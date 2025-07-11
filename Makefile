# Golden Image Build System Makefile

# Load configuration
-include configs/acr-config.env

# Variables
BUILD_DATE := $(shell date -u +'%Y-%m-%dT%H:%M:%SZ')
VCS_REF := $(shell git rev-parse --short HEAD)
VERSION := 1.0.0

# Base images
BASE_IMAGES := alpine debian redhat
PLATFORM_IMAGES := nginx openjdk tomcat python springboot aspnet dotnet

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
build-base-images: $(addprefix build-base-,$(BASE_IMAGES))

build-base-alpine:
	@echo "🔨 Building Alpine base image..."
	docker build $(BUILD_ARGS) -t $(ACR_LOGIN_SERVER)/alpine-hardened:$(BASE_IMAGE_TAG) base-images/alpine/

build-base-debian:
	@echo "🔨 Building Debian base image..."
	docker build $(BUILD_ARGS) -t $(ACR_LOGIN_SERVER)/debian-hardened:$(BASE_IMAGE_TAG) base-images/debian/

build-base-redhat:
	@echo "🔨 Building RedHat base image..."
	docker build $(BUILD_ARGS) -t $(ACR_LOGIN_SERVER)/redhat-hardened:$(BASE_IMAGE_TAG) base-images/redhat/

# Build platform images
.PHONY: build-platform-images
build-platform-images: $(addprefix build-platform-,$(PLATFORM_IMAGES))

build-platform-nginx:
	@echo "🔨 Building Nginx platform image..."
	docker build $(BUILD_ARGS) -t $(ACR_LOGIN_SERVER)/nginx-platform:$(PLATFORM_IMAGE_TAG) platform-images/nginx/

build-platform-openjdk:
	@echo "🔨 Building OpenJDK platform image..."
	docker build $(BUILD_ARGS) -t $(ACR_LOGIN_SERVER)/openjdk-platform:$(PLATFORM_IMAGE_TAG) platform-images/openjdk/

build-platform-tomcat:
	@echo "🔨 Building Tomcat platform image..."
	docker build $(BUILD_ARGS) -t $(ACR_LOGIN_SERVER)/tomcat-platform:$(PLATFORM_IMAGE_TAG) platform-images/tomcat/

build-platform-python:
	@echo "🔨 Building Python platform image..."
	docker build $(BUILD_ARGS) -t $(ACR_LOGIN_SERVER)/python-platform:$(PLATFORM_IMAGE_TAG) platform-images/python/

build-platform-springboot:
	@echo "🔨 Building Spring Boot platform image..."
	docker build $(BUILD_ARGS) -t $(ACR_LOGIN_SERVER)/springboot-platform:$(PLATFORM_IMAGE_TAG) platform-images/springboot/

build-platform-aspnet:
	@echo "🔨 Building ASP.NET Core platform image..."
	docker build $(BUILD_ARGS) -t $(ACR_LOGIN_SERVER)/aspnet-platform:$(PLATFORM_IMAGE_TAG) platform-images/aspnet/

build-platform-dotnet:
	@echo "🔨 Building .NET Runtime platform image..."
	docker build $(BUILD_ARGS) -t $(ACR_LOGIN_SERVER)/dotnet-platform:$(PLATFORM_IMAGE_TAG) platform-images/dotnet/

# Build all images
.PHONY: build-all
build-all: build-base-images build-platform-images

# Push base images to ACR
.PHONY: push-base-images
push-base-images: $(addprefix push-base-,$(BASE_IMAGES))

push-base-alpine:
	@echo "📤 Pushing Alpine base image to ACR..."
	docker push $(ACR_LOGIN_SERVER)/alpine-hardened:$(BASE_IMAGE_TAG)

push-base-debian:
	@echo "📤 Pushing Debian base image to ACR..."
	docker push $(ACR_LOGIN_SERVER)/debian-hardened:$(BASE_IMAGE_TAG)

push-base-redhat:
	@echo "📤 Pushing RedHat base image to ACR..."
	docker push $(ACR_LOGIN_SERVER)/redhat-hardened:$(BASE_IMAGE_TAG)

# Push platform images to ACR
.PHONY: push-platform-images
push-platform-images: $(addprefix push-platform-,$(PLATFORM_IMAGES))

push-platform-nginx:
	@echo "📤 Pushing Nginx platform image to ACR..."
	docker push $(ACR_LOGIN_SERVER)/nginx-platform:$(PLATFORM_IMAGE_TAG)

push-platform-openjdk:
	@echo "📤 Pushing OpenJDK platform image to ACR..."
	docker push $(ACR_LOGIN_SERVER)/openjdk-platform:$(PLATFORM_IMAGE_TAG)

push-platform-tomcat:
	@echo "📤 Pushing Tomcat platform image to ACR..."
	docker push $(ACR_LOGIN_SERVER)/tomcat-platform:$(PLATFORM_IMAGE_TAG)

push-platform-python:
	@echo "📤 Pushing Python platform image to ACR..."
	docker push $(ACR_LOGIN_SERVER)/python-platform:$(PLATFORM_IMAGE_TAG)

push-platform-springboot:
	@echo "📤 Pushing Spring Boot platform image to ACR..."
	docker push $(ACR_LOGIN_SERVER)/springboot-platform:$(PLATFORM_IMAGE_TAG)

push-platform-aspnet:
	@echo "📤 Pushing ASP.NET Core platform image to ACR..."
	docker push $(ACR_LOGIN_SERVER)/aspnet-platform:$(PLATFORM_IMAGE_TAG)

push-platform-dotnet:
	@echo "📤 Pushing .NET Runtime platform image to ACR..."
	docker push $(ACR_LOGIN_SERVER)/dotnet-platform:$(PLATFORM_IMAGE_TAG)

# Push all images
.PHONY: push-all
push-all: push-base-images push-platform-images

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

# Login to ACR
.PHONY: login-acr
login-acr:
	@echo "🔐 Logging into Azure Container Registry..."
	docker login $(ACR_LOGIN_SERVER) -u $(ACR_USERNAME) -p $(ACR_PASSWORD)

# Complete build and push workflow
.PHONY: deploy
deploy: login-acr build-all push-all scan-images
	@echo "✅ Complete build and deployment completed successfully!" 