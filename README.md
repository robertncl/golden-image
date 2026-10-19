# Golden Image Build System

A comprehensive build platform that creates **CIS-hardened** container base images
and platform images, and **CIS-hardened Azure/Linux VM images** — each verified
against the relevant CIS benchmark by a hard-fail gate before it is published.

See **[docs/CIS-COMPLIANCE.md](docs/CIS-COMPLIANCE.md)** for the full control-by-control mapping.

## Overview

This system creates golden images by:
1. Building all current LTS versions of Alpine (3.22, 3.23, 3.24), Debian (12, 13), and RedHat UBI (9, 10) base images from upstream bases **pinned by digest**
2. Hardening each image to the **CIS Docker Benchmark v1.7.0** at build time (non-root `appuser` uid 10001, setuid/setgid stripped, caches purged, locked system accounts) via `scripts/container/harden-*.sh`
3. Updating all packages to latest patched versions
4. **CIS-verifying** every image with a hard-fail gate (`trivy config` for Dockerfile build checks + `trivy image` for vulns/secrets/misconfig) *before* it is pushed
5. Building platform images (nginx, OpenJDK, Tomcat, Python, Spring Boot, ASP.NET, .NET) on the hardened Alpine base in the same build graph, smoke-testing every image, and publishing multi-arch (amd64 + arm64) images with provenance and SBOM to GitHub Container Registry (GHCR)
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
│   ├── smoke-test.sh     # Functional checks (non-root, healthchecks, runtimes)
│   ├── deploy/           # One-time GitHub + Azure (OIDC) setup
│   └── local-build-test.sh  # Build + smoke-test + CIS-verify everything on Docker Desktop
├── docker-bake.hcl      # THE build graph (local + CI): every image, one parallel build
├── packer/              # CIS-hardened Azure/Linux VM image builds
├── configs/             # Configuration files
├── docs/CIS-COMPLIANCE.md   # Control-by-control CIS mapping
└── Makefile             # Build orchestration
```

## Features

- **Multi-OS LTS Support**: Alpine (3.22, 3.23, 3.24), Debian (12, 13), RedHat UBI (9, 10) base images
- **Security Hardening**: CIS Container Security Best Practices
- **Automated Updates**: Latest package versions
- **Multi-Platform**: Support for various application runtimes
- **GHCR Integration**: Automated upload to GitHub Container Registry
- **ACR Sync**: Optional syncing to Azure Container Registry
- **CI/CD Ready**: Docker-based build system with GitHub Actions
- **Version Management**: Individual LTS version support and tagging

## Quick Start

1. Build, smoke-test and CIS-gate everything locally on Docker Desktop (no registry needed):
   ```bash
   ./scripts/local-build-test.sh            # all 14 images (every LTS base + 7 platforms)
   ./scripts/local-build-test.sh --quick    # default bases + nginx/python
   make build-alpine-3.24                   # one image (no tests)
   ```
2. Publish through CI: GHCR needs no setup (the workflow's `GITHUB_TOKEN` pushes).
   ```bash
   scripts/deploy/github-setup.sh check && scripts/deploy/github-setup.sh run
   ```
3. (Optional) Add Azure Container Registry, with OIDC and no stored secrets:
   ```bash
   scripts/deploy/azure-bootstrap.sh --acr-name <name> --configure-github
   ```
4. Run the gates / scans individually:
   ```bash
   make lint-dockerfiles                                     # CIS Docker build checks (trivy config)
   make cis-verify IMAGE=ghcr.io/<ns>/alpine-hardened:3.24   # built-image scan (trivy image)
   make smoke-test IMAGE=golden-local/nginx-platform:1.30-alpine3.24
   make report                                               # size + vulnerability table
   ```

See **[docs/BUILD-AND-DEPLOY.md](docs/BUILD-AND-DEPLOY.md)** for the build graph,
the CI pipeline, tags, and the GitHub/Azure deployment details.

## Security Features

- **CIS Docker Benchmark v1.7.0** compliance for container images, verified by a hard-fail gate
- **Hard-fail CIS gate** — non-compliant images are never pushed (Dockerfile lint + image scan with **Trivy**; no vulnerable Dockle image)
- **Functional smoke tests** before push: every HEALTHCHECK must turn healthy with all capabilities dropped
- **Daily patch rebuilds**; no build-only tooling (curl, bash installers, pip) left in runtime images
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
- **3.22** (May 2025 - May 2027)
- **3.23** (November 2025 - November 2027)
- **3.24** (May 2026 - May 2028)

### Debian
- **12 (Bookworm)** (June 2023 - June 2028)
- **13 (Trixie)** (August 2025 - ~2030)

### RedHat UBI
- **9** (May 2022 - May 2032)
- **10** (2025 - ~2035)

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