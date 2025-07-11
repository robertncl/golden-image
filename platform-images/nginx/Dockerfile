# Nginx Platform Image
ARG GHCR_NAMESPACE
FROM ghcr.io/${GHCR_NAMESPACE}/alpine-base:3.20

# Set build arguments
ARG BUILD_DATE
ARG VCS_REF
ARG VERSION
ARG NGINX_VERSION=1.25

# Set labels
LABEL maintainer="Golden Image Build System" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.vendor="Golden Image Build System" \
      org.opencontainers.image.title="Nginx Platform" \
      org.opencontainers.image.description="Nginx platform image based on Alpine" \
      org.opencontainers.image.source="https://github.com/your-org/golden-image" \
      org.opencontainers.image.licenses="MIT"

# Switch to root for installation
USER root

# Install Nginx
RUN apk update && \
    apk add --no-cache \
        nginx=${NGINX_VERSION}* \
        ca-certificates \
        curl

# Create nginx user
RUN addgroup -g 101 nginx && \
    adduser -D -u 101 -G nginx nginx

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