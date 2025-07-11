# Golden Image Build System Makefile

# Load configuration
-include configs/ghcr-config.env
-include configs/acr-config.env
-include configs/lts-versions.env
-include configs/platform-lts-versions.env

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

# LTS versions for each OS (loaded from configs/lts-versions.env)
# ALPINE_VERSIONS, DEBIAN_VERSIONS, REDHAT_VERSIONS are defined in lts-versions.env

# Docker build arguments
BUILD_ARGS := --build-arg BUILD_DATE=$(BUILD_DATE) --build-arg VCS_REF=$(VCS_REF) --build-arg VERSION=$(VERSION)

# Default target
.PHONY: help
help:
	@echo "Golden Image Build System"
	@echo "========================="
	@echo ""
	@echo "Available targets:"
	@echo "  build-base-images    - Build all base OS images (all LTS versions)"
	@echo "  build-platform-images - Build all platform images"
	@echo "  build-all           - Build all images"
	@echo "  push-base-images    - Push base images to GHCR (all LTS versions)"
	@echo "  push-platform-images - Push platform images to GHCR"
	@echo "  push-all           - Push all images to GHCR"
	@echo "  scan-images        - Scan images for vulnerabilities"
	@echo "  clean              - Clean build artifacts"
	@echo "  help               - Show this help"
	@echo ""
	@echo "LTS Version Management:"
	@echo "  show-lts-versions           - Show current OS LTS version configuration"
	@echo "  show-platform-versions      - Show current platform LTS version configuration"
	@echo "  validate-lts-config         - Validate OS LTS version configuration"
	@echo "  validate-platform-config    - Validate platform LTS version configuration"
	@echo ""
	@echo "OS LTS Version Targets:"
	@echo "  build-alpine-<version>      - Build specific Alpine LTS version"
	@echo "  build-debian-<version>      - Build specific Debian LTS version"
	@echo "  build-redhat-<version>      - Build specific RedHat LTS version"
	@echo "  push-alpine-<version>       - Push specific Alpine LTS version"
	@echo "  push-debian-<version>       - Push specific Debian LTS version"
	@echo "  push-redhat-<version>       - Push specific RedHat LTS version"
	@echo ""
	@echo "Platform LTS Version Targets:"
	@echo "  build-<platform>-<version>-<os>-<os_version> - Build specific platform version on specific OS"
	@echo "  push-<platform>-<version>-<os>-<os_version>  - Push specific platform version on specific OS"
	@echo "  build-all-platforms         - Build all platform versions on all OS versions"
	@echo "  push-all-platforms          - Push all platform versions on all OS versions"
	@echo ""
	@echo "To add/remove OS LTS versions, edit configs/lts-versions.env"
	@echo "To add/remove platform LTS versions, edit configs/platform-lts-versions.env"

# Build base images
.PHONY: build-base-images
build-base-images: build-all-alpine-versions build-all-debian-versions build-all-redhat-versions

# Build all Alpine LTS versions
.PHONY: build-all-alpine-versions
build-all-alpine-versions: $(addprefix build-alpine-,$(ALPINE_VERSIONS))

# Alpine build targets are dynamically generated based on ALPINE_VERSIONS in lts-versions.env
# To add/remove Alpine versions, edit configs/lts-versions.env and run: make validate-lts-config

# Build all Debian LTS versions
.PHONY: build-all-debian-versions
build-all-debian-versions: $(addprefix build-debian-,$(DEBIAN_VERSIONS))

# Debian build targets are dynamically generated based on DEBIAN_VERSIONS in lts-versions.env
# To add/remove Debian versions, edit configs/lts-versions.env and run: make validate-lts-config

# Build all RedHat LTS versions
.PHONY: build-all-redhat-versions
build-all-redhat-versions: $(addprefix build-redhat-,$(REDHAT_VERSIONS))

# RedHat build targets are dynamically generated based on REDHAT_VERSIONS in lts-versions.env
# To add/remove RedHat versions, edit configs/lts-versions.env and run: make validate-lts-config

# Legacy targets for backward compatibility
build-base-alpine: build-alpine-$(DEFAULT_ALPINE_VERSION)
build-base-debian: build-debian-$(DEFAULT_DEBIAN_VERSION)
build-base-redhat: build-redhat-$(DEFAULT_REDHAT_VERSION)

# Dynamic target generation and validation
.PHONY: validate-lts-config
validate-lts-config:
	@echo "🔍 Validating LTS version configuration..."
	@for version in $(ALPINE_VERSIONS); do \
		if [ ! -f base-images/alpine/Dockerfile.$$version ]; then \
			echo "❌ Missing Alpine $$version Dockerfile"; \
			exit 1; \
		fi; \
	done
	@for version in $(DEBIAN_VERSIONS); do \
		if [ ! -f base-images/debian/Dockerfile.$$version ]; then \
			echo "❌ Missing Debian $$version Dockerfile"; \
			exit 1; \
		fi; \
	done
	@for version in $(REDHAT_VERSIONS); do \
		if [ ! -f base-images/redhat/Dockerfile.$$version ]; then \
			echo "❌ Missing RedHat $$version Dockerfile"; \
			exit 1; \
		fi; \
	done
	@echo "✅ LTS version configuration is valid"

.PHONY: show-lts-versions
show-lts-versions:
	@echo "📋 Current LTS version configuration:"
	@echo "  Alpine versions: $(ALPINE_VERSIONS)"
	@echo "  Debian versions: $(DEBIAN_VERSIONS)"
	@echo "  RedHat versions: $(REDHAT_VERSIONS)"
	@echo ""
	@echo "Default versions:"
	@echo "  Alpine default: $(DEFAULT_ALPINE_VERSION)"
	@echo "  Debian default: $(DEFAULT_DEBIAN_VERSION)"
	@echo "  RedHat default: $(DEFAULT_REDHAT_VERSION)"

.PHONY: show-platform-versions
show-platform-versions:
	@echo "📋 Current platform LTS version configuration:"
	@echo "  Nginx versions: $(NGINX_VERSIONS)"
	@echo "  OpenJDK versions: $(OPENJDK_VERSIONS)"
	@echo "  Tomcat versions: $(TOMCAT_VERSIONS)"
	@echo "  Python versions: $(PYTHON_VERSIONS)"
	@echo "  Spring Boot versions: $(SPRINGBOOT_VERSIONS)"
	@echo "  ASP.NET versions: $(ASPNET_VERSIONS)"
	@echo "  .NET Runtime versions: $(DOTNET_VERSIONS)"
	@echo ""
	@echo "Default versions:"
	@echo "  Nginx default: $(DEFAULT_NGINX_VERSION)"
	@echo "  OpenJDK default: $(DEFAULT_OPENJDK_VERSION)"
	@echo "  Tomcat default: $(DEFAULT_TOMCAT_VERSION)"
	@echo "  Python default: $(DEFAULT_PYTHON_VERSION)"
	@echo "  Spring Boot default: $(DEFAULT_SPRINGBOOT_VERSION)"
	@echo "  ASP.NET default: $(DEFAULT_ASPNET_VERSION)"
	@echo "  .NET Runtime default: $(DEFAULT_DOTNET_VERSION)"

.PHONY: validate-platform-config
validate-platform-config:
	@echo "🔍 Validating platform LTS version configuration..."
	@if [ -z "$(NGINX_VERSIONS)" ]; then echo "❌ Missing NGINX_VERSIONS configuration"; exit 1; fi
	@if [ -z "$(OPENJDK_VERSIONS)" ]; then echo "❌ Missing OPENJDK_VERSIONS configuration"; exit 1; fi
	@if [ -z "$(TOMCAT_VERSIONS)" ]; then echo "❌ Missing TOMCAT_VERSIONS configuration"; exit 1; fi
	@if [ -z "$(PYTHON_VERSIONS)" ]; then echo "❌ Missing PYTHON_VERSIONS configuration"; exit 1; fi
	@if [ -z "$(SPRINGBOOT_VERSIONS)" ]; then echo "❌ Missing SPRINGBOOT_VERSIONS configuration"; exit 1; fi
	@if [ -z "$(ASPNET_VERSIONS)" ]; then echo "❌ Missing ASPNET_VERSIONS configuration"; exit 1; fi
	@if [ -z "$(DOTNET_VERSIONS)" ]; then echo "❌ Missing DOTNET_VERSIONS configuration"; exit 1; fi
	@echo "✅ Platform LTS version configuration is valid"

# Build platform images (all LTS versions)
.PHONY: build-platform-images
build-platform-images: build-all-platforms

# Platform build targets are dynamically generated based on platform LTS versions in platform-lts-versions.env
# To add/remove platform versions, edit configs/platform-lts-versions.env and run: make validate-platform-config

# Build all images
.PHONY: build-all
build-all: build-base-images build-platform-images

# Push base images to GHCR
.PHONY: push-base-images
push-base-images: push-all-alpine-versions push-all-debian-versions push-all-redhat-versions

# Push all Alpine LTS versions
.PHONY: push-all-alpine-versions
push-all-alpine-versions: $(addprefix push-alpine-,$(ALPINE_VERSIONS))

push-alpine-3.18:
	@echo "📤 Pushing Alpine 3.18 LTS base image to GHCR..."
	docker push $(REGISTRY)/alpine-hardened:3.18

push-alpine-3.19:
	@echo "📤 Pushing Alpine 3.19 LTS base image to GHCR..."
	docker push $(REGISTRY)/alpine-hardened:3.19

push-alpine-3.20:
	@echo "📤 Pushing Alpine 3.20 LTS base image to GHCR..."
	docker push $(REGISTRY)/alpine-hardened:3.20

# Push all Debian LTS versions
.PHONY: push-all-debian-versions
push-all-debian-versions: $(addprefix push-debian-,$(DEBIAN_VERSIONS))

push-debian-11:
	@echo "📤 Pushing Debian 11 (Bullseye) LTS base image to GHCR..."
	docker push $(REGISTRY)/debian-hardened:11

push-debian-12:
	@echo "📤 Pushing Debian 12 (Bookworm) LTS base image to GHCR..."
	docker push $(REGISTRY)/debian-hardened:12

# Push all RedHat LTS versions
.PHONY: push-all-redhat-versions
push-all-redhat-versions: $(addprefix push-redhat-,$(REDHAT_VERSIONS))

push-redhat-8:
	@echo "📤 Pushing RedHat UBI 8 LTS base image to GHCR..."
	docker push $(REGISTRY)/redhat-hardened:8

push-redhat-9:
	@echo "📤 Pushing RedHat UBI 9 LTS base image to GHCR..."
	docker push $(REGISTRY)/redhat-hardened:9

# Legacy targets for backward compatibility
push-base-alpine: push-alpine-$(DEFAULT_ALPINE_VERSION)
push-base-debian: push-debian-$(DEFAULT_DEBIAN_VERSION)
push-base-redhat: push-redhat-$(DEFAULT_REDHAT_VERSION)

# Push platform images to GHCR (all LTS versions)
.PHONY: push-platform-images
push-platform-images: push-all-platforms

# Platform push targets are dynamically generated based on platform LTS versions in platform-lts-versions.env
# To add/remove platform versions, edit configs/platform-lts-versions.env and run: make validate-platform-config

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
		for image in $(REGISTRY)/alpine-hardened:3.18 \
			$(REGISTRY)/alpine-hardened:3.19 \
			$(REGISTRY)/alpine-hardened:3.20 \
			$(REGISTRY)/debian-hardened:11 \
			$(REGISTRY)/debian-hardened:12 \
			$(REGISTRY)/redhat-hardened:8 \
			$(REGISTRY)/redhat-hardened:9 \
			$(REGISTRY)/nginx-platform:$(PLATFORM_IMAGE_TAG) \
			$(REGISTRY)/openjdk-platform:$(PLATFORM_IMAGE_TAG) \
			$(REGISTRY)/python-platform:$(PLATFORM_IMAGE_TAG) \
			$(REGISTRY)/dotnet-platform:$(PLATFORM_IMAGE_TAG); do \
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