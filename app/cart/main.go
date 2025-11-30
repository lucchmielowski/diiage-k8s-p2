package main

import (
	"bytes"
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	_ "github.com/lib/pq"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
	"go.opentelemetry.io/otel/propagation"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.4.0"
	"go.opentelemetry.io/otel/trace"
)

var (
	db *sql.DB

	sagaTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "cart_saga_total",
			Help: "Total saga executions",
		},
		[]string{"status"},
	)

	sagaDuration = promauto.NewHistogram(
		prometheus.HistogramOpts{
			Name:    "cart_saga_duration_seconds",
			Help:    "Saga execution duration",
			Buckets: prometheus.DefBuckets,
		},
	)
)

type CheckoutRequest struct {
	UserID string  `json:"user_id"`
	Amount float64 `json:"amount"`
	Items  []Item  `json:"items"`
}

type Item struct {
	ProductID string  `json:"product_id"`
	Quantity  int     `json:"quantity"`
	Price     float64 `json:"price"`
}

type SagaState struct {
	OrderID         string
	PaymentComplete bool
	NotifySent      bool
}

func initTracer() (*sdktrace.TracerProvider, error) {
	ctx := context.Background()

	otlpEndpoint := os.Getenv("OTEL_EXPORTER_OTLP_ENDPOINT")
	if otlpEndpoint == "" {
		otlpEndpoint = "tempo:4317"
	}

	exporter, err := otlptracegrpc.New(ctx,
		otlptracegrpc.WithEndpoint(otlpEndpoint),
		otlptracegrpc.WithInsecure(),
	)
	if err != nil {
		return nil, err
	}

	res, err := resource.New(ctx,
		resource.WithAttributes(
			semconv.ServiceNameKey.String("cart"),
		),
	)
	if err != nil {
		return nil, err
	}

	tp := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(exporter),
		sdktrace.WithResource(res),
	)

	otel.SetTracerProvider(tp)
	otel.SetTextMapPropagator(propagation.TraceContext{})

	return tp, nil
}

func initDB() error {
	connStr := os.Getenv("DATABASE_URL")
	if connStr == "" {
		connStr = "postgres://postgres:postgres@postgres:5432/ecommerce?sslmode=disable"
	}

	var err error
	db, err = sql.Open("postgres", connStr)
	if err != nil {
		return err
	}

	// Retry connection with exponential backoff
	maxRetries := 10
	backoff := time.Second
	
	for i := 0; i < maxRetries; i++ {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		err = db.PingContext(ctx)
		cancel()
		
		if err == nil {
			log.Printf("Successfully connected to database")
			break
		}
		
		if i < maxRetries-1 {
			log.Printf("Database connection attempt %d/%d failed: %v. Retrying in %v...", i+1, maxRetries, err, backoff)
			time.Sleep(backoff)
			backoff *= 2
			if backoff > 30*time.Second {
				backoff = 30 * time.Second
			}
		} else {
			return fmt.Errorf("failed to connect to database after %d attempts: %w", maxRetries, err)
		}
	}

	// Create orders table
	log.Printf("Creating orders table if not exists...")
	_, err = db.Exec(`
		CREATE TABLE IF NOT EXISTS orders (
			id SERIAL PRIMARY KEY,
			order_id VARCHAR(255) UNIQUE NOT NULL,
			user_id VARCHAR(255) NOT NULL,
			amount DECIMAL(10,2) NOT NULL,
			status VARCHAR(50) NOT NULL,
			created_at TIMESTAMP DEFAULT NOW()
		)
	`)
	
	if err != nil {
		return fmt.Errorf("failed to create orders table: %w", err)
	}
	
	log.Printf("Database initialized successfully")
	return nil
}

func main() {
	tp, err := initTracer()
	if err != nil {
		log.Printf("Failed to initialize tracer: %v", err)
	} else {
		defer func() {
			ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
			defer cancel()
			if err := tp.Shutdown(ctx); err != nil {
				log.Printf("Error shutting down tracer: %v", err)
			}
		}()
	}

	if err := initDB(); err != nil {
		log.Fatalf("Failed to initialize database: %v", err)
	}
	defer db.Close()

	http.HandleFunc("/health", handleHealth)
	http.HandleFunc("/cart/checkout", handleCheckout)
	http.Handle("/metrics", promhttp.Handler())

	port := os.Getenv("PORT")
	if port == "" {
		port = "8081"
	}

	log.Printf("Cart service listening on :%s", port)
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatal(err)
	}
}

func handleHealth(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("OK"))
}

func handleCheckout(w http.ResponseWriter, r *http.Request) {
	start := time.Now()
	ctx := r.Context()

	// Extract trace context from headers
	ctx = otel.GetTextMapPropagator().Extract(ctx, propagation.HeaderCarrier(r.Header))

	tracer := otel.Tracer("cart")
	ctx, span := tracer.Start(ctx, "checkout-saga",
		trace.WithAttributes(
			attribute.String("http.method", r.Method),
		),
	)
	defer span.End()

	defer func() {
		sagaDuration.Observe(time.Since(start).Seconds())
	}()

	var req CheckoutRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sagaTotal.WithLabelValues("error").Inc()
		http.Error(w, "Invalid request", http.StatusBadRequest)
		return
	}

	// Execute Saga
	orderID := fmt.Sprintf("ORD-%d", time.Now().UnixNano())
	state := &SagaState{OrderID: orderID}

	span.SetAttributes(
		attribute.String("order_id", orderID),
		attribute.String("user_id", req.UserID),
	)

	// Step 1: Save order
	if err := saveOrder(ctx, orderID, req); err != nil {
		sagaTotal.WithLabelValues("failed").Inc()
		span.RecordError(err)
		log.Printf("Failed to save order: %v", err)
		http.Error(w, "Failed to create order", http.StatusInternalServerError)
		return
	}

	// Step 2: Process payment
	if err := processPayment(ctx, orderID, req.Amount); err != nil {
		sagaTotal.WithLabelValues("compensated").Inc()
		span.RecordError(err)
		log.Printf("Payment failed, compensating: %v", err)

		// Compensate: mark order as failed
		compensateOrder(ctx, orderID)

		http.Error(w, "Payment failed", http.StatusPaymentRequired)
		return
	}
	state.PaymentComplete = true

	// Step 3: Send notification
	if err := sendNotification(ctx, orderID, req.UserID); err != nil {
		log.Printf("Notification failed (non-critical): %v", err)
		// Don't fail the saga for notification errors
	} else {
		state.NotifySent = true
	}

	sagaTotal.WithLabelValues("success").Inc()

	resp := map[string]string{
		"order_id": orderID,
		"status":   "completed",
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(resp)
}

func saveOrder(ctx context.Context, orderID string, req CheckoutRequest) error {
	tracer := otel.Tracer("cart")
	_, span := tracer.Start(ctx, "save-order")
	defer span.End()

	if db == nil {
		log.Printf("Warning: Database not available, skipping order save")
		return nil
	}

	_, err := db.ExecContext(ctx, `
		INSERT INTO orders (order_id, user_id, amount, status)
		VALUES ($1, $2, $3, $4)
	`, orderID, req.UserID, req.Amount, "pending")

	return err
}

func compensateOrder(ctx context.Context, orderID string) {
	tracer := otel.Tracer("cart")
	_, span := tracer.Start(ctx, "compensate-order")
	defer span.End()

	if db == nil {
		return
	}

	db.ExecContext(ctx, `
		UPDATE orders SET status = $1 WHERE order_id = $2
	`, "failed", orderID)
}

func processPayment(ctx context.Context, orderID string, amount float64) error {
	tracer := otel.Tracer("cart")
	ctx, span := tracer.Start(ctx, "process-payment")
	defer span.End()

	paymentURL := os.Getenv("PAYMENT_SERVICE_URL")
	if paymentURL == "" {
		paymentURL = "http://payment:8082"
	}

	reqBody, _ := json.Marshal(map[string]interface{}{
		"order_id": orderID,
		"amount":   amount,
	})

	httpReq, err := http.NewRequestWithContext(ctx, "POST", paymentURL+"/payment/process", bytes.NewBuffer(reqBody))
	if err != nil {
		return err
	}
	httpReq.Header.Set("Content-Type", "application/json")

	// Propagate trace context
	otel.GetTextMapPropagator().Inject(ctx, propagation.HeaderCarrier(httpReq.Header))

	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Do(httpReq)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("payment failed with status %d", resp.StatusCode)
	}

	return nil
}

func sendNotification(ctx context.Context, orderID, userID string) error {
	tracer := otel.Tracer("cart")
	ctx, span := tracer.Start(ctx, "send-notification")
	defer span.End()

	notifURL := os.Getenv("NOTIFICATION_SERVICE_URL")
	if notifURL == "" {
		notifURL = "http://notification:8083"
	}

	reqBody, _ := json.Marshal(map[string]string{
		"order_id": orderID,
		"user_id":  userID,
		"message":  "Your order has been confirmed",
	})

	httpReq, err := http.NewRequestWithContext(ctx, "POST", notifURL+"/notify", bytes.NewBuffer(reqBody))
	if err != nil {
		return err
	}
	httpReq.Header.Set("Content-Type", "application/json")

	// Propagate trace context
	otel.GetTextMapPropagator().Inject(ctx, propagation.HeaderCarrier(httpReq.Header))

	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Do(httpReq)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	return nil
}
