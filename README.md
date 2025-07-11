# Golden Image Build System

A comprehensive container image build system that creates hardened base images following CIS Container Security Best Practices and builds platform-specific images for various applications.

## Overview

This system creates golden images by:
1. Downloading latest LTS versions of Alpine, Debian, and RedHat base images
2. Applying security hardening scripts based on CIS Container Security Best Practices
3. Updating all packages to latest versions
4. Uploading hardened base images to private Azure Container Registry (ACR)
5. Building platform-specific images (nginx, OpenJDK, Tomcat, Python, Spring Boot, ASP.NET, .NET Runtime)

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

- **Multi-OS Support**: Alpine, Debian, RedHat base images
- **Security Hardening**: CIS Container Security Best Practices
- **Automated Updates**: Latest package versions
- **Multi-Platform**: Support for various application runtimes
- **ACR Integration**: Automated upload to private registry
- **CI/CD Ready**: Docker-based build system

## Quick Start

1. Configure your ACR credentials in `configs/acr-config.env`
2. Run the build system:
   ```bash
   make build-all
   ```

## Security Features

- CIS Container Security Best Practices compliance
- Minimal attack surface
- Regular security updates
- Non-root user execution
- Secure package management
- Vulnerability scanning integration

## Supported Platforms

- **Web Servers**: Nginx
- **Java**: OpenJDK, Tomcat, Spring Boot
- **Python**: Python runtime
- **.NET**: ASP.NET Core, .NET Runtime

## License

MIT License