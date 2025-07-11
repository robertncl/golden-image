#!/bin/bash
# Generate Platform Build Targets Script
# Dynamically generates platform build targets based on platform LTS version configuration

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load LTS version configurations
set -a
source configs/lts-versions.env
source configs/platform-lts-versions.env
set +a

# Function to get the latest version from a space-separated list
get_latest_version() {
    local versions="$1"
    for v in $versions; do latest=$v; done
    echo $latest
}

# Function to generate platform build targets for preferred OS (Alpine if possible, else Debian)
generate_platform_targets_preferred_os() {
    local platform_name="$1"
    local platform_versions_var="$2"
    local build_arg_name="$3"
    local image_dir="$4"
    local platform_versions=$(eval echo \${platform_versions_var})
    for platform_version in $platform_versions; do
        # Prefer Alpine if available
        if [ -n "$ALPINE_VERSIONS" ]; then
            os="alpine"
            os_versions="$ALPINE_VERSIONS"
        else
            os="debian"
            os_versions="$DEBIAN_VERSIONS"
        fi
        latest_os_version=$(get_latest_version "$os_versions")
        echo "build-$platform_name-$platform_version-$os-$latest_os_version:"
        echo "\t@echo \"🔨 Building $platform_name $platform_version on $os $latest_os_version LTS...\""
        echo "\tdocker build \$(BUILD_ARGS) \
\t\t--build-arg $build_arg_name=$platform_version \
\t\t--build-arg BASE_IMAGE=\$(REGISTRY)/$os-hardened:$latest_os_version \
\t\t-t \$(REGISTRY)/$platform_name-$platform_version-$os-$latest_os_version \
\t\tplatform-images/$image_dir/"
        echo ""
    done
}

# Nginx
# $1: platform name, $2: versions var, $3: build arg, $4: image dir
generate_nginx_targets() {
    echo "# Nginx build targets"
    generate_platform_targets_preferred_os "nginx" "NGINX_VERSIONS" "NGINX_VERSION" "nginx"
}
# OpenJDK
generate_openjdk_targets() {
    echo "# OpenJDK build targets"
    generate_platform_targets_preferred_os "openjdk" "OPENJDK_VERSIONS" "OPENJDK_VERSION" "openjdk"
}
# Tomcat
generate_tomcat_targets() {
    echo "# Tomcat build targets"
    generate_platform_targets_preferred_os "tomcat" "TOMCAT_VERSIONS" "TOMCAT_VERSION" "tomcat"
}
# Python
generate_python_targets() {
    echo "# Python build targets"
    generate_platform_targets_preferred_os "python" "PYTHON_VERSIONS" "PYTHON_VERSION" "python"
}
# Spring Boot
generate_springboot_targets() {
    echo "# Spring Boot build targets"
    generate_platform_targets_preferred_os "springboot" "SPRINGBOOT_VERSIONS" "SPRINGBOOT_VERSION" "springboot"
}

# Function to generate ASP.NET build targets
generate_aspnet_targets() {
    echo "# ASP.NET build targets"
    for aspnet_version in $ASPNET_VERSIONS; do
        for os in alpine debian redhat; do
            for os_version in $(eval echo \$${os^^}_VERSIONS); do
                echo "build-aspnet-$aspnet_version-$os-$os_version:"
                echo "	@echo \"🔨 Building ASP.NET $aspnet_version on $os $os_version LTS...\""
                echo "	docker build \$(BUILD_ARGS) \\"
                echo "		--build-arg ASPNET_VERSION=$aspnet_version \\"
                echo "		--build-arg BASE_IMAGE=\$(REGISTRY)/$os-hardened:$os_version \\"
                echo "		-t \$(REGISTRY)/aspnet-$aspnet_version-$os-$os_version \\"
                echo "		platform-images/aspnet/"
                echo ""
            done
        done
    done
}

# Function to generate .NET Runtime build targets
generate_dotnet_targets() {
    echo "# .NET Runtime build targets"
    for dotnet_version in $DOTNET_VERSIONS; do
        for os in alpine debian redhat; do
            for os_version in $(eval echo \$${os^^}_VERSIONS); do
                echo "build-dotnet-$dotnet_version-$os-$os_version:"
                echo "	@echo \"🔨 Building .NET Runtime $dotnet_version on $os $os_version LTS...\""
                echo "	docker build \$(BUILD_ARGS) \\"
                echo "		--build-arg DOTNET_VERSION=$dotnet_version \\"
                echo "		--build-arg BASE_IMAGE=\$(REGISTRY)/$os-hardened:$os_version \\"
                echo "		-t \$(REGISTRY)/dotnet-$dotnet_version-$os-$os_version \\"
                echo "		platform-images/dotnet/"
                echo ""
            done
        done
    done
}

# Function to generate push targets
generate_push_targets() {
    echo "# Platform push targets"
    for platform in nginx openjdk tomcat python springboot aspnet dotnet; do
        platform_upper=$(echo $platform | tr '[:lower:]' '[:upper:]')
        for platform_version in $(eval echo \$${platform_upper}_VERSIONS); do
            for os in alpine debian redhat; do
                for os_version in $(eval echo \$${os^^}_VERSIONS); do
                    echo "push-$platform-$platform_version-$os-$os_version:"
                    echo "	@echo \"📤 Pushing $platform $platform_version on $os $os_version to GHCR...\""
                    echo "	docker push \$(REGISTRY)/$platform-$platform_version-$os-$os_version"
                    echo ""
                done
            done
        done
    done
}

# Function to generate bulk build targets
generate_bulk_targets() {
    echo "# Bulk platform build targets"
    echo "build-all-platforms:"
    for platform in nginx openjdk tomcat python springboot aspnet dotnet; do
        platform_upper=$(echo $platform | tr '[:lower:]' '[:upper:]')
        for platform_version in $(eval echo \$${platform_upper}_VERSIONS); do
            for os in alpine debian redhat; do
                for os_version in $(eval echo \$${os^^}_VERSIONS); do
                    echo "	\$(MAKE) build-$platform-$platform_version-$os-$os_version"
                done
            done
        done
    done
    echo ""
    
    echo "push-all-platforms:"
    for platform in nginx openjdk tomcat python springboot aspnet dotnet; do
        platform_upper=$(echo $platform | tr '[:lower:]' '[:upper:]')
        for platform_version in $(eval echo \$${platform_upper}_VERSIONS); do
            for os in alpine debian redhat; do
                for os_version in $(eval echo \$${os^^}_VERSIONS); do
                    echo "	\$(MAKE) push-$platform-$platform_version-$os-$os_version"
                done
            done
        done
    done
}

# Function to generate validation targets
generate_validation_targets() {
    echo "# Platform validation targets"
    echo "validate-platform-config:"
    echo "	@echo \"🔍 Validating platform LTS version configuration...\""
    for platform in nginx openjdk tomcat python springboot aspnet dotnet; do
        platform_upper=$(echo $platform | tr '[:lower:]' '[:upper:]')
        echo "	@if [ -z \"\$${platform_upper}_VERSIONS\" ]; then \\"
        echo "		echo \"❌ Missing ${platform_upper}_VERSIONS configuration\"; \\"
        echo "		exit 1; \\"
        echo "	fi"
    done
    echo "	@echo \"✅ Platform LTS version configuration is valid\""
}

# Function to show platform versions
generate_show_platform_versions() {
    echo "# Show platform versions target"
    echo "show-platform-versions:"
    echo "	@echo \"📋 Current platform LTS version configuration:\""
    for platform in nginx openjdk tomcat python springboot aspnet dotnet; do
        platform_upper=$(echo $platform | tr '[:lower:]' '[:upper:]')
        echo "	@echo \"  $platform versions: \$${platform_upper}_VERSIONS\""
    done
    echo "	@echo \"\""
    echo "	@echo \"Default versions:\""
    for platform in nginx openjdk tomcat python springboot aspnet dotnet; do
        platform_upper=$(echo $platform | tr '[:lower:]' '[:upper:]')
        echo "	@echo \"  $platform default: \$${DEFAULT_${platform_upper}_VERSION}\""
    done
}

# Function to generate JSON matrix for GitHub Actions
generate_json_matrix() {
    echo "{"
    echo "  \"include\": ["
    
    # Generate matrix entries for each platform
    for platform in nginx openjdk tomcat python springboot aspnet dotnet; do
        platform_upper=$(echo $platform | tr '[:lower:]' '[:upper:]')
        for platform_version in $(eval echo \$${platform_upper}_VERSIONS); do
            for os in alpine debian redhat; do
                for os_version in $(eval echo \$${os^^}_VERSIONS); do
                    echo "    {"
                    echo "      \"platform\": \"$platform\","
                    echo "      \"platform_version\": \"$platform_version\","
                    echo "      \"platform_upper\": \"${platform_upper}_VERSION\","
                    echo "      \"os\": \"$os\","
                    echo "      \"os_version\": \"$os_version\""
                    if [ "$platform" = "dotnet" ] && [ "$platform_version" = "$(echo $DOTNET_VERSIONS | awk '{print $NF}')" ] && [ "$os" = "redhat" ] && [ "$os_version" = "$(echo $REDHAT_VERSIONS | awk '{print $NF}')" ]; then
                        echo "    }"
                    else
                        echo "    },"
                    fi
                done
            done
        done
    done
    
    echo "  ]"
    echo "}"
}

# Main execution
case "${1:-help}" in
    "json")
        generate_json_matrix
        ;;
    "build-targets")
        generate_nginx_targets
        generate_openjdk_targets
        generate_tomcat_targets
        generate_python_targets
        generate_springboot_targets
        generate_aspnet_targets
        generate_dotnet_targets
        ;;
    "push-targets")
        generate_push_targets
        ;;
    "bulk-targets")
        generate_bulk_targets
        ;;
    "validation-targets")
        generate_validation_targets
        ;;
    "show-versions")
        generate_show_platform_versions
        ;;
    "all")
        echo "# Generated platform build targets"
        generate_nginx_targets
        generate_openjdk_targets
        generate_tomcat_targets
        generate_python_targets
        generate_springboot_targets
        generate_aspnet_targets
        generate_dotnet_targets
        echo ""
        echo "# Generated platform push targets"
        generate_push_targets
        echo ""
        echo "# Generated bulk targets"
        generate_bulk_targets
        echo ""
        echo "# Generated validation targets"
        generate_validation_targets
        echo ""
        echo "# Generated show versions target"
        generate_show_platform_versions
        ;;
    *)
        echo "Usage: $0 {json|build-targets|push-targets|bulk-targets|validation-targets|show-versions|all}"
        echo ""
        echo "Available platform LTS versions:"
        echo "  Nginx: $NGINX_VERSIONS"
        echo "  OpenJDK: $OPENJDK_VERSIONS"
        echo "  Tomcat: $TOMCAT_VERSIONS"
        echo "  Python: $PYTHON_VERSIONS"
        echo "  Spring Boot: $SPRINGBOOT_VERSIONS"
        echo "  ASP.NET: $ASPNET_VERSIONS"
        echo "  .NET Runtime: $DOTNET_VERSIONS"
        echo ""
        echo "Examples:"
        echo "  $0 json              - Generate JSON matrix for GitHub Actions"
        echo "  $0 build-targets     - Generate build targets for all platforms"
        echo "  $0 push-targets      - Generate push targets for all platforms"
        echo "  $0 bulk-targets      - Generate bulk build/push targets"
        echo "  $0 validation-targets - Generate validation targets"
        echo "  $0 show-versions     - Generate show versions target"
        echo "  $0 all               - Generate all targets"
        ;;
esac 