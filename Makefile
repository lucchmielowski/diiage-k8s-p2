## Container build and push helpers

# Registry/namespace configuration
REGISTRY ?= ghcr.io
OWNER    ?= lucchmielowski
PROJECT  ?= k8s-diiage-p2

# List of application services located under app/
SERVICES := cart frontend notification payment

# Image tag to use (override with TAG=...)
TAG ?= latest

IMAGE_PREFIX := $(REGISTRY)/$(OWNER)/$(PROJECT)-

.PHONY: help build build-% build-all push push-% push-all ghcr-login kind-load

help:
	@echo "Available targets:"
	@echo "  build           Build all service images (TAG=$(TAG))"
	@echo "  build-<svc>     Build a single service image (services: $(SERVICES))"
	@echo "  push            Push all service images (TAG=$(TAG)) to $(REGISTRY)"
	@echo "  push-<svc>      Push a single service image"
	@echo "  ghcr-login      Docker login to ghcr.io (uses GHCR_TOKEN env var)"
	@echo "  kind-load       Load all service images into kind cluster"
	@echo "  helm-install    Install Helm chart"
	@echo "  helm-uninstall  Uninstall Helm chart"

# Build a single service image from app/<service>/
build-%:
	@svc=$*; \
	if echo " $(SERVICES) " | grep -q " $$svc "; then \
		echo "Building $$svc -> $(IMAGE_PREFIX)$$svc:$(TAG)"; \
		docker build -t $(IMAGE_PREFIX)$$svc:$(TAG) app/$$svc; \
	else \
		echo "Unknown service: $$svc. Choose one of: $(SERVICES)"; \
		exit 1; \
	fi

# Build all service images
build: build-all

build-all: $(SERVICES:%=build-%)

# Push a single service image
push-%:
	@svc=$*; \
	if echo " $(SERVICES) " | grep -q " $$svc "; then \
		echo "Pushing $$svc -> $(IMAGE_PREFIX)$$svc:$(TAG)"; \
		docker push $(IMAGE_PREFIX)$$svc:$(TAG); \
	else \
		echo "Unknown service: $$svc. Choose one of: $(SERVICES)"; \
		exit 1; \
	fi

# Push all service images to ghcr.io
push: push-all

push-all: $(SERVICES:%=push-%)

# Optional: login to GitHub Container Registry using GHCR_TOKEN env var
ghcr-login:
	@if [ -z "$$GHCR_TOKEN" ]; then \
		echo "GHCR_TOKEN env var is not set. Create a GitHub PAT with 'write:packages' and set GHCR_TOKEN."; \
		exit 1; \
	fi
	@echo "Logging in to ghcr.io as $(OWNER)";
	@echo "$$GHCR_TOKEN" | docker login ghcr.io -u "$(OWNER)" --password-stdin

# Load all service images into kind cluster
kind-load: build-all
	@for svc in $(SERVICES); do \
		echo "Loading $$svc -> $(IMAGE_PREFIX)$$svc:$(TAG) into kind cluster"; \
		kind load docker-image $(IMAGE_PREFIX)$$svc:$(TAG); \
	done

# Helm chart directory
CHART_DIR ?= ./charts/ecommerce-demo

# Helm targets
.PHONY: helm-install helm-upgrade helm-uninstall

helm-install:
	helm upgrade --install ecommerce $(CHART_DIR) --create-namespace --namespace ecommerce

helm-uninstall:
	helm uninstall ecommerce --namespace ecommerce
