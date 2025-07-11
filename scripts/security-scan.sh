#!/bin/bash
# Security Scanning Script for Golden Images
# Uses Trivy to scan images for vulnerabilities

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SEVERITY_LEVELS="HIGH,CRITICAL"
EXIT_ON_VULNERABILITIES=false
OUTPUT_FORMAT="table"

# Load configuration
source configs/acr-config.env

echo "🔍 Starting security scan of golden images..."

# Function to scan an image
scan_image() {
    local image_name=$1
    local image_tag=$2
    local full_image="${ACR_LOGIN_SERVER}/${image_name}:${image_tag}"
    
    echo -e "${YELLOW}Scanning ${full_image}...${NC}"
    
    if command -v trivy >/dev/null 2>&1; then
        if trivy image --severity ${SEVERITY_LEVELS} --format ${OUTPUT_FORMAT} ${full_image}; then
            echo -e "${GREEN}✅ ${image_name} scan completed successfully${NC}"
        else
            echo -e "${RED}❌ ${image_name} scan found vulnerabilities${NC}"
            if [ "$EXIT_ON_VULNERABILITIES" = true ]; then
                exit 1
            fi
        fi
    else
        echo -e "${RED}❌ Trivy not found. Please install it to scan images.${NC}"
        exit 1
    fi
}

# Base images to scan
base_images=(
    "alpine-hardened:${BASE_IMAGE_TAG}"
    "debian-hardened:${BASE_IMAGE_TAG}"
    "redhat-hardened:${BASE_IMAGE_TAG}"
)

# Platform images to scan
platform_images=(
    "nginx-platform:${PLATFORM_IMAGE_TAG}"
    "openjdk-platform:${PLATFORM_IMAGE_TAG}"
    "tomcat-platform:${PLATFORM_IMAGE_TAG}"
    "python-platform:${PLATFORM_IMAGE_TAG}"
    "springboot-platform:${PLATFORM_IMAGE_TAG}"
    "aspnet-platform:${PLATFORM_IMAGE_TAG}"
    "dotnet-platform:${PLATFORM_IMAGE_TAG}"
)

# Scan base images
echo "📋 Scanning base images..."
for image in "${base_images[@]}"; do
    scan_image "$image" "$BASE_IMAGE_TAG"
done

# Scan platform images
echo "📋 Scanning platform images..."
for image in "${platform_images[@]}"; do
    scan_image "$image" "$PLATFORM_IMAGE_TAG"
done

echo -e "${GREEN}✅ Security scan completed!${NC}"

# Generate scan report
if command -v trivy >/dev/null 2>&1; then
    echo "📊 Generating scan report..."
    mkdir -p reports
    
    # Create HTML report
    trivy image --severity ${SEVERITY_LEVELS} --format html --output reports/security-scan-report.html \
        ${ACR_LOGIN_SERVER}/debian-hardened:${BASE_IMAGE_TAG} \
        ${ACR_LOGIN_SERVER}/nginx-platform:${PLATFORM_IMAGE_TAG} \
        ${ACR_LOGIN_SERVER}/openjdk-platform:${PLATFORM_IMAGE_TAG}
    
    echo -e "${GREEN}📄 Scan report generated: reports/security-scan-report.html${NC}"
fi 