# Nginx Platform Image
FROM ${GHCR_REGISTRY}/${GHCR_NAMESPACE}/debian-hardened:latest

# Set build arguments
ARG BUILD_DATE
ARG VCS_REF
ARG VERSION=1.24

# Set labels
LABEL maintainer="Golden Image Build System" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.vendor="Golden Image Build System" \
      org.opencontainers.image.title="Nginx Platform" \
      org.opencontainers.image.description="Nginx platform image based on hardened Debian" \
      org.opencontainers.image.source="https://github.com/your-org/golden-image" \
      org.opencontainers.image.licenses="MIT"

# Switch to root for installation
USER root

# Install Nginx
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        nginx \
        ca-certificates \
        curl \
    && rm -rf /var/lib/apt/lists/*

# Create nginx user
RUN groupadd -g 101 nginx && \
    useradd -r -u 101 -g nginx nginx

# Configure Nginx
RUN mkdir -p /var/log/nginx /var/cache/nginx /var/run && \
    chown -R nginx:nginx /var/log/nginx /var/cache/nginx /var/run

# Copy Nginx configuration
COPY configs/nginx.conf /etc/nginx/nginx.conf
COPY configs/default.conf /etc/nginx/conf.d/default.conf

# Create application directory
RUN mkdir -p /app && \
    chown nginx:nginx /app

# Switch to nginx user
USER nginx

# Set working directory
WORKDIR /app

# Expose ports
EXPOSE 80 443

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost/ || exit 1

# Default command
CMD ["nginx", "-g", "daemon off;"] 