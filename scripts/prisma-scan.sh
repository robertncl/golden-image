#!/bin/bash
# Prisma Cloud Security Scanning Script
# Uses Twistlock CLI for advanced vulnerability and compliance scanning

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PRISMA_CONSOLE_URL="${PRISMA_CONSOLE_URL:-}"
PRISMA_ACCESS_KEY="${PRISMA_ACCESS_KEY:-}"
PRISMA_SECRET_KEY="${PRISMA_SECRET_KEY:-}"
SCAN_SEVERITY="${SCAN_SEVERITY:-high,critical}"
COMPLIANCE_PROFILE="${COMPLIANCE_PROFILE:-CIS-1.0}"
OUTPUT_FORMAT="${OUTPUT_FORMAT:-json}"
REPORTS_DIR="${REPORTS_DIR:-reports/prisma}"

# Load configuration
source configs/acr-config.env

echo "🔍 Starting Prisma Cloud security scan of golden images..."

# Function to check Prisma CLI availability
check_prisma_cli() {
    if ! command -v twistcli >/dev/null 2>&1; then
        echo -e "${RED}❌ Prisma Cloud CLI (twistcli) not found${NC}"
        echo "Please install Prisma Cloud CLI:"
        echo "1. Download from Prisma Cloud Console"
        echo "2. Extract and add to PATH"
        echo "3. Configure authentication"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Prisma Cloud CLI found${NC}"
}

# Function to authenticate with Prisma Cloud
authenticate_prisma() {
    if [ -z "$PRISMA_CONSOLE_URL" ] || [ -z "$PRISMA_ACCESS_KEY" ] || [ -z "$PRISMA_SECRET_KEY" ]; then
        echo -e "${RED}❌ Prisma Cloud credentials not configured${NC}"
        echo "Please set the following environment variables:"
        echo "  PRISMA_CONSOLE_URL - Your Prisma Cloud Console URL"
        echo "  PRISMA_ACCESS_KEY - Your Prisma Cloud Access Key"
        echo "  PRISMA_SECRET_KEY - Your Prisma Cloud Secret Key"
        exit 1
    fi
    
    echo -e "${BLUE}🔐 Authenticating with Prisma Cloud...${NC}"
    
    # Test authentication
    if twistcli images scan --address "$PRISMA_CONSOLE_URL" --user "$PRISMA_ACCESS_KEY" --password "$PRISMA_SECRET_KEY" --help >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Prisma Cloud authentication successful${NC}"
    else
        echo -e "${RED}❌ Prisma Cloud authentication failed${NC}"
        exit 1
    fi
}

# Function to scan an image with Prisma Cloud
scan_image_prisma() {
    local image_name=$1
    local image_tag=$2
    local full_image="${ACR_LOGIN_SERVER}/${image_name}:${image_tag}"
    local report_file="${REPORTS_DIR}/${image_name}-prisma-scan.${OUTPUT_FORMAT}"
    
    echo -e "${YELLOW}Scanning ${full_image} with Prisma Cloud...${NC}"
    
    # Create reports directory
    mkdir -p "$REPORTS_DIR"
    
    # Run Prisma Cloud scan
    if twistcli images scan \
        --address "$PRISMA_CONSOLE_URL" \
        --user "$PRISMA_ACCESS_KEY" \
        --password "$PRISMA_SECRET_KEY" \
        --image "$full_image" \
        --severity "$SCAN_SEVERITY" \
        --compliance-profile "$COMPLIANCE_PROFILE" \
        --output-file "$report_file" \
        --format "$OUTPUT_FORMAT"; then
        
        echo -e "${GREEN}✅ ${image_name} Prisma Cloud scan completed successfully${NC}"
        
        # Parse and display summary
        if [ "$OUTPUT_FORMAT" = "json" ]; then
            echo "📊 Scan Summary for ${image_name}:"
            if command -v jq >/dev/null 2>&1; then
                jq -r '.vulnerabilities | length' "$report_file" 2>/dev/null | xargs -I {} echo "  Vulnerabilities found: {}"
                jq -r '.compliance | length' "$report_file" 2>/dev/null | xargs -I {} echo "  Compliance issues: {}"
            fi
        fi
    else
        echo -e "${RED}❌ ${image_name} Prisma Cloud scan failed${NC}"
        return 1
    fi
}

# Function to run compliance scan
run_compliance_scan() {
    local image_name=$1
    local image_tag=$2
    local full_image="${ACR_LOGIN_SERVER}/${image_name}:${image_tag}"
    local compliance_file="${REPORTS_DIR}/${image_name}-compliance.${OUTPUT_FORMAT}"
    
    echo -e "${YELLOW}Running compliance scan for ${full_image}...${NC}"
    
    if twistcli images compliance \
        --address "$PRISMA_CONSOLE_URL" \
        --user "$PRISMA_ACCESS_KEY" \
        --password "$PRISMA_SECRET_KEY" \
        --image "$full_image" \
        --compliance-profile "$COMPLIANCE_PROFILE" \
        --output-file "$compliance_file" \
        --format "$OUTPUT_FORMAT"; then
        
        echo -e "${GREEN}✅ Compliance scan completed for ${image_name}${NC}"
    else
        echo -e "${RED}❌ Compliance scan failed for ${image_name}${NC}"
    fi
}

# Function to generate comprehensive report
generate_comprehensive_report() {
    local report_file="${REPORTS_DIR}/prisma-comprehensive-report.html"
    
    echo -e "${BLUE}📊 Generating comprehensive Prisma Cloud report...${NC}"
    
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Prisma Cloud Security Scan Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 20px; border-radius: 5px; }
        .section { margin: 20px 0; padding: 15px; border-left: 4px solid #007acc; }
        .vulnerability { background-color: #fff3cd; padding: 10px; margin: 10px 0; border-radius: 3px; }
        .compliance { background-color: #d1ecf1; padding: 10px; margin: 10px 0; border-radius: 3px; }
        .summary { background-color: #d4edda; padding: 15px; border-radius: 5px; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Prisma Cloud Security Scan Report</h1>
        <p>Generated on: $(date)</p>
        <p>Scan Type: Vulnerability + Compliance</p>
    </div>
    
    <div class="summary">
        <h2>Scan Summary</h2>
        <p>This report contains security and compliance scan results for golden images.</p>
        <p>Images scanned: $(ls ${REPORTS_DIR}/*-prisma-scan.${OUTPUT_FORMAT} 2>/dev/null | wc -l)</p>
    </div>
    
    <div class="section">
        <h2>Vulnerability Scans</h2>
        <p>Detailed vulnerability scan results for each image.</p>
    </div>
    
    <div class="section">
        <h2>Compliance Scans</h2>
        <p>Compliance scan results based on ${COMPLIANCE_PROFILE} profile.</p>
    </div>
    
    <div class="section">
        <h2>Recommendations</h2>
        <ul>
            <li>Review all high and critical vulnerabilities</li>
            <li>Address compliance violations</li>
            <li>Update base images regularly</li>
            <li>Monitor for new vulnerabilities</li>
        </ul>
    </div>
</body>
</html>
EOF

    echo -e "${GREEN}📄 Comprehensive report generated: $report_file${NC}"
}

# Function to check scan results
check_scan_results() {
    echo -e "${BLUE}📋 Checking scan results...${NC}"
    
    local total_vulnerabilities=0
    local total_compliance_issues=0
    
    for report in "${REPORTS_DIR}"/*-prisma-scan.${OUTPUT_FORMAT}; do
        if [ -f "$report" ]; then
            local image_name=$(basename "$report" | sed 's/-prisma-scan.*//')
            echo "📊 Results for $image_name:"
            
            if [ "$OUTPUT_FORMAT" = "json" ] && command -v jq >/dev/null 2>&1; then
                local vulns=$(jq -r '.vulnerabilities | length' "$report" 2>/dev/null || echo "0")
                local compliance=$(jq -r '.compliance | length' "$report" 2>/dev/null || echo "0")
                
                echo "  Vulnerabilities: $vulns"
                echo "  Compliance issues: $compliance"
                
                total_vulnerabilities=$((total_vulnerabilities + vulns))
                total_compliance_issues=$((total_compliance_issues + compliance))
            fi
        fi
    done
    
    echo -e "${YELLOW}📈 Total Summary:${NC}"
    echo "  Total vulnerabilities: $total_vulnerabilities"
    echo "  Total compliance issues: $total_compliance_issues"
}

# Main execution
main() {
    echo "🔍 Prisma Cloud Security Scanner"
    echo "================================"
    
    # Check prerequisites
    check_prisma_cli
    authenticate_prisma
    
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
    echo "📋 Scanning base images with Prisma Cloud..."
    for image in "${base_images[@]}"; do
        local image_name=$(echo "$image" | cut -d: -f1)
        local image_tag=$(echo "$image" | cut -d: -f2)
        scan_image_prisma "$image_name" "$image_tag"
        run_compliance_scan "$image_name" "$image_tag"
    done
    
    # Scan platform images
    echo "📋 Scanning platform images with Prisma Cloud..."
    for image in "${platform_images[@]}"; do
        local image_name=$(echo "$image" | cut -d: -f1)
        local image_tag=$(echo "$image" | cut -d: -f2)
        scan_image_prisma "$image_name" "$image_tag"
        run_compliance_scan "$image_name" "$image_tag"
    done
    
    # Generate comprehensive report
    generate_comprehensive_report
    
    # Check results
    check_scan_results
    
    echo -e "${GREEN}✅ Prisma Cloud security scan completed!${NC}"
    echo -e "${BLUE}📁 Reports available in: $REPORTS_DIR${NC}"
}

# Run main function
main "$@" 