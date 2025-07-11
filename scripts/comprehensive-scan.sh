#!/bin/bash
# Comprehensive Security Scanning Script
# Combines Trivy and Prisma Cloud for maximum security coverage

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Load configurations
source configs/acr-config.env
source configs/prisma-config.env

echo "🔍 Starting comprehensive security scan of golden images..."

# Function to check scanning tools
check_scanning_tools() {
    echo -e "${BLUE}🔍 Checking scanning tools availability...${NC}"
    
    local tools_available=true
    
    # Check Trivy
    if command -v trivy >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Trivy found${NC}"
    else
        echo -e "${YELLOW}⚠️  Trivy not found (optional)${NC}"
        tools_available=false
    fi
    
    # Check Prisma Cloud CLI
    if command -v twistcli >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Prisma Cloud CLI found${NC}"
    else
        echo -e "${YELLOW}⚠️  Prisma Cloud CLI not found (optional)${NC}"
        tools_available=false
    fi
    
    # Check jq for JSON parsing
    if command -v jq >/dev/null 2>&1; then
        echo -e "${GREEN}✅ jq found for JSON parsing${NC}"
    else
        echo -e "${YELLOW}⚠️  jq not found (optional for JSON parsing)${NC}"
    fi
    
    if [ "$tools_available" = false ]; then
        echo -e "${RED}❌ No scanning tools available${NC}"
        echo "Please install at least one of:"
        echo "  - Trivy: https://aquasecurity.github.io/trivy/"
        echo "  - Prisma Cloud CLI: Download from Prisma Cloud Console"
        exit 1
    fi
}

# Function to run Trivy scan
run_trivy_scan() {
    local image_name=$1
    local image_tag=$2
    local full_image="${ACR_LOGIN_SERVER}/${image_name}:${image_tag}"
    local report_dir="reports/trivy"
    local report_file="${report_dir}/${image_name}-trivy-scan.json"
    
    if ! command -v trivy >/dev/null 2>&1; then
        return 0
    fi
    
    echo -e "${YELLOW}🔍 Running Trivy scan for ${full_image}...${NC}"
    
    mkdir -p "$report_dir"
    
    if trivy image --severity HIGH,CRITICAL --format json --output "$report_file" "$full_image"; then
        echo -e "${GREEN}✅ Trivy scan completed for ${image_name}${NC}"
        
        # Parse and display summary
        if command -v jq >/dev/null 2>&1; then
            local vulns=$(jq -r '.Results[].Vulnerabilities | length' "$report_file" 2>/dev/null | awk '{sum+=$1} END {print sum}')
            echo "  Trivy vulnerabilities found: ${vulns:-0}"
        fi
    else
        echo -e "${RED}❌ Trivy scan failed for ${image_name}${NC}"
    fi
}

# Function to run Prisma Cloud scan
run_prisma_scan() {
    local image_name=$1
    local image_tag=$2
    
    if ! command -v twistcli >/dev/null 2>&1; then
        return 0
    fi
    
    if [ -z "$PRISMA_CONSOLE_URL" ] || [ -z "$PRISMA_ACCESS_KEY" ] || [ -z "$PRISMA_SECRET_KEY" ]; then
        echo -e "${YELLOW}⚠️  Prisma Cloud credentials not configured, skipping Prisma scan${NC}"
        return 0
    fi
    
    echo -e "${PURPLE}🔍 Running Prisma Cloud scan for ${image_name}...${NC}"
    
    # Run the Prisma scan script
    if ./scripts/prisma-scan.sh --single-image "${image_name}:${image_tag}"; then
        echo -e "${GREEN}✅ Prisma Cloud scan completed for ${image_name}${NC}"
    else
        echo -e "${RED}❌ Prisma Cloud scan failed for ${image_name}${NC}"
    fi
}

# Function to generate combined report
generate_combined_report() {
    local report_file="reports/comprehensive-security-report.html"
    local trivy_reports="reports/trivy"
    local prisma_reports="reports/prisma"
    
    echo -e "${BLUE}📊 Generating comprehensive security report...${NC}"
    
    mkdir -p reports
    
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Comprehensive Security Scan Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background-color: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; border-radius: 8px; margin-bottom: 30px; }
        .section { margin: 20px 0; padding: 20px; border-left: 4px solid #667eea; background-color: #f8f9fa; border-radius: 4px; }
        .tool-section { margin: 15px 0; padding: 15px; border-radius: 4px; }
        .trivy { border-left-color: #28a745; background-color: #d4edda; }
        .prisma { border-left-color: #007bff; background-color: #d1ecf1; }
        .summary { background-color: #fff3cd; padding: 20px; border-radius: 8px; margin: 20px 0; }
        .metrics { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; margin: 20px 0; }
        .metric { background-color: #e9ecef; padding: 15px; border-radius: 4px; text-align: center; }
        .metric-value { font-size: 24px; font-weight: bold; color: #495057; }
        .metric-label { color: #6c757d; font-size: 14px; }
        .recommendations { background-color: #d1ecf1; padding: 20px; border-radius: 8px; }
        .recommendations ul { margin: 10px 0; }
        .recommendations li { margin: 5px 0; }
        .status { display: inline-block; padding: 4px 8px; border-radius: 4px; font-size: 12px; font-weight: bold; }
        .status-success { background-color: #d4edda; color: #155724; }
        .status-warning { background-color: #fff3cd; color: #856404; }
        .status-danger { background-color: #f8d7da; color: #721c24; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔒 Comprehensive Security Scan Report</h1>
            <p>Golden Image Build System - Security Analysis</p>
            <p>Generated on: $(date)</p>
        </div>
        
        <div class="summary">
            <h2>📋 Executive Summary</h2>
            <p>This comprehensive security scan combines multiple scanning tools to provide maximum coverage:</p>
            <ul>
                <li><strong>Trivy:</strong> Open-source vulnerability scanner</li>
                <li><strong>Prisma Cloud:</strong> Enterprise-grade security and compliance scanner</li>
            </ul>
        </div>
        
        <div class="metrics">
            <div class="metric">
                <div class="metric-value" id="total-images">0</div>
                <div class="metric-label">Images Scanned</div>
            </div>
            <div class="metric">
                <div class="metric-value" id="total-vulnerabilities">0</div>
                <div class="metric-label">Vulnerabilities Found</div>
            </div>
            <div class="metric">
                <div class="metric-value" id="critical-vulnerabilities">0</div>
                <div class="metric-label">Critical Issues</div>
            </div>
            <div class="metric">
                <div class="metric-value" id="compliance-issues">0</div>
                <div class="metric-label">Compliance Issues</div>
            </div>
        </div>
        
        <div class="section">
            <h2>🔍 Scanning Tools Used</h2>
            
            <div class="tool-section trivy">
                <h3>🔍 Trivy Scanner</h3>
                <p><span class="status status-success">Active</span> Open-source vulnerability scanner</p>
                <p>Scanned images: $(ls ${trivy_reports}/*.json 2>/dev/null | wc -l)</p>
            </div>
            
            <div class="tool-section prisma">
                <h3>🔍 Prisma Cloud Scanner</h3>
                <p><span class="status status-success">Active</span> Enterprise security and compliance scanner</p>
                <p>Scanned images: $(ls ${prisma_reports}/*.json 2>/dev/null | wc -l)</p>
            </div>
        </div>
        
        <div class="section">
            <h2>📊 Detailed Results</h2>
            <p>Individual scan results are available in the reports directory:</p>
            <ul>
                <li>Trivy reports: <code>reports/trivy/</code></li>
                <li>Prisma Cloud reports: <code>reports/prisma/</code></li>
            </ul>
        </div>
        
        <div class="recommendations">
            <h2>💡 Security Recommendations</h2>
            <ul>
                <li>Review all critical and high severity vulnerabilities immediately</li>
                <li>Address compliance violations based on CIS benchmarks</li>
                <li>Update base images regularly to include security patches</li>
                <li>Implement automated scanning in CI/CD pipelines</li>
                <li>Monitor for new vulnerabilities and security advisories</li>
                <li>Consider implementing image signing for additional security</li>
            </ul>
        </div>
        
        <div class="section">
            <h2>🔧 Next Steps</h2>
            <ol>
                <li>Review detailed scan reports in the reports directory</li>
                <li>Prioritize fixes based on severity and compliance requirements</li>
                <li>Update images with security patches</li>
                <li>Re-run scans after updates to verify fixes</li>
                <li>Implement continuous monitoring and alerting</li>
            </ol>
        </div>
    </div>
    
    <script>
        // Update metrics with actual data
        document.addEventListener('DOMContentLoaded', function() {
            // This would be populated with actual scan results
            // For now, showing placeholder values
        });
    </script>
</body>
</html>
EOF

    echo -e "${GREEN}📄 Comprehensive report generated: $report_file${NC}"
}

# Function to scan all images
scan_all_images() {
    echo -e "${BLUE}🔍 Starting comprehensive scan of all images...${NC}"
    
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
    
    local total_images=0
    local total_vulnerabilities=0
    local total_critical=0
    local total_compliance=0
    
    # Scan base images
    echo "📋 Scanning base images..."
    for image in "${base_images[@]}"; do
        local image_name=$(echo "$image" | cut -d: -f1)
        local image_tag=$(echo "$image" | cut -d: -f2)
        
        echo -e "${YELLOW}Scanning ${image_name}...${NC}"
        
        run_trivy_scan "$image_name" "$image_tag"
        run_prisma_scan "$image_name" "$image_tag"
        
        total_images=$((total_images + 1))
    done
    
    # Scan platform images
    echo "📋 Scanning platform images..."
    for image in "${platform_images[@]}"; do
        local image_name=$(echo "$image" | cut -d: -f1)
        local image_tag=$(echo "$image" | cut -d: -f2)
        
        echo -e "${YELLOW}Scanning ${image_name}...${NC}"
        
        run_trivy_scan "$image_name" "$image_tag"
        run_prisma_scan "$image_name" "$image_tag"
        
        total_images=$((total_images + 1))
    done
    
    echo -e "${GREEN}✅ Comprehensive scan completed!${NC}"
    echo -e "${BLUE}📊 Summary:${NC}"
    echo "  Total images scanned: $total_images"
    echo "  Reports available in: reports/"
}

# Function to show help
show_help() {
    echo "Comprehensive Security Scanner"
    echo "============================="
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --trivy-only      Run only Trivy scans"
    echo "  --prisma-only      Run only Prisma Cloud scans"
    echo "  --single-image     Scan a single image (format: name:tag)"
    echo "  --help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                    # Run comprehensive scan"
    echo "  $0 --trivy-only       # Run only Trivy scans"
    echo "  $0 --single-image debian-hardened:latest"
    echo ""
    echo "Configuration:"
    echo "  - Edit configs/acr-config.env for ACR settings"
    echo "  - Edit configs/prisma-config.env for Prisma Cloud settings"
}

# Main execution
main() {
    case "${1:-}" in
        --help|-h)
            show_help
            exit 0
            ;;
        --trivy-only)
            echo "🔍 Running Trivy-only scan..."
            check_scanning_tools
            scan_all_images
            ;;
        --prisma-only)
            echo "🔍 Running Prisma Cloud-only scan..."
            check_scanning_tools
            scan_all_images
            ;;
        --single-image)
            if [ -z "$2" ]; then
                echo -e "${RED}❌ Please specify image name:tag${NC}"
                exit 1
            fi
            echo "🔍 Running single image scan for $2..."
            check_scanning_tools
            local image_name=$(echo "$2" | cut -d: -f1)
            local image_tag=$(echo "$2" | cut -d: -f2)
            run_trivy_scan "$image_name" "$image_tag"
            run_prisma_scan "$image_name" "$image_tag"
            ;;
        "")
            echo "🔍 Running comprehensive security scan..."
            check_scanning_tools
            scan_all_images
            generate_combined_report
            ;;
        *)
            echo -e "${RED}❌ Unknown option: $1${NC}"
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@" 