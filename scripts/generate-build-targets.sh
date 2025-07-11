#!/bin/bash
# Generate Build Targets Script
# Dynamically generates build targets based on LTS version configuration

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load LTS version configuration
source configs/lts-versions.env

echo -e "${BLUE}🔧 Generating build targets from LTS version configuration...${NC}"

# Function to generate Alpine build targets
generate_alpine_targets() {
    echo "# Alpine Linux build targets"
    for version in $ALPINE_VERSIONS; do
        echo "build-alpine-$version:"
        echo "	@echo \"🔨 Building Alpine $version LTS base image...\""
        echo "	docker build \$(BUILD_ARGS) -f base-images/alpine/Dockerfile.$version -t \$(REGISTRY)/alpine-hardened:$version base-images/alpine/"
        echo ""
    done
}

# Function to generate Debian build targets
generate_debian_targets() {
    echo "# Debian build targets"
    for version in $DEBIAN_VERSIONS; do
        echo "build-debian-$version:"
        echo "	@echo \"🔨 Building Debian $version LTS base image...\""
        echo "	docker build \$(BUILD_ARGS) -f base-images/debian/Dockerfile.$version -t \$(REGISTRY)/debian-hardened:$version base-images/debian/"
        echo ""
    done
}

# Function to generate RedHat build targets
generate_redhat_targets() {
    echo "# RedHat UBI build targets"
    for version in $REDHAT_VERSIONS; do
        echo "build-redhat-$version:"
        echo "	@echo \"🔨 Building RedHat UBI $version LTS base image...\""
        echo "	docker build \$(BUILD_ARGS) -f base-images/redhat/Dockerfile.$version -t \$(REGISTRY)/redhat-hardened:$version base-images/redhat/"
        echo ""
    done
}

# Function to generate Alpine push targets
generate_alpine_push_targets() {
    echo "# Alpine Linux push targets"
    for version in $ALPINE_VERSIONS; do
        echo "push-alpine-$version:"
        echo "	@echo \"📤 Pushing Alpine $version LTS base image to GHCR...\""
        echo "	docker push \$(REGISTRY)/alpine-hardened:$version"
        echo ""
    done
}

# Function to generate Debian push targets
generate_debian_push_targets() {
    echo "# Debian push targets"
    for version in $DEBIAN_VERSIONS; do
        echo "push-debian-$version:"
        echo "	@echo \"📤 Pushing Debian $version LTS base image to GHCR...\""
        echo "	docker push \$(REGISTRY)/debian-hardened:$version"
        echo ""
    done
}

# Function to generate RedHat push targets
generate_redhat_push_targets() {
    echo "# RedHat UBI push targets"
    for version in $REDHAT_VERSIONS; do
        echo "push-redhat-$version:"
        echo "	@echo \"📤 Pushing RedHat UBI $version LTS base image to GHCR...\""
        echo "	docker push \$(REGISTRY)/redhat-hardened:$version"
        echo ""
    done
}

# Function to generate help text
generate_help_text() {
    echo "# LTS Version Targets:"
    echo "	@echo \"  Alpine LTS versions: $ALPINE_VERSIONS\""
    echo "	@echo \"  Debian LTS versions: $DEBIAN_VERSIONS\""
    echo "	@echo \"  RedHat LTS versions: $REDHAT_VERSIONS\""
    echo "	@echo \"\""
    echo "	@echo \"  Build targets: build-alpine-<version>, build-debian-<version>, build-redhat-<version>\""
    echo "	@echo \"  Push targets: push-alpine-<version>, push-debian-<version>, push-redhat-<version>\""
}

# Function to generate scanning targets
generate_scanning_targets() {
    echo "# Scanning targets for all LTS versions"
    echo "scan-all-lts-versions:"
    echo "	@echo \"🔍 Scanning all LTS versions for vulnerabilities...\""
    echo "	@if command -v trivy >/dev/null 2>&1; then \\"
    
    # Alpine scanning
    for version in $ALPINE_VERSIONS; do
        echo "		echo \"Scanning Alpine $version...\"; \\"
        echo "		trivy image --severity HIGH,CRITICAL \$(REGISTRY)/alpine-hardened:$version; \\"
    done
    
    # Debian scanning
    for version in $DEBIAN_VERSIONS; do
        echo "		echo \"Scanning Debian $version...\"; \\"
        echo "		trivy image --severity HIGH,CRITICAL \$(REGISTRY)/debian-hardened:$version; \\"
    done
    
    # RedHat scanning
    for version in $REDHAT_VERSIONS; do
        echo "		echo \"Scanning RedHat $version...\"; \\"
        echo "		trivy image --severity HIGH,CRITICAL \$(REGISTRY)/redhat-hardened:$version; \\"
    done
    
    echo "	else \\"
    echo "		echo \"Trivy not found. Install it to scan images for vulnerabilities.\"; \\"
    echo "	fi"
}

# Function to generate Dockerfile creation targets
generate_dockerfile_targets() {
    echo "# Dockerfile creation targets"
    echo "create-alpine-dockerfiles:"
    for version in $ALPINE_VERSIONS; do
        echo "	@if [ ! -f base-images/alpine/Dockerfile.$version ]; then \\"
        echo "		echo \"Creating Alpine $version Dockerfile...\"; \\"
        echo "		cp base-images/alpine/Dockerfile base-images/alpine/Dockerfile.$version; \\"
        echo "		sed -i 's/FROM alpine:.*/FROM alpine:$version/' base-images/alpine/Dockerfile.$version; \\"
        echo "	fi"
    done
    echo ""
    
    echo "create-debian-dockerfiles:"
    for version in $DEBIAN_VERSIONS; do
        echo "	@if [ ! -f base-images/debian/Dockerfile.$version ]; then \\"
        echo "		echo \"Creating Debian $version Dockerfile...\"; \\"
        echo "		cp base-images/debian/Dockerfile base-images/debian/Dockerfile.$version; \\"
        echo "		sed -i 's/FROM debian:.*/FROM debian:$version-slim/' base-images/debian/Dockerfile.$version; \\"
        echo "	fi"
    done
    echo ""
    
    echo "create-redhat-dockerfiles:"
    for version in $REDHAT_VERSIONS; do
        echo "	@if [ ! -f base-images/redhat/Dockerfile.$version ]; then \\"
        echo "		echo \"Creating RedHat $version Dockerfile...\"; \\"
        echo "		cp base-images/redhat/Dockerfile base-images/redhat/Dockerfile.$version; \\"
        echo "		sed -i 's/FROM registry.access.redhat.com\/ubi.*/FROM registry.access.redhat.com\/ubi$version\/ubi-minimal:latest/' base-images/redhat/Dockerfile.$version; \\"
        echo "	fi"
    done
}

# Function to generate validation targets
generate_validation_targets() {
    echo "# Validation targets"
    echo "validate-lts-config:"
    echo "	@echo \"🔍 Validating LTS version configuration...\""
    echo "	@for version in $ALPINE_VERSIONS; do \\"
    echo "		if [ ! -f base-images/alpine/Dockerfile.\$$version ]; then \\"
    echo "			echo \"❌ Missing Alpine \$$version Dockerfile\"; \\"
    echo "			exit 1; \\"
    echo "		fi; \\"
    echo "	done"
    echo "	@for version in $DEBIAN_VERSIONS; do \\"
    echo "		if [ ! -f base-images/debian/Dockerfile.\$$version ]; then \\"
    echo "			echo \"❌ Missing Debian \$$version Dockerfile\"; \\"
    echo "			exit 1; \\"
    echo "		fi; \\"
    echo "	done"
    echo "	@for version in $REDHAT_VERSIONS; do \\"
    echo "		if [ ! -f base-images/redhat/Dockerfile.\$$version ]; then \\"
    echo "			echo \"❌ Missing RedHat \$$version Dockerfile\"; \\"
    echo "			exit 1; \\"
    echo "		fi; \\"
    echo "	done"
    echo "	@echo \"✅ LTS version configuration is valid\""
}

# Main execution
case "${1:-help}" in
    "build-targets")
        generate_alpine_targets
        generate_debian_targets
        generate_redhat_targets
        ;;
    "push-targets")
        generate_alpine_push_targets
        generate_debian_push_targets
        generate_redhat_push_targets
        ;;
    "help-text")
        generate_help_text
        ;;
    "scanning-targets")
        generate_scanning_targets
        ;;
    "dockerfile-targets")
        generate_dockerfile_targets
        ;;
    "validation-targets")
        generate_validation_targets
        ;;
    "all")
        echo "# Generated build targets"
        generate_alpine_targets
        generate_debian_targets
        generate_redhat_targets
        echo ""
        echo "# Generated push targets"
        generate_alpine_push_targets
        generate_debian_push_targets
        generate_redhat_push_targets
        echo ""
        echo "# Generated scanning targets"
        generate_scanning_targets
        echo ""
        echo "# Generated validation targets"
        generate_validation_targets
        ;;
    *)
        echo "Usage: $0 {build-targets|push-targets|help-text|scanning-targets|dockerfile-targets|validation-targets|all}"
        echo ""
        echo "Available LTS versions:"
        echo "  Alpine: $ALPINE_VERSIONS"
        echo "  Debian: $DEBIAN_VERSIONS"
        echo "  RedHat: $REDHAT_VERSIONS"
        ;;
esac 