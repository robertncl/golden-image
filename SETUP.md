# Golden Image Build System Setup Guide

This guide will help you set up and configure the Golden Image Build System for your environment.

## Prerequisites

### System Requirements
- Docker 20.10 or later
- Make 4.0 or later
- Git
- Bash shell
- At least 8GB RAM and 20GB free disk space

### Azure Requirements
- Azure Container Registry (ACR)
- Azure CLI (optional, for management)

## Quick Start

### 1. Clone the Repository
```bash
git clone <your-repo-url>
cd golden-image
```

### 2. Configure Azure Container Registry

Edit `configs/acr-config.env` with your ACR details:

```bash
# Azure Container Registry Configuration
ACR_NAME=your-acr-name
ACR_LOGIN_SERVER=your-acr-name.azurecr.io
ACR_USERNAME=your-acr-username
ACR_PASSWORD=your-acr-password

# Image Tags
BASE_IMAGE_TAG=latest
PLATFORM_IMAGE_TAG=latest

# Build Configuration
BUILD_PLATFORMS=linux/amd64,linux/arm64
BUILD_CACHE=true
BUILD_PUSH=true

# Security Scanning
SCAN_IMAGES=true
TRIVY_ENABLED=true
```

### 3. Make Scripts Executable
```bash
chmod +x scripts/*.sh
```

### 4. Check Prerequisites
```bash
./scripts/build-helper.sh check-prereqs
```

### 5. Validate Configuration
```bash
./scripts/build-helper.sh validate-config
```

### 6. Login to ACR
```bash
./scripts/build-helper.sh login-acr
```

### 7. Build All Images
```bash
make build-all
```

### 8. Push Images to ACR
```bash
make push-all
```

### 9. Scan for Vulnerabilities
```bash
make scan-images
```

## Detailed Configuration

### Azure Container Registry Setup

1. **Create ACR** (if not exists):
```bash
az acr create --resource-group myResourceGroup --name myacr --sku Basic
```

2. **Get ACR Credentials**:
```bash
az acr credential show --name myacr
```

3. **Enable Admin User** (if needed):
```bash
az acr update -n myacr --admin-enabled true
```

### Security Scanning Setup

Install Trivy for vulnerability scanning:

**Ubuntu/Debian:**
```bash
sudo apt-get install wget apt-transport-https gnupg lsb-release
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
echo deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main | sudo tee -a /etc/apt/sources.list.d/trivy.list
sudo apt-get update
sudo apt-get install trivy
```

**macOS:**
```bash
brew install trivy
```

**Windows:**
```bash
scoop install trivy
```

## Build Process

### Base Images
The system builds hardened base images for (default = latest):
- **Alpine Linux 3.22 / 3.23 / 3.24** - Minimal, security-focused
- **Debian 12 (Bookworm) / 13 (Trixie)** - Stable, widely supported
- **RedHat UBI 9 / 10** - Enterprise-grade

### Platform Images
Based on the hardened base images, platform images include (default versions):
- **Nginx 1.28** - Web server
- **OpenJDK 21 (LTS)** - Java runtime
- **Tomcat 11.0** - Java application server
- **Python 3.13** - Python runtime
- **Spring Boot 3.5** - Java framework
- **ASP.NET Core 10.0 (LTS)** - .NET web framework
- **.NET Runtime 10.0 (LTS)** - .NET runtime

## Security Features

### CIS Docker Benchmark v1.7.0 compliance
- Non-root user execution (`appuser`, uid 10001) — final `USER` is never root
- Upstream base images pinned by digest; minimal attack surface
- setuid/setgid bits stripped; world-writable bits removed; caches purged
- HEALTHCHECK on every image; COPY-only (no ADD); no secrets in the image/context
- Hard-fail CIS gate before any push (see below)

### CIS verification gate (Trivy)
Every image must pass two Trivy-powered checks or the build fails:
- `scripts/lint-dockerfiles.sh` → `trivy config` (Dockerfile CIS build checks)
- `scripts/cis-verify.sh` → `trivy image --scanners vuln,secret,misconfig`

```bash
make lint-dockerfiles
make cis-verify IMAGE=ghcr.io/<ns>/alpine-hardened:3.20
```

> Dockle is intentionally not used (its container image carried vulnerabilities);
> Trivy provides equivalent CIS-DI coverage. See [docs/CIS-COMPLIANCE.md](docs/CIS-COMPLIANCE.md).

### Build & verify everything locally on Docker Desktop
```bash
./scripts/local-build-test.sh                              # bases + nginx/python + CIS gate
./scripts/local-build-test.sh --all-platforms --with-redhat
```

## Usage Examples

### Build Specific Images
```bash
# Build only base images
make build-base-images

# Build only platform images
make build-platform-images

# Build specific base image
make build-base-debian

# Build specific platform image
make build-platform-nginx
```

### Push Specific Images
```bash
# Push all images
make push-all

# Push only base images
make push-base-images

# Push only platform images
make push-platform-images
```

### Local Testing
```bash
# Test base images
docker-compose --profile test up

# Test platform images
docker-compose --profile platform up

# Run security scan
docker-compose --profile security up
```

### Complete Workflow
```bash
# Complete build and deployment
make deploy
```

## CI/CD Integration

### GitHub Actions
The system includes a GitHub Actions workflow that:
- Builds images on push/PR
- Runs security scans
- Performs integration tests
- Updates latest tags

### Required Secrets
Set these secrets in your GitHub repository:
- `ACR_LOGIN_SERVER` - Your ACR login server
- `ACR_USERNAME` - ACR username
- `ACR_PASSWORD` - ACR password

## Monitoring and Maintenance

### Regular Tasks
1. **Weekly Security Updates**: Run `make build-all` to rebuild with latest patches
2. **Vulnerability Scanning**: Run `make scan-images` to check for new vulnerabilities
3. **Image Cleanup**: Run `make clean` to remove old images

### Health Checks
```bash
# Check build status
./scripts/build-helper.sh build-status

# Validate configuration
./scripts/build-helper.sh validate-config
```

## Troubleshooting

### Common Issues

**Build Failures:**
- Check Docker daemon is running
- Verify ACR credentials
- Ensure sufficient disk space

**Push Failures:**
- Verify ACR login
- Check network connectivity
- Confirm ACR permissions

**Security Scan Failures:**
- Install Trivy
- Check image exists locally
- Verify scan permissions

### Logs and Debugging
```bash
# Enable verbose output
make build-all V=1

# Check Docker logs
docker logs <container-name>

# Inspect image layers
docker history <image-name>
```

## Advanced Configuration

### Multi-Platform Builds
Edit `configs/build-config.yaml` to enable multi-platform builds:
```yaml
build:
  platforms: ["linux/amd64", "linux/arm64"]
  parallel: 4
```

### Custom Hardening
Container hardening (runs during `docker build`, CIS Docker Benchmark) lives in
`scripts/container/`:
- `harden-alpine.sh` / `harden-debian.sh` / `harden-redhat.sh` — base-image hardening
- `harden-runtime.sh` — re-applied by platform images after installing packages

VM/host hardening (runs on a real VM via Packer, CIS Linux/Windows Benchmarks)
lives in `scripts/vm/` and is kept strictly separate:
- `harden-debian.sh` / `harden-redhat.sh` / `harden-alpine.sh` / `harden-windows.ps1`
- `openscap-remediate.sh` — OpenSCAP CIS remediation + scoring gate

### Custom Platform Images
Add new platform images by:
1. Create directory in `platform-images/`
2. Add Dockerfile
3. Update `Makefile` targets
4. Update `docker-compose.yml`

## Support

For issues and questions:
1. Check the troubleshooting section
2. Review logs and error messages
3. Consult the security scanning reports
4. Open an issue in the repository

## License

This project is licensed under the MIT License. 