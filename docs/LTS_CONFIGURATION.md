# LTS Version Configuration System

This document explains how to configure and manage LTS versions in the Golden Image Build System.

## Overview

The LTS version configuration system allows you to easily add, remove, or modify supported LTS versions without changing multiple files. All LTS versions are centrally managed in `configs/lts-versions.env`.

## Configuration File

### `configs/lts-versions.env`

This is the central configuration file for all LTS versions:

```bash
# Alpine Linux LTS versions
ALPINE_VERSIONS=3.18 3.19 3.20

# Debian LTS versions
DEBIAN_VERSIONS=11 12

# RedHat UBI LTS versions
REDHAT_VERSIONS=8 9

# Default versions (used for platform images and legacy targets)
DEFAULT_ALPINE_VERSION=3.20
DEFAULT_DEBIAN_VERSION=12
DEFAULT_REDHAT_VERSION=9
```

## Adding New LTS Versions

### Step 1: Update Configuration

Edit `configs/lts-versions.env` and add the new version:

```bash
# Example: Adding Alpine 3.21
ALPINE_VERSIONS=3.18 3.19 3.20 3.21
```

### Step 2: Create Dockerfile

Create a new Dockerfile for the version:

```bash
# For Alpine 3.21
cp base-images/alpine/Dockerfile base-images/alpine/Dockerfile.3.21
```

### Step 3: Validate Configuration

Run the validation command:

```bash
make validate-lts-config
```

### Step 4: Test Build

Test building the new version:

```bash
make build-alpine-3.21
```

## Removing LTS Versions

### Step 1: Update Configuration

Edit `configs/lts-versions.env` and remove the version:

```bash
# Example: Removing Alpine 3.18
ALPINE_VERSIONS=3.19 3.20 3.21
```

### Step 2: Remove Dockerfile (Optional)

You can optionally remove the Dockerfile:

```bash
rm base-images/alpine/Dockerfile.3.18
```

### Step 3: Validate Configuration

```bash
make validate-lts-config
```

## Available Commands

### Configuration Management

```bash
# Show current LTS version configuration
make show-lts-versions

# Validate LTS version configuration
make validate-lts-config

# Generate build targets from configuration
./scripts/generate-build-targets.sh build-targets

# Generate push targets from configuration
./scripts/generate-build-targets.sh push-targets
```

### GitHub Actions Integration

```bash
# Generate JSON matrix for GitHub Actions
./scripts/generate-github-matrix.sh json

# Generate YAML matrix for GitHub Actions
./scripts/generate-github-matrix.sh yaml

# Generate scanning list for all versions
./scripts/generate-github-matrix.sh scanning
```

## Dynamic Target Generation

The system automatically generates build and push targets based on the configuration:

### Build Targets
- `build-alpine-<version>` - Build specific Alpine version
- `build-debian-<version>` - Build specific Debian version
- `build-redhat-<version>` - Build specific RedHat version

### Push Targets
- `push-alpine-<version>` - Push specific Alpine version
- `push-debian-<version>` - Push specific Debian version
- `push-redhat-<version>` - Push specific RedHat version

### Bulk Operations
- `build-base-images` - Build all LTS versions
- `push-base-images` - Push all LTS versions
- `scan-images` - Scan all LTS versions

## Default Versions

Default versions are used for:
- Platform images (nginx, python, etc.)
- Legacy targets (`build-base-alpine`, etc.)
- Documentation examples

To change default versions, update the `DEFAULT_*_VERSION` variables in `configs/lts-versions.env`.

## Registry Sync

The registry sync script automatically syncs all configured LTS versions:

```bash
# Sync all LTS versions from GHCR to ACR
make sync-to-acr

# Check sync status for all versions
./scripts/registry-sync.sh status
```

## GitHub Actions Integration

The GitHub Actions workflow automatically builds all configured LTS versions. The matrix is generated from the configuration file.

### Manual Matrix Generation

If you need to update the GitHub Actions matrix manually:

```bash
# Generate the matrix section
./scripts/generate-github-matrix.sh yaml
```

Copy the output to `.github/workflows/build.yml` in the matrix section.

## Validation

The system includes comprehensive validation:

### Configuration Validation
- Checks that all configured versions have corresponding Dockerfiles
- Validates that Dockerfiles exist and are accessible
- Ensures default versions are included in the version lists

### Build Validation
- Validates that images can be built successfully
- Checks that tags are properly applied
- Ensures registry access is working

### Runtime Validation
- Tests that built images can run successfully
- Validates security scanning works for all versions
- Ensures registry sync works for all versions

## Best Practices

### Version Management
1. **Add versions early**: Add new LTS versions as soon as they're announced
2. **Remove versions gradually**: Keep old versions for a transition period
3. **Test thoroughly**: Always test new versions before production use
4. **Document changes**: Update documentation when adding/removing versions

### Configuration
1. **Use consistent naming**: Follow the established naming convention
2. **Validate changes**: Always run validation after configuration changes
3. **Test builds**: Test individual version builds before bulk operations
4. **Monitor builds**: Watch for build failures and address them quickly

### Security
1. **Regular updates**: Keep all versions updated with security patches
2. **Scan all versions**: Ensure all LTS versions are scanned for vulnerabilities
3. **Monitor EOL**: Track end-of-life dates for all versions
4. **Plan migrations**: Plan migrations before versions reach EOL

## Troubleshooting

### Common Issues

1. **Missing Dockerfile**
   ```bash
   # Error: Missing Alpine 3.21 Dockerfile
   # Solution: Create the Dockerfile
   cp base-images/alpine/Dockerfile base-images/alpine/Dockerfile.3.21
   ```

2. **Configuration not loaded**
   ```bash
   # Error: ALPINE_VERSIONS not defined
   # Solution: Check configs/lts-versions.env is included
   make show-lts-versions
   ```

3. **Build failures**
   ```bash
   # Error: Build fails for specific version
   # Solution: Check Dockerfile and base image availability
   make validate-lts-config
   ```

4. **Registry sync issues**
   ```bash
   # Error: Sync fails for new version
   # Solution: Ensure version is built and pushed to GHCR first
   make build-alpine-3.21
   make push-alpine-3.21
   ```

### Debugging Commands

```bash
# Show current configuration
make show-lts-versions

# Validate configuration
make validate-lts-config

# Test specific version build
make build-alpine-3.21

# Check registry sync status
./scripts/registry-sync.sh status

# Generate debugging information
./scripts/generate-build-targets.sh all
```

## Migration Guide

### Adding a New LTS Version

1. **Research**: Check official LTS release dates and support timelines
2. **Prepare**: Create Dockerfile and update configuration
3. **Test**: Build and test the new version locally
4. **Deploy**: Push to registry and update CI/CD
5. **Monitor**: Watch for issues and validate functionality

### Removing an EOL Version

1. **Plan**: Identify applications using the EOL version
2. **Migrate**: Update applications to use supported versions
3. **Test**: Validate applications work with new versions
4. **Remove**: Update configuration and remove Dockerfile
5. **Cleanup**: Remove images from registries

### Updating Default Versions

1. **Evaluate**: Assess which version should be the new default
2. **Test**: Ensure platform images work with new default
3. **Update**: Change DEFAULT_*_VERSION variables
4. **Deploy**: Update CI/CD and documentation
5. **Monitor**: Watch for any issues with the change

## Future Enhancements

### Planned Features
- **Automatic EOL detection**: Automatically flag versions approaching EOL
- **Migration automation**: Automated migration tools for version changes
- **Performance monitoring**: Track build times and resource usage per version
- **Security scoring**: Automated security scoring for each LTS version

### Integration Opportunities
- **Vulnerability databases**: Integration with CVE databases for version-specific alerts
- **Compliance tools**: Integration with compliance scanning tools
- **Cost optimization**: Tools to optimize storage and build costs
- **Analytics**: Detailed analytics on version usage and performance

This configuration system provides a flexible and maintainable way to manage LTS versions across the entire Golden Image Build System. 