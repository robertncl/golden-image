#!/bin/bash
# Build Helper Script for Golden Image Build System

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load configuration
source configs/acr-config.env

# Function to check prerequisites
check_prerequisites() {
    echo -e "${BLUE}🔍 Checking prerequisites...${NC}"
    
    # Check Docker
    if ! command -v docker >/dev/null 2>&1; then
        echo -e "${RED}❌ Docker is not installed${NC}"
        exit 1
    fi
    
    # Check Make
    if ! command -v make >/dev/null 2>&1; then
        echo -e "${RED}❌ Make is not installed${NC}"
        exit 1
    fi
    
    # Check if Docker daemon is running
    if ! docker info >/dev/null 2>&1; then
        echo -e "${RED}❌ Docker daemon is not running${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Prerequisites check passed${NC}"
}

# Function to validate ACR configuration
validate_acr_config() {
    echo -e "${BLUE}🔍 Validating ACR configuration...${NC}"
    
    if [ -z "$ACR_NAME" ] || [ -z "$ACR_LOGIN_SERVER" ]; then
        echo -e "${RED}❌ ACR configuration is incomplete${NC}"
        echo "Please update configs/acr-config.env with your ACR details"
        exit 1
    fi
    
    echo -e "${GREEN}✅ ACR configuration validated${NC}"
}

# Function to login to ACR
login_to_acr() {
    echo -e "${BLUE}🔐 Logging into Azure Container Registry...${NC}"
    
    if docker login $ACR_LOGIN_SERVER -u $ACR_USERNAME -p $ACR_PASSWORD; then
        echo -e "${GREEN}✅ Successfully logged into ACR${NC}"
    else
        echo -e "${RED}❌ Failed to login to ACR${NC}"
        exit 1
    fi
}

# Function to show build status
show_build_status() {
    echo -e "${BLUE}📊 Build Status:${NC}"
    
    # Check base images
    echo "Base Images:"
    for base in alpine debian redhat; do
        if docker images | grep -q "${ACR_LOGIN_SERVER}/alpine-hardened:${BASE_IMAGE_TAG}"; then
            echo -e "  ${GREEN}✅ ${base}-hardened${NC}"
        else
            echo -e "  ${RED}❌ ${base}-hardened${NC}"
        fi
    done
    
    # Check platform images
    echo "Platform Images:"
    for platform in nginx openjdk tomcat python springboot aspnet dotnet; do
        if docker images | grep -q "${ACR_LOGIN_SERVER}/${platform}-platform:${PLATFORM_IMAGE_TAG}"; then
            echo -e "  ${GREEN}✅ ${platform}-platform${NC}"
        else
            echo -e "  ${RED}❌ ${platform}-platform${NC}"
        fi
    done
}

# Function to clean up
cleanup() {
    echo -e "${BLUE}🧹 Cleaning up build artifacts...${NC}"
    
    # Remove dangling images
    docker image prune -f
    
    # Remove unused containers
    docker container prune -f
    
    # Remove unused networks
    docker network prune -f
    
    echo -e "${GREEN}✅ Cleanup completed${NC}"
}

# Function to show help
show_help() {
    echo "Golden Image Build Helper"
    echo "========================"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  check-prereqs    - Check if all prerequisites are met"
    echo "  validate-config  - Validate ACR configuration"
    echo "  login-acr        - Login to Azure Container Registry"
    echo "  build-status     - Show current build status"
    echo "  cleanup          - Clean up build artifacts"
    echo "  help             - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 check-prereqs"
    echo "  $0 login-acr"
    echo "  $0 build-status"
}

# Main script logic
case "${1:-help}" in
    check-prereqs)
        check_prerequisites
        ;;
    validate-config)
        validate_acr_config
        ;;
    login-acr)
        validate_acr_config
        login_to_acr
        ;;
    build-status)
        show_build_status
        ;;
    cleanup)
        cleanup
        ;;
    help|*)
        show_help
        ;;
esac 