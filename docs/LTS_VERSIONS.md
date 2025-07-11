# LTS Version Support

This document describes the Long Term Support (LTS) versions of operating systems supported by the Golden Image Build System.

## Supported LTS Versions

### Alpine Linux
- **3.18** - Released May 2023, supported until May 2026
- **3.19** - Released November 2023, supported until November 2026
- **3.20** - Released May 2024, supported until May 2027

### Debian
- **11 (Bullseye)** - Released August 2021, supported until June 2026
- **12 (Bookworm)** - Released June 2023, supported until June 2028

### RedHat UBI (Universal Base Image)
- **8** - Released May 2019, supported until May 2029
- **9** - Released May 2022, supported until May 2032

## Building Specific LTS Versions

### Using Makefile

Build all LTS versions:
```bash
make build-base-images
```

Build specific OS and version:
```bash
# Alpine
make build-alpine-3.18
make build-alpine-3.19
make build-alpine-3.20

# Debian
make build-debian-11
make build-debian-12

# RedHat
make build-redhat-8
make build-redhat-9
```

Push all LTS versions:
```bash
make push-base-images
```

Push specific OS and version:
```bash
# Alpine
make push-alpine-3.18
make push-alpine-3.19
make push-alpine-3.20

# Debian
make push-debian-11
make push-debian-12

# RedHat
make push-redhat-8
make push-redhat-9
```

### Using Docker Directly

Build specific version:
```bash
# Alpine 3.18
docker build -f base-images/alpine/Dockerfile.3.18 -t ghcr.io/<your-username>/alpine-base:3.18 base-images/alpine/

# Debian 11
docker build -f base-images/debian/Dockerfile.11 -t ghcr.io/<your-username>/debian-base:11 base-images/debian/

# RedHat 8
docker build -f base-images/redhat/Dockerfile.8 -t ghcr.io/your-org/redhat-hardened:8 base-images/redhat/
```

## Image Naming Convention

Images are tagged with their LTS version number:

- `ghcr.io/<your-username>/alpine-base:3.18`
- `ghcr.io/<your-username>/alpine-base:3.19`
- `ghcr.io/<your-username>/alpine-base:3.20`
- `ghcr.io/<your-username>/debian-base:11`
- `ghcr.io/<your-username>/debian-base:12`

## Security Scanning

All LTS versions are automatically scanned for vulnerabilities:

```bash
# Scan all LTS versions
make scan-images

# Comprehensive scanning
make scan-comprehensive
```

## Registry Sync

All LTS versions are synced from GHCR to ACR:

```bash
# Sync all LTS versions
make sync-to-acr

# Check sync status
./scripts/registry-sync.sh status
```

## Platform Images

Platform images are built on the latest LTS version of each OS by default:

- **Alpine-based**: Uses Alpine 3.20
- **Debian-based**: Uses Debian 12
- **RedHat-based**: Uses RedHat UBI 9

## Version Selection Strategy

### For Production Use
- **Latest LTS**: Use the most recent LTS version for new deployments
- **Stability**: Use older LTS versions for critical systems requiring maximum stability
- **Security**: All versions receive security updates throughout their support period

### Migration Strategy
1. **Test**: Deploy new LTS version in non-production environment
2. **Validate**: Run security scans and compatibility tests
3. **Gradual Rollout**: Migrate applications incrementally
4. **Monitor**: Track performance and stability metrics

## Support Timeline

### Alpine Linux
- 3.18: Supported until May 2026
- 3.19: Supported until November 2026
- 3.20: Supported until May 2027

### Debian
- 11 (Bullseye): Supported until June 2026
- 12 (Bookworm): Supported until June 2028

### RedHat UBI
- 8: Supported until May 2029
- 9: Supported until May 2032

## Best Practices

1. **Regular Updates**: Keep base images updated with latest security patches
2. **Version Pinning**: Pin to specific LTS versions in production
3. **Testing**: Test new LTS versions before production deployment
4. **Documentation**: Document which LTS version each application uses
5. **Monitoring**: Monitor for end-of-life announcements

## Troubleshooting

### Common Issues

1. **Build Failures**: Ensure Dockerfile version matches the base image version
2. **Security Scan Failures**: Update base images to latest patches
3. **Registry Sync Issues**: Check credentials and network connectivity

### Support

For issues with specific LTS versions:
1. Check the official OS documentation
2. Review security advisories
3. Test with different LTS versions
4. Contact the development team

## Future Versions

The system is designed to easily add new LTS versions:

1. Create new Dockerfile with version suffix
2. Update Makefile with new version
3. Update GitHub Actions workflow
4. Test and validate
5. Deploy to production

This ensures continuous support for the latest LTS versions while maintaining backward compatibility. 