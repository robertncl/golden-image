#!/bin/bash
# Registry Sync Script
# Syncs images from GitHub Container Registry to Azure Container Registry

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load configurations as defaults only: values already in the environment (e.g.
# CI secrets) win over the placeholder credentials in configs/*.env. The files
# are parsed as KEY=VALUE data rather than executed with `source`.
load_config() {
    local key value
    while IFS='=' read -r key value; do
        [[ $key =~ ^[A-Z_][A-Z0-9_]*$ ]] || continue
        value="${value%\"}"; value="${value#\"}"
        [ -n "${!key:-}" ] || export "$key=$value"
    done < "$1"
}
load_config configs/ghcr-config.env
load_config configs/acr-config.env
load_config configs/lts-versions.env

echo "🔄 Starting registry sync from GHCR to ACR..."

# Function to check prerequisites
check_prerequisites() {
    echo -e "${BLUE}🔍 Checking prerequisites...${NC}"
    
    # Check Docker
    if ! command -v docker >/dev/null 2>&1; then
        echo -e "${RED}❌ Docker is not installed${NC}"
        exit 1
    fi
    
    # Check if Docker daemon is running
    if ! docker info >/dev/null 2>&1; then
        echo -e "${RED}❌ Docker daemon is not running${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Prerequisites check passed${NC}"
}

# Function to login to registries
login_to_registries() {
    echo -e "${BLUE}🔐 Logging into registries...${NC}"
    
    # Login to GitHub Container Registry
    if [ -n "$GHCR_USERNAME" ] && [ -n "$GHCR_PASSWORD" ]; then
        echo "Logging into GitHub Container Registry..."
        echo "$GHCR_PASSWORD" | docker login "$GHCR_REGISTRY" -u "$GHCR_USERNAME" --password-stdin
    else
        echo -e "${YELLOW}⚠️  GHCR credentials not configured, using GITHUB_TOKEN${NC}"
        echo "$GITHUB_TOKEN" | docker login "$GHCR_REGISTRY" -u "$GITHUB_ACTOR" --password-stdin
    fi
    
    # Login to Azure Container Registry
    if [ -n "$ACR_USERNAME" ] && [ -n "$ACR_PASSWORD" ]; then
        echo "Logging into Azure Container Registry..."
        echo "$ACR_PASSWORD" | docker login "$ACR_LOGIN_SERVER" -u "$ACR_USERNAME" --password-stdin
    else
        echo -e "${RED}❌ ACR credentials not configured${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Registry login successful${NC}"
}

# Function to sync a single image
sync_image() {
    local image_name=$1
    local image_tag=$2
    local source_image="${GHCR_REGISTRY}/${GHCR_NAMESPACE}/${image_name}:${image_tag}"
    local target_image="${ACR_LOGIN_SERVER}/${image_name}:${image_tag}"
    
    echo -e "${YELLOW}🔄 Syncing ${source_image} to ${target_image}...${NC}"
    
    # Pull image from GHCR
    if docker pull "$source_image"; then
        echo -e "${GREEN}✅ Successfully pulled ${source_image}${NC}"
        
        # Tag image for ACR
        docker tag "$source_image" "$target_image"
        
        # Push to ACR
        if docker push "$target_image"; then
            echo -e "${GREEN}✅ Successfully pushed ${target_image}${NC}"
            
            # Clean up local image
            docker rmi "$source_image" "$target_image" 2>/dev/null || true
            
            return 0
        else
            echo -e "${RED}❌ Failed to push ${target_image}${NC}"
            return 1
        fi
    else
        echo -e "${RED}❌ Failed to pull ${source_image}${NC}"
        return 1
    fi
}

# Function to sync all images
sync_all_images() {
    echo -e "${BLUE}🔄 Starting sync of all images...${NC}"
    
    local success_count=0
    local total_count=0
    
    # Base images to sync (all LTS versions from config)
    base_images=()
    
    # Add Alpine versions
    for version in $ALPINE_VERSIONS; do
        base_images+=("alpine-base:$version")
    done
    
    # Add Debian versions
    for version in $DEBIAN_VERSIONS; do
        base_images+=("debian-base:$version")
    done
    
    # Platform images to sync
    platform_images=(
        "nginx-platform:${PLATFORM_IMAGE_TAG}"
        "openjdk-platform:${PLATFORM_IMAGE_TAG}"
        "tomcat-platform:${PLATFORM_IMAGE_TAG}"
        "python-platform:${PLATFORM_IMAGE_TAG}"
        "springboot-platform:${PLATFORM_IMAGE_TAG}"
        "aspnet-platform:${PLATFORM_IMAGE_TAG}"
        "dotnet-platform:${PLATFORM_IMAGE_TAG}"
    )
    
    # Sync base images
    echo "📋 Syncing base images..."
    for image in "${base_images[@]}"; do
        local image_name=$(echo "$image" | cut -d: -f1)
        local image_tag=$(echo "$image" | cut -d: -f2)
        
        total_count=$((total_count + 1))
        if sync_image "$image_name" "$image_tag"; then
            success_count=$((success_count + 1))
        fi
    done
    
    # Sync platform images
    echo "📋 Syncing platform images..."
    for image in "${platform_images[@]}"; do
        local image_name=$(echo "$image" | cut -d: -f1)
        local image_tag=$(echo "$image" | cut -d: -f2)
        
        total_count=$((total_count + 1))
        if sync_image "$image_name" "$image_tag"; then
            success_count=$((success_count + 1))
        fi
    done
    
    echo -e "${GREEN}✅ Sync completed!${NC}"
    echo -e "${BLUE}📊 Summary:${NC}"
    echo "  Successful syncs: $success_count/$total_count"
    
    if [ $success_count -eq $total_count ]; then
        echo -e "${GREEN}🎉 All images synced successfully!${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️  Some images failed to sync${NC}"
        return 1
    fi
}

# Function to sync specific image
sync_specific_image() {
    local image_name=$1
    local image_tag=${2:-latest}
    
    echo -e "${BLUE}🔄 Syncing specific image: ${image_name}:${image_tag}${NC}"
    
    if sync_image "$image_name" "$image_tag"; then
        echo -e "${GREEN}✅ Image sync completed successfully!${NC}"
        return 0
    else
        echo -e "${RED}❌ Image sync failed!${NC}"
        return 1
    fi
}

# Function to show sync status
show_sync_status() {
    echo -e "${BLUE}📊 Checking sync status...${NC}"
    
    # Check base images (all LTS versions from config)
    echo "Base Images:"
    
    # Check Alpine versions
    for version in $ALPINE_VERSIONS; do
        local ghcr_image="${GHCR_REGISTRY}/${GHCR_NAMESPACE}/alpine-base:${version}"
        local acr_image="${ACR_LOGIN_SERVER}/alpine-base:${version}"
        
        if docker manifest inspect "$ghcr_image" >/dev/null 2>&1; then
            echo -e "  ${GREEN}✅ alpine-base:${version} (GHCR)${NC}"
        else
            echo -e "  ${RED}❌ alpine-base:${version} (GHCR)${NC}"
        fi
        
        if docker manifest inspect "$acr_image" >/dev/null 2>&1; then
            echo -e "  ${GREEN}✅ alpine-base:${version} (ACR)${NC}"
        else
            echo -e "  ${RED}❌ alpine-base:${version} (ACR)${NC}"
        fi
    done
    
    # Check Debian versions
    for version in $DEBIAN_VERSIONS; do
        local ghcr_image="${GHCR_REGISTRY}/${GHCR_NAMESPACE}/debian-base:${version}"
        local acr_image="${ACR_LOGIN_SERVER}/debian-base:${version}"
        
        if docker manifest inspect "$ghcr_image" >/dev/null 2>&1; then
            echo -e "  ${GREEN}✅ debian-base:${version} (GHCR)${NC}"
        else
            echo -e "  ${RED}❌ debian-base:${version} (GHCR)${NC}"
        fi
        
        if docker manifest inspect "$acr_image" >/dev/null 2>&1; then
            echo -e "  ${GREEN}✅ debian-base:${version} (ACR)${NC}"
        else
            echo -e "  ${RED}❌ debian-base:${version} (ACR)${NC}"
        fi
    done
    
    # Check platform images
    echo "Platform Images:"
    for platform in nginx openjdk tomcat python springboot aspnet dotnet; do
        local ghcr_image="${GHCR_REGISTRY}/${GHCR_NAMESPACE}/${platform}-platform:${PLATFORM_IMAGE_TAG}"
        local acr_image="${ACR_LOGIN_SERVER}/${platform}-platform:${PLATFORM_IMAGE_TAG}"
        
        if docker manifest inspect "$ghcr_image" >/dev/null 2>&1; then
            echo -e "  ${GREEN}✅ ${platform}-platform (GHCR)${NC}"
        else
            echo -e "  ${RED}❌ ${platform}-platform (GHCR)${NC}"
        fi
        
        if docker manifest inspect "$acr_image" >/dev/null 2>&1; then
            echo -e "  ${GREEN}✅ ${platform}-platform (ACR)${NC}"
        else
            echo -e "  ${RED}❌ ${platform}-platform (ACR)${NC}"
        fi
    done
}

# Function to show help
show_help() {
    echo "Registry Sync Tool"
    echo "=================="
    echo ""
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  sync-all           - Sync all images from GHCR to ACR"
    echo "  sync-image         - Sync a specific image (requires image name)"
    echo "  status             - Show sync status of all images"
    echo "  help               - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 sync-all                    # Sync all images"
    echo "  $0 sync-image debian-hardened  # Sync specific image"
    echo "  $0 sync-image nginx-platform latest  # Sync with specific tag"
    echo "  $0 status                       # Check sync status"
    echo ""
    echo "Configuration:"
    echo "  - Edit configs/ghcr-config.env for GHCR settings"
    echo "  - Edit configs/acr-config.env for ACR settings"
}

# Main execution
main() {
    case "${1:-help}" in
        sync-all)
            check_prerequisites
            login_to_registries
            sync_all_images
            ;;
        sync-image)
            if [ -z "$2" ]; then
                echo -e "${RED}❌ Please specify image name${NC}"
                exit 1
            fi
            check_prerequisites
            login_to_registries
            sync_specific_image "$2" "$3"
            ;;
        status)
            check_prerequisites
            login_to_registries
            show_sync_status
            ;;
        help|*)
            show_help
            ;;
    esac
}

# Run main function
main "$@" 