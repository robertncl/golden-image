# Debian Hardened Base Image
FROM debian:12-slim

# Set build arguments
ARG BUILD_DATE
ARG VCS_REF
ARG VERSION

# Set labels
LABEL maintainer="Golden Image Build System" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.vendor="Golden Image Build System" \
      org.opencontainers.image.title="Debian Hardened Base" \
      org.opencontainers.image.description="Hardened Debian base image following CIS Container Security Best Practices" \
      org.opencontainers.image.source="https://github.com/your-org/golden-image" \
      org.opencontainers.image.licenses="MIT"

# Copy hardening script
COPY scripts/harden-debian.sh /tmp/harden.sh

# Run hardening script
RUN chmod +x /tmp/harden.sh && /tmp/harden.sh

# Set working directory
WORKDIR /app

# Switch to non-root user
USER appuser

# Use dumb-init as entrypoint
ENTRYPOINT ["/usr/bin/dumb-init", "--"]

# Default command
CMD ["/bin/bash"] 