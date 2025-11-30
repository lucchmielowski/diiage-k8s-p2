package main

import (
	"context"
	"encoding/json"
	"log"
	"math/rand"
	"net/http"
	"os"
	"strconv"
	"time"

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
	paymentTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "payment_requests_total",
			Help: "Total payment requests",
		},
		[]string{"status"},
	)

	paymentDuration = promauto.NewHistogram(
		prometheus.HistogramOpts{
			Name:    "payment_duration_seconds",
			Help:    "Payment processing duration",
			Buckets: prometheus.DefBuckets,
		},
	)

	failureRate float64 = 0.2 // 20% failure rate for demo
)

type PaymentRequest struct {
	OrderID string  `json:"order_id"`
	Amount  float64 `json:"amount"`
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
			semconv.ServiceNameKey.String("payment"),
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

func main() {
	rand.Seed(time.Now().UnixNano())

	// Allow configuring failure rate via env
	if fr := os.Getenv("FAILURE_RATE"); fr != "" {
		if parsed, err := strconv.ParseFloat(fr, 64); err == nil {
			failureRate = parsed
			log.Printf("Failure rate set to %.2f%%", failureRate*100)
		}
	}

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

	http.HandleFunc("/health", handleHealth)
	http.HandleFunc("/payment/process", handlePayment)
	http.Handle("/metrics", promhttp.Handler())

	port := os.Getenv("PORT")
	if port == "" {
		port = "8082"
	}

	log.Printf("Payment service listening on :%s", port)
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatal(err)
	}
}

func handleHealth(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("OK"))
}

func handlePayment(w http.ResponseWriter, r *http.Request) {
	start := time.Now()
	ctx := r.Context()

	// Extract trace context
	ctx = otel.GetTextMapPropagator().Extract(ctx, propagation.HeaderCarrier(r.Header))

	tracer := otel.Tracer("payment")
	ctx, span := tracer.Start(ctx, "process-payment",
		trace.WithAttributes(
			attribute.String("http.method", r.Method),
		),
	)
	defer span.End()

	defer func() {
		paymentDuration.Observe(time.Since(start).Seconds())
	}()

	var req PaymentRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		paymentTotal.WithLabelValues("error").Inc()
		http.Error(w, "Invalid request", http.StatusBadRequest)
		return
	}

	span.SetAttributes(
		attribute.String("order_id", req.OrderID),
		attribute.Float64("amount", req.Amount),
	)

	// Simulate payment processing delay
	processingTime := time.Duration(50+rand.Intn(150)) * time.Millisecond
	time.Sleep(processingTime)

	// Simulate random failures
	if rand.Float64() < failureRate {
		paymentTotal.WithLabelValues("failed").Inc()
		span.SetAttributes(attribute.String("failure.reason", "simulated"))

		log.Printf("Payment failed (simulated) for order %s", req.OrderID)

		resp := map[string]string{
			"status":  "failed",
			"message": "Payment processing failed",
		}
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusPaymentRequired)
		json.NewEncoder(w).Encode(resp)
		return
	}

	paymentTotal.WithLabelValues("success").Inc()

	log.Printf("Payment successful for order %s, amount: %.2f", req.OrderID, req.Amount)

	resp := map[string]string{
		"status":         "success",
		"transaction_id": generateTransactionID(),
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(resp)
}

func generateTransactionID() string {
	return "TXN-" + strconv.FormatInt(time.Now().UnixNano(), 36)
}
