IMAGE    := ghcr.io/gifi71/ocserv-docker
TAG      ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo latest)
PLATFORM := linux/amd64,linux/arm64

.DEFAULT_GOAL := help

.PHONY: help build build-multiarch push lint test clean

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-18s %s\n", $$1, $$2}'

build: ## Build the Docker image (local)
	docker buildx build --progress=plain --pull --load -t $(IMAGE):$(TAG) .

build-multiarch: ## Build multi-platform and push
	docker buildx build --progress=plain --pull --platform $(PLATFORM) --push -t $(IMAGE):$(TAG) .

push: ## Push the image to GHCR
	docker push $(IMAGE):$(TAG)

lint: ## Run all linters via pre-commit
	pre-commit run --all-files

test: build ## Run integration tests
	IMAGE=$(IMAGE) TAG=$(TAG) tests/run.sh

clean: ## Remove the built image
	docker rmi $(IMAGE):$(TAG) 2>/dev/null || true
