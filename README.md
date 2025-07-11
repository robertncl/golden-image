# Golden Image Build System

A comprehensive container image build system that creates hardened base images following CIS Container Security Best Practices and builds platform-specific images for various applications.

## Overview

This system creates golden images by:
1. Downloading and building all LTS versions of Alpine (3.18, 3.19, 3.20), Debian (11, 12), and RedHat UBI (8, 9) base images
2. Applying security hardening scripts based on CIS Container Security Best Practices
3. Updating all packages to latest versions
4. Uploading hardened base images to GitHub Container Registry (GHCR) with version-specific tags
5. Building platform-specific images (nginx, OpenJDK, Tomcat, Python, Spring Boot, ASP.NET, .NET Runtime)
6. Optional syncing to Azure Container Registry (ACR)

## Architecture

```
golden-image/
├── base-images/           # Base OS image builds
│   ├── alpine/
│   ├── debian/
│   └── redhat/
├── platform-images/       # Application platform images
│   ├── nginx/
│   ├── openjdk/
│   ├── tomcat/
│   ├── python/
│   ├── springboot/
│   ├── aspnet/
│   └── dotnet/
├── scripts/              # Build and hardening scripts
├── configs/              # Configuration files
├── docker-compose.yml    # Local development
└── Makefile             # Build orchestration
```

## Features

- **Multi-OS LTS Support**: Alpine (3.18, 3.19, 3.20), Debian (11, 12), RedHat UBI (8, 9) base images
- **Security Hardening**: CIS Container Security Best Practices
- **Automated Updates**: Latest package versions
- **Multi-Platform**: Support for various application runtimes
- **GHCR Integration**: Automated upload to GitHub Container Registry
- **ACR Sync**: Optional syncing to Azure Container Registry
- **CI/CD Ready**: Docker-based build system with GitHub Actions
- **Version Management**: Individual LTS version support and tagging

## Quick Start

1. Configure your GHCR credentials in `configs/ghcr-config.env`
2. (Optional) Configure ACR credentials in `configs/acr-config.env`
3. (Optional) Configure Prisma Cloud in `configs/prisma-config.env`
4. Run the build system:
   ```bash
   # Build all LTS versions
   make build-all
   
   # Build specific LTS version
   make build-alpine-3.20
   make build-debian-12
   make build-redhat-9
   ```
5. Run security scans:
   ```bash
   # Comprehensive scan (Trivy + Prisma Cloud)
   make scan-comprehensive
   
   # Trivy only
   make scan-trivy
   
   # Prisma Cloud only
   make scan-prisma
   ```

## Security Features

- CIS Container Security Best Practices compliance
- Minimal attack surface
- Regular security updates
- Non-root user execution
- Secure package management
- **Dual Vulnerability Scanning**: Trivy + Prisma Cloud integration
- **Compliance Checking**: CIS, HIPAA, PCI, SOX, NIST compliance
- **Secret Detection**: Find hardcoded secrets and credentials
- **Malware Detection**: Identify malicious software in images
- **Comprehensive Reporting**: HTML and JSON security reports

## Supported Platforms

- **Web Servers**: Nginx
- **Java**: OpenJDK, Tomcat, Spring Boot
- **Python**: Python runtime
- **.NET**: ASP.NET Core, .NET Runtime

## LTS Version Support

The system supports multiple LTS versions for each operating system:

### Alpine Linux
- **3.18** (May 2023 - May 2026)
- **3.19** (November 2023 - November 2026)
- **3.20** (May 2024 - May 2027)

### Debian
- **11 (Bullseye)** (August 2021 - June 2026)
- **12 (Bookworm)** (June 2023 - June 2028)

### RedHat UBI
- **8** (May 2019 - May 2029)
- **9** (May 2022 - May 2032)

For detailed information about OS LTS version support, see [LTS_VERSIONS.md](docs/LTS_VERSIONS.md).

For information about platform LTS version support, see [PLATFORM_LTS_VERSIONS.md](docs/PLATFORM_LTS_VERSIONS.md).

For information about configuring and managing LTS versions, see [LTS_CONFIGURATION.md](docs/LTS_CONFIGURATION.md).

## License

MIT License

## VM Image Build with Packer and Security Scanning

This project supports building Azure VM images for Alpine, Debian, and RedHat using Packer, with integrated security scanning. The process is triggered manually via GitHub Actions.

### Directory Structure

```
packer/
  alpine.pkr.hcl
  debian.pkr.hcl
  redhat.pkr.hcl
  scripts/
    harden-alpine.sh
    harden-debian.sh
    harden-redhat.sh
```

### How it Works
- **Manual Trigger:** Run the workflow from the GitHub Actions tab and select the OS (alpine, debian, redhat).
- **Packer Build:** The workflow uses Packer to build a VM image for the selected OS, running the appropriate hardening script.
- **Security Scanning:** After the image is built, a security scan (e.g., OpenSCAP or Lynis) is run on the image.
- **Azure Integration:** The image is published to your Azure subscription as a managed image.

### Example Workflow

```yaml
name: Build Azure VM Images with Packer

on:
  workflow_dispatch:
    inputs:
      os:
        description: 'OS to build (debian, redhat, alpine)'
        required: true
        default: 'debian'

jobs:
  build-vm-image:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Packer
        uses: hashicorp/setup-packer@v2

      - name: Build VM image with Packer
        env:
          PKR_VAR_client_id: ${{ secrets.AZURE_CLIENT_ID }}
          PKR_VAR_client_secret: ${{ secrets.AZURE_CLIENT_SECRET }}
          PKR_VAR_tenant_id: ${{ secrets.AZURE_TENANT_ID }}
          PKR_VAR_subscription_id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
        run: |
          cd packer
          case "${{ github.event.inputs.os }}" in
            debian)
              packer build debian.pkr.hcl
              ;;
            redhat)
              packer build redhat.pkr.hcl
              ;;
            alpine)
              packer build alpine.pkr.hcl
              ;;
            *)
              echo "Unknown OS: ${{ github.event.inputs.os }}"
              exit 1
              ;;
          esac

      - name: Security scan (OpenSCAP example)
        run: |
          # Example: Run OpenSCAP or Lynis on the built image
          echo "Run security scan here"
```

### Azure Credentials
Add the following secrets to your repo or org:
- `AZURE_CLIENT_ID`
- `AZURE_CLIENT_SECRET`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`

### Notes
- Alpine is not officially supported as an Azure VM image, but you can build a custom VHD with Packer.
- Security scanning can be customized (OpenSCAP, Lynis, etc.).
- Harden scripts are reused from `scripts/`.