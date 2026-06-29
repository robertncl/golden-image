# Golden Image Build System

A comprehensive build platform that creates **CIS-hardened** container base images
and platform images, and **CIS-hardened Azure/Linux VM images** — each verified
against the relevant CIS benchmark by a hard-fail gate before it is published.

See **[docs/CIS-COMPLIANCE.md](docs/CIS-COMPLIANCE.md)** for the full control-by-control mapping.

## Overview

This system creates golden images by:
1. Building all LTS versions of Alpine (3.18, 3.19, 3.20), Debian (11, 12), and RedHat UBI (8, 9) base images from upstream bases **pinned by digest**
2. Hardening each image to the **CIS Docker Benchmark v1.7.0** at build time (non-root `appuser` uid 10001, setuid/setgid stripped, caches purged, locked system accounts) via `scripts/container/harden-*.sh`
3. Updating all packages to latest patched versions
4. **CIS-verifying** every image with a hard-fail gate (`trivy config` for Dockerfile build checks + `trivy image` for vulns/secrets/misconfig) *before* it is pushed
5. Uploading hardened images to GitHub Container Registry (GHCR), then building platform images (nginx, OpenJDK, Tomcat, Python, Spring Boot, ASP.NET, .NET) on the hardened bases
6. Optionally syncing to Azure Container Registry (ACR), and building CIS-hardened VM images with Packer + OpenSCAP

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
├── scripts/
│   ├── container/        # Build-time container hardening (CIS Docker Benchmark)
│   ├── vm/               # Host hardening + OpenSCAP for Packer VM images
│   ├── cis-verify.sh     # CIS gate: trivy image (vuln/secret/misconfig)
│   ├── lint-dockerfiles.sh  # CIS gate: trivy config (Dockerfile build checks)
│   └── local-build-test.sh  # Build + CIS-verify everything on Docker Desktop
├── packer/              # CIS-hardened Azure/Linux VM image builds
├── configs/             # Configuration files
├── docs/CIS-COMPLIANCE.md   # Control-by-control CIS mapping
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
5. Build everything locally on Docker Desktop and run the CIS gate (no registry needed):
   ```bash
   # Base images + nginx/python, then CIS-verify them
   ./scripts/local-build-test.sh
   # Everything, including JVM/.NET platforms and the UBI 9 base
   ./scripts/local-build-test.sh --all-platforms --with-redhat
   ```
6. Run the CIS gates / scans individually:
   ```bash
   make lint-dockerfiles                                     # CIS Docker build checks (trivy config)
   make cis-verify IMAGE=ghcr.io/<ns>/alpine-hardened:3.20   # built-image scan (trivy image)
   make scan-comprehensive                                   # Trivy (+ optional Prisma) vuln scan
   ```

## Security Features

- **CIS Docker Benchmark v1.7.0** compliance for container images, verified by a hard-fail gate
- **Hard-fail CIS gate** — non-compliant images are never pushed (Dockerfile lint + image scan with **Trivy**; no vulnerable Dockle image)
- Non-root execution everywhere (`appuser`, uid 10001); setuid/setgid binaries stripped
- Upstream base images **pinned by digest**; minimal attack surface; latest patches
- **Secret detection** in built images (`trivy image --scanners secret`)
- **CIS-hardened VM images** via Packer + **OpenSCAP** SSG remediation with a minimum-score gate
- Optional dual vulnerability scanning (Trivy + Prisma Cloud) and HTML/JSON reporting

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
  alpine.pkr.hcl   # qemu builder (Azure has no Alpine marketplace image)
  debian.pkr.hcl   # azure-arm
  redhat.pkr.hcl   # azure-arm
  windows.pkr.hcl  # azure-arm
scripts/vm/
  harden-debian.sh        # supplementary host CIS hardening
  harden-redhat.sh
  harden-alpine.sh
  harden-windows.ps1
  openscap-remediate.sh   # OpenSCAP CIS remediation + scoring gate
```

### How it Works
- **Manual Trigger:** Run the `Build CIS-Hardened Azure VM Images (Packer)` workflow and select the OS (debian, redhat, windows).
- **Hardening:** Packer copies `scripts/vm/` onto the build VM and runs the supplementary host hardening script.
- **CIS gate (Linux):** `openscap-remediate.sh` applies the CIS SSG profile with `oscap --remediate`, re-scans, and **fails the build** if the score is below `min_cis_score` (default 70). The HTML report is uploaded as an artifact.
- **Windows:** the build VM's admin password comes from the `WINDOWS_ADMIN_PASSWORD` secret (no longer hardcoded).
- **Azure Integration:** images that pass the gate are published to your Azure subscription / Shared Image Gallery.

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
- Alpine is not in the Azure Marketplace, so `alpine.pkr.hcl` uses the `qemu` builder; it has no OpenSCAP gate because there is no official CIS SSG content for Alpine.
- VM hardening scripts live in `scripts/vm/` (kept strictly separate from the container hardening in `scripts/container/`).
- The authoritative workflow is `.github/workflows/packer-vm-image.yml`; the YAML above is illustrative only.