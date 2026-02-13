IMAGE := ghcr.io/gifi71/ocserv-docker
TAG   := latest

.DEFAULT_GOAL := help

.PHONY: help build push lint clean oci-image

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-12s %s\n", $$1, $$2}'

build: oci-image ## Alias for oci-image

oci-image: ## Build the Docker image
	docker buildx build --progress=plain --pull -t $(IMAGE):$(TAG) .

push: ## Push the image to GHCR
	docker push $(IMAGE):$(TAG)

lint: ## Run hadolint and shellcheck
	hadolint Dockerfile
	shellcheck rootfs/etc/s6-overlay/s6-rc.d/*/run rootfs/etc/s6-overlay/s6-rc.d/*/teardown rootfs/usr/local/bin/*.sh

clean: ## Remove the built image
	docker rmi $(IMAGE):$(TAG) 2>/dev/null || true
