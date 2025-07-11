# Platform LTS Version Support

This document describes the Long Term Support (LTS) versions of platform software supported by the Golden Image Build System.

## Supported Platform LTS Versions

### Nginx
- **1.24** - Released April 2023, supported until April 2026
- **1.25** - Released May 2024, supported until May 2027

### OpenJDK
- **11** - Released September 2018, supported until September 2026
- **17** - Released September 2021, supported until September 2029
- **21** - Released September 2023, supported until September 2031

### Tomcat
- **9.0** - Released January 2018, supported until January 2024
- **10.1** - Released January 2022, supported until January 2027

### Python
- **3.11** - Released October 2022, supported until October 2027
- **3.12** - Released October 2023, supported until October 2028

### Spring Boot
- **2.7** - Released May 2022, supported until August 2025
- **3.2** - Released November 2023, supported until February 2027

### ASP.NET Core
- **6.0** - Released November 2021, supported until November 2024
- **8.0** - Released November 2023, supported until November 2026

### .NET Runtime
- **6.0** - Released November 2021, supported until November 2024
- **8.0** - Released November 2023, supported until November 2026

## Building Specific Platform LTS Versions

### Using Makefile

Build all platform LTS versions on all OS LTS versions:
```bash
make build-all-platforms
```

Build specific platform version on specific OS:
```bash
# Nginx 1.25 on Alpine 3.20
make build-nginx-1.25-alpine-3.20

# Python 3.12 on Debian 12
make build-python-3.12-debian-12

# OpenJDK 17 on RedHat 9
make build-openjdk-17-redhat-9
```

Push all platform LTS versions:
```bash
make push-all-platforms
```

Push specific platform version:
```bash
# Nginx 1.25 on Alpine 3.20
make push-nginx-1.25-alpine-3.20

# Python 3.12 on Debian 12
make push-python-3.12-debian-12
```

### Using Docker Directly

Build specific platform version on specific OS:
```bash
# Nginx 1.25 on Alpine 3.20
docker build \
  --build-arg NGINX_VERSION=1.25 \
  --build-arg BASE_IMAGE=ghcr.io/your-org/alpine-hardened:3.20 \
  -t ghcr.io/your-org/nginx-1.25-alpine-3.20 \
  platform-images/nginx/

# Python 3.12 on Debian 12
docker build \
  --build-arg PYTHON_VERSION=3.12 \
  --build-arg BASE_IMAGE=ghcr.io/your-org/debian-hardened:12 \
  -t ghcr.io/your-org/python-3.12-debian-12 \
  platform-images/python/
```

## Image Naming Convention

Platform images are tagged with the format: `platform-version-os-osversion`

Examples:
- `ghcr.io/your-org/nginx-1.25-alpine-3.20`
- `ghcr.io/your-org/python-3.12-debian-12`
- `ghcr.io/your-org/openjdk-17-redhat-9`
- `ghcr.io/your-org/springboot-3.2-alpine-3.19`

## Configuration Management

### Adding New Platform LTS Versions

1. **Update Configuration**:
   Edit `configs/platform-lts-versions.env` and add the new version:
   ```bash
   # Example: Adding Nginx 1.26
   NGINX_VERSIONS=1.24 1.25 1.26
   ```

2. **Update Dockerfile** (if needed):
   Ensure the Dockerfile can handle the new version via build arguments.

3. **Validate Configuration**:
   ```bash
   make validate-platform-config
   ```

4. **Test Build**:
   ```bash
   make build-nginx-1.26-alpine-3.20
   ```

### Removing Platform LTS Versions

1. **Update Configuration**:
   Edit `configs/platform-lTS-versions.env` and remove the version:
   ```bash
   # Example: Removing Nginx 1.24
   NGINX_VERSIONS=1.25 1.26
   ```

2. **Validate Configuration**:
   ```bash
   make validate-platform-config
   ```

## Platform-Specific Considerations

### Nginx
- Uses package manager to install specific version
- Configuration files are copied from `configs/` directory
- Health check validates nginx is running

### OpenJDK
- Uses package manager to install specific JDK version
- Sets JAVA_HOME environment variable
- Health check validates java command works

### Python
- Uses package manager to install specific Python version
- Creates virtual environment in `/app/venv`
- Sets Python environment variables for best practices

### Spring Boot
- Based on OpenJDK platform images
- Includes Spring Boot specific configurations
- Health check validates Spring Boot application startup

### ASP.NET Core
- Based on .NET Runtime platform images
- Includes ASP.NET Core specific configurations
- Health check validates ASP.NET Core application startup

### .NET Runtime
- Uses Microsoft's official .NET Runtime packages
- Includes .NET specific configurations
- Health check validates dotnet command works

## Security Scanning

All platform LTS versions are automatically scanned for vulnerabilities:

```bash
# Scan all platform LTS versions
make scan-images

# Comprehensive scanning
make scan-comprehensive
```

## Registry Sync

All platform LTS versions are synced from GHCR to ACR:

```bash
# Sync all platform LTS versions
make sync-to-acr

# Check sync status
./scripts/registry-sync.sh status
```

## GitHub Actions Integration

The GitHub Actions workflow automatically builds all platform LTS versions on all OS LTS versions. The matrix is generated dynamically from the configuration files.

### Matrix Generation

The workflow generates a matrix that includes:
- All platform versions (nginx, openjdk, tomcat, python, springboot, aspnet, dotnet)
- All platform LTS versions for each platform
- All OS LTS versions for each OS
- All combinations of platform+version+os+osversion

## Version Selection Strategy

### For Production Use
- **Latest LTS**: Use the most recent LTS version for new deployments
- **Stability**: Use older LTS versions for critical systems requiring maximum stability
- **Security**: All versions receive security updates throughout their support period

### Migration Strategy
1. **Test**: Deploy new platform LTS version in non-production environment
2. **Validate**: Run security scans and compatibility tests
3. **Gradual Rollout**: Migrate applications incrementally
4. **Monitor**: Track performance and stability metrics

## Support Timeline

### Nginx
- 1.24: Supported until April 2026
- 1.25: Supported until May 2027

### OpenJDK
- 11: Supported until September 2026
- 17: Supported until September 2029
- 21: Supported until September 2031

### Tomcat
- 9.0: Supported until January 2024
- 10.1: Supported until January 2027

### Python
- 3.11: Supported until October 2027
- 3.12: Supported until October 2028

### Spring Boot
- 2.7: Supported until August 2025
- 3.2: Supported until February 2027

### ASP.NET Core
- 6.0: Supported until November 2024
- 8.0: Supported until November 2026

### .NET Runtime
- 6.0: Supported until November 2024
- 8.0: Supported until November 2026

## Best Practices

1. **Regular Updates**: Keep platform images updated with latest security patches
2. **Version Pinning**: Pin to specific platform LTS versions in production
3. **Testing**: Test new platform LTS versions before production deployment
4. **Documentation**: Document which platform LTS version each application uses
5. **Monitoring**: Monitor for end-of-life announcements

## Troubleshooting

### Common Issues

1. **Build Failures**: Ensure platform version is available in the OS package manager
2. **Security Scan Failures**: Update platform images to latest patches
3. **Registry Sync Issues**: Check credentials and network connectivity

### Support

For issues with specific platform LTS versions:
1. Check the official platform documentation
2. Review security advisories
3. Test with different platform LTS versions
4. Contact the development team

## Future Versions

The system is designed to easily add new platform LTS versions:

1. Update `configs/platform-lts-versions.env` with new version
2. Ensure Dockerfile can handle the new version
3. Test and validate
4. Deploy to production

This ensures continuous support for the latest platform LTS versions while maintaining backward compatibility. 