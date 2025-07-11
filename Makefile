# Golden Image Build System Makefile

# Load configuration
-include configs/ghcr-config.env
-include configs/acr-config.env

# Variables
BUILD_DATE := $(shell date -u +'%Y-%m-%dT%H:%M:%SZ')
VCS_REF := $(shell git rev-parse --short HEAD)
VERSION := 1.0.0

# Registry configuration
REGISTRY := $(GHCR_REGISTRY)/$(GHCR_NAMESPACE)
ACR_REGISTRY := $(ACR_LOGIN_SERVER)

# Base images
BASE_IMAGES := alpine debian redhat
PLATFORM_IMAGES := nginx openjdk tomcat python springboot aspnet dotnet

# LTS versions for each OS
ALPINE_VERSIONS := 3.18 3.19 3.20
DEBIAN_VERSIONS := 11 12
REDHAT_VERSIONS := 8 9

# Docker build arguments
BUILD_ARGS := --build-arg BUILD_DATE=$(BUILD_DATE) --build-arg VCS_REF=$(VCS_REF) --build-arg VERSION=$(VERSION)

# Default target
.PHONY: help
help:
	@echo "Golden Image Build System"
	@echo "========================="
	@echo ""
	@echo "Available targets:"
	@echo "  build-base-images    - Build all base OS images"
	@echo "  build-platform-images - Build all platform images"
	@echo "  build-all           - Build all images"
	@echo "  push-base-images    - Push base images to ACR"
	@echo "  push-platform-images - Push platform images to ACR"
	@echo "  push-all           - Push all images to ACR"
	@echo "  scan-images        - Scan images for vulnerabilities"
	@echo "  clean              - Clean build artifacts"
	@echo "  help               - Show this help"

# Build base images
.PHONY: build-base-images
build-base-images: build-all-alpine-versions build-all-debian-versions build-all-redhat-versions

# Build all Alpine LTS versions
.PHONY: build-all-alpine-versions
build-all-alpine-versions: $(addprefix build-alpine-,$(ALPINE_VERSIONS))

build-alpine-3.18:
	@echo "🔨 Building Alpine 3.18 LTS base image..."
	docker build $(BUILD_ARGS) -f base-images/alpine/Dockerfile.3.18 -t $(REGISTRY)/alpine-hardened:3.18 base-images/alpine/

build-alpine-3.19:
	@echo "🔨 Building Alpine 3.19 LTS base image..."
	docker build $(BUILD_ARGS) -f base-images/alpine/Dockerfile.3.19 -t $(REGISTRY)/alpine-hardened:3.19 base-images/alpine/

build-alpine-3.20:
	@echo "🔨 Building Alpine 3.20 LTS base image..."
	docker build $(BUILD_ARGS) -f base-images/alpine/Dockerfile.3.20 -t $(REGISTRY)/alpine-hardened:3.20 base-images/alpine/

# Build all Debian LTS versions
.PHONY: build-all-debian-versions
build-all-debian-versions: $(addprefix build-debian-,$(DEBIAN_VERSIONS))

build-debian-11:
	@echo "🔨 Building Debian 11 (Bullseye) LTS base image..."
	docker build $(BUILD_ARGS) -f base-images/debian/Dockerfile.11 -t $(REGISTRY)/debian-hardened:11 base-images/debian/

build-debian-12:
	@echo "🔨 Building Debian 12 (Bookworm) LTS base image..."
	docker build $(BUILD_ARGS) -f base-images/debian/Dockerfile.12 -t $(REGISTRY)/debian-hardened:12 base-images/debian/

# Build all RedHat LTS versions
.PHONY: build-all-redhat-versions
build-all-redhat-versions: $(addprefix build-redhat-,$(REDHAT_VERSIONS))

build-redhat-8:
	@echo "🔨 Building RedHat UBI 8 LTS base image..."
	docker build $(BUILD_ARGS) -f base-images/redhat/Dockerfile.8 -t $(REGISTRY)/redhat-hardened:8 base-images/redhat/

build-redhat-9:
	@echo "🔨 Building RedHat UBI 9 LTS base image..."
	docker build $(BUILD_ARGS) -f base-images/redhat/Dockerfile.9 -t $(REGISTRY)/redhat-hardened:9 base-images/redhat/

# Legacy targets for backward compatibility
build-base-alpine: build-alpine-3.20
build-base-debian: build-debian-12
build-base-redhat: build-redhat-9

# Build platform images
.PHONY: build-platform-images
build-platform-images: $(addprefix build-platform-,$(PLATFORM_IMAGES))

build-platform-nginx:
	@echo "🔨 Building Nginx platform image..."
	docker build $(BUILD_ARGS) -t $(REGISTRY)/nginx-platform:$(PLATFORM_IMAGE_TAG) platform-images/nginx/

build-platform-openjdk:
	@echo "🔨 Building OpenJDK platform image..."
	docker build $(BUILD_ARGS) -t $(REGISTRY)/openjdk-platform:$(PLATFORM_IMAGE_TAG) platform-images/openjdk/

build-platform-tomcat:
	@echo "🔨 Building Tomcat platform image..."
	docker build $(BUILD_ARGS) -t $(REGISTRY)/tomcat-platform:$(PLATFORM_IMAGE_TAG) platform-images/tomcat/

build-platform-python:
	@echo "🔨 Building Python platform image..."
	docker build $(BUILD_ARGS) -t $(REGISTRY)/python-platform:$(PLATFORM_IMAGE_TAG) platform-images/python/

build-platform-springboot:
	@echo "🔨 Building Spring Boot platform image..."
	docker build $(BUILD_ARGS) -t $(REGISTRY)/springboot-platform:$(PLATFORM_IMAGE_TAG) platform-images/springboot/

build-platform-aspnet:
	@echo "🔨 Building ASP.NET Core platform image..."
	docker build $(BUILD_ARGS) -t $(REGISTRY)/aspnet-platform:$(PLATFORM_IMAGE_TAG) platform-images/aspnet/

build-platform-dotnet:
	@echo "🔨 Building .NET Runtime platform image..."
	docker build $(BUILD_ARGS) -t $(REGISTRY)/dotnet-platform:$(PLATFORM_IMAGE_TAG) platform-images/dotnet/

# Build all images
.PHONY: build-all
build-all: build-base-images build-platform-images

# Push base images to GHCR
.PHONY: push-base-images
push-base-images: $(addprefix push-base-,$(BASE_IMAGES))

push-base-alpine:
	@echo "📤 Pushing Alpine base image to GHCR..."
	docker push $(REGISTRY)/alpine-hardened:$(BASE_IMAGE_TAG)

push-base-debian:
	@echo "📤 Pushing Debian base image to GHCR..."
	docker push $(REGISTRY)/debian-hardened:$(BASE_IMAGE_TAG)

push-base-redhat:
	@echo "📤 Pushing RedHat base image to GHCR..."
	docker push $(REGISTRY)/redhat-hardened:$(BASE_IMAGE_TAG)

# Push platform images to GHCR
.PHONY: push-platform-images
push-platform-images: $(addprefix push-platform-,$(PLATFORM_IMAGES))

push-platform-nginx:
	@echo "📤 Pushing Nginx platform image to GHCR..."
	docker push $(REGISTRY)/nginx-platform:$(PLATFORM_IMAGE_TAG)

push-platform-openjdk:
	@echo "📤 Pushing OpenJDK platform image to GHCR..."
	docker push $(REGISTRY)/openjdk-platform:$(PLATFORM_IMAGE_TAG)

push-platform-tomcat:
	@echo "📤 Pushing Tomcat platform image to GHCR..."
	docker push $(REGISTRY)/tomcat-platform:$(PLATFORM_IMAGE_TAG)

push-platform-python:
	@echo "📤 Pushing Python platform image to GHCR..."
	docker push $(REGISTRY)/python-platform:$(PLATFORM_IMAGE_TAG)

push-platform-springboot:
	@echo "📤 Pushing Spring Boot platform image to GHCR..."
	docker push $(REGISTRY)/springboot-platform:$(PLATFORM_IMAGE_TAG)

push-platform-aspnet:
	@echo "📤 Pushing ASP.NET Core platform image to GHCR..."
	docker push $(REGISTRY)/aspnet-platform:$(PLATFORM_IMAGE_TAG)

push-platform-dotnet:
	@echo "📤 Pushing .NET Runtime platform image to GHCR..."
	docker push $(REGISTRY)/dotnet-platform:$(PLATFORM_IMAGE_TAG)

# Push all images to GHCR
.PHONY: push-all
push-all: push-base-images push-platform-images

# Sync images from GHCR to ACR
.PHONY: sync-to-acr
sync-to-acr:
	@echo "🔄 Syncing images from GHCR to ACR..."
	@./scripts/registry-sync.sh sync-all

# Sync specific image to ACR
.PHONY: sync-image-to-acr
sync-image-to-acr:
	@if [ -z "$(IMAGE_NAME)" ]; then \
		echo "❌ Please specify IMAGE_NAME=<image-name>"; \
		exit 1; \
	fi
	@echo "🔄 Syncing $(IMAGE_NAME) from GHCR to ACR..."
	@./scripts/registry-sync.sh sync-image $(IMAGE_NAME) $(IMAGE_TAG)

# Scan images for vulnerabilities
.PHONY: scan-images
scan-images:
	@echo "🔍 Scanning images for vulnerabilities..."
	@if command -v trivy >/dev/null 2>&1; then \
		for image in $(ACR_LOGIN_SERVER)/alpine-hardened:$(BASE_IMAGE_TAG) \
			$(ACR_LOGIN_SERVER)/debian-hardened:$(BASE_IMAGE_TAG) \
			$(ACR_LOGIN_SERVER)/redhat-hardened:$(BASE_IMAGE_TAG) \
			$(ACR_LOGIN_SERVER)/nginx-platform:$(PLATFORM_IMAGE_TAG) \
			$(ACR_LOGIN_SERVER)/openjdk-platform:$(PLATFORM_IMAGE_TAG) \
			$(ACR_LOGIN_SERVER)/python-platform:$(PLATFORM_IMAGE_TAG) \
			$(ACR_LOGIN_SERVER)/dotnet-platform:$(PLATFORM_IMAGE_TAG); do \
			echo "Scanning $$image..."; \
			trivy image --severity HIGH,CRITICAL $$image; \
		done; \
	else \
		echo "Trivy not found. Install it to scan images for vulnerabilities."; \
	fi

# Comprehensive security scanning with multiple tools
.PHONY: scan-comprehensive
scan-comprehensive:
	@echo "🔍 Running comprehensive security scan..."
	@./scripts/comprehensive-scan.sh

# Prisma Cloud security scanning
.PHONY: scan-prisma
scan-prisma:
	@echo "🔍 Running Prisma Cloud security scan..."
	@./scripts/prisma-scan.sh

# Trivy-only security scanning
.PHONY: scan-trivy
scan-trivy:
	@echo "🔍 Running Trivy security scan..."
	@./scripts/comprehensive-scan.sh --trivy-only

# Prisma Cloud-only security scanning
.PHONY: scan-prisma-only
scan-prisma-only:
	@echo "🔍 Running Prisma Cloud-only security scan..."
	@./scripts/comprehensive-scan.sh --prisma-only

# Clean build artifacts
.PHONY: clean
clean:
	@echo "🧹 Cleaning build artifacts..."
	docker system prune -f
	docker image prune -f

# Login to registries
.PHONY: login-ghcr
login-ghcr:
	@echo "🔐 Logging into GitHub Container Registry..."
	@if [ -n "$(GHCR_USERNAME)" ] && [ -n "$(GHCR_PASSWORD)" ]; then \
		echo "$(GHCR_PASSWORD)" | docker login $(GHCR_REGISTRY) -u $(GHCR_USERNAME) --password-stdin; \
	else \
		echo "$(GITHUB_TOKEN)" | docker login $(GHCR_REGISTRY) -u $(GITHUB_ACTOR) --password-stdin; \
	fi

.PHONY: login-acr
login-acr:
	@echo "🔐 Logging into Azure Container Registry..."
	docker login $(ACR_LOGIN_SERVER) -u $(ACR_USERNAME) -p $(ACR_PASSWORD)

# Complete build and push workflow
.PHONY: deploy
deploy: login-ghcr build-all push-all scan-images
	@echo "✅ Complete build and deployment to GHCR completed successfully!"

# Complete workflow with ACR sync
.PHONY: deploy-with-sync
deploy-with-sync: deploy login-acr sync-to-acr
	@echo "✅ Complete build, push to GHCR, and sync to ACR completed successfully!" 