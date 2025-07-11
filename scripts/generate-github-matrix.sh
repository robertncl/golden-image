#!/bin/bash
# Generate GitHub Actions Matrix Script
# Dynamically generates GitHub Actions matrix from LTS version configuration

set -e

# Load LTS version configuration
set -a
source configs/lts-versions.env
set +a

echo "🔧 Generating GitHub Actions matrix from LTS version configuration..."

# Function to generate matrix JSON
generate_matrix() {
    echo "{"
    echo "  \"include\": ["
    
    # Alpine versions
    for version in $ALPINE_VERSIONS; do
        echo "    {"
        echo "      \"os\": \"alpine\","
        echo "      \"version\": \"$version\""
        if [ "$version" = "$(echo $ALPINE_VERSIONS | awk '{print $NF}')" ] && [ "$(echo $DEBIAN_VERSIONS | wc -w)" -eq 0 ] && [ "$(echo $REDHAT_VERSIONS | wc -w)" -eq 0 ]; then
            echo "    }"
        else
            echo "    },"
        fi
    done
    
    # Debian versions
    for version in $DEBIAN_VERSIONS; do
        echo "    {"
        echo "      \"os\": \"debian\","
        echo "      \"version\": \"$version\""
        if [ "$version" = "$(echo $DEBIAN_VERSIONS | awk '{print $NF}')" ] && [ "$(echo $REDHAT_VERSIONS | wc -w)" -eq 0 ]; then
            echo "    }"
        else
            echo "    },"
        fi
    done
    
    # RedHat versions
    for version in $REDHAT_VERSIONS; do
        echo "    {"
        echo "      \"os\": \"redhat\","
        echo "      \"version\": \"$version\""
        if [ "$version" = "$(echo $REDHAT_VERSIONS | awk '{print $NF}')" ]; then
            echo "    }"
        else
            echo "    },"
        fi
    done
    
    echo "  ]"
    echo "}"
}

# Function to generate YAML matrix
generate_yaml_matrix() {
    echo "matrix:"
    echo "  include:"
    
    # Alpine versions
    for version in $ALPINE_VERSIONS; do
        echo "    - os: alpine"
        echo "      version: $version"
    done
    
    # Debian versions
    for version in $DEBIAN_VERSIONS; do
        echo "    - os: debian"
        echo "      version: $version"
    done
    
    # RedHat versions
    for version in $REDHAT_VERSIONS; do
        echo "    - os: redhat"
        echo "      version: $version"
    done
}

# Function to generate scanning list
generate_scanning_list() {
    echo "# Scanning list for all LTS versions"
    echo "scanning_images:"
    
    # Alpine versions
    for version in $ALPINE_VERSIONS; do
        echo "  - \${{ env.REGISTRY }}/alpine-hardened:$version"
    done
    
    # Debian versions
    for version in $DEBIAN_VERSIONS; do
        echo "  - \${{ env.REGISTRY }}/debian-hardened:$version"
    done
    
    # RedHat versions
    for version in $REDHAT_VERSIONS; do
        echo "  - \${{ env.REGISTRY }}/redhat-hardened:$version"
    done
}

# Main execution
case "${1:-help}" in
    "json")
        generate_matrix
        ;;
    "yaml")
        generate_yaml_matrix
        ;;
    "scanning")
        generate_scanning_list
        ;;
    "all")
        echo "=== JSON Matrix ==="
        generate_matrix
        echo ""
        echo "=== YAML Matrix ==="
        generate_yaml_matrix
        echo ""
        echo "=== Scanning List ==="
        generate_scanning_list
        ;;
    *)
        echo "Usage: $0 {json|yaml|scanning|all}"
        echo ""
        echo "Available LTS versions:"
        echo "  Alpine: $ALPINE_VERSIONS"
        echo "  Debian: $DEBIAN_VERSIONS"
        echo "  RedHat: $REDHAT_VERSIONS"
        echo ""
        echo "Examples:"
        echo "  $0 json     - Generate JSON matrix for GitHub Actions"
        echo "  $0 yaml     - Generate YAML matrix for GitHub Actions"
        echo "  $0 scanning - Generate scanning list for all versions"
        echo "  $0 all      - Generate all formats"
        ;;
esac 