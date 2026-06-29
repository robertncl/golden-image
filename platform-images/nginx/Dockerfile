# syntax=docker/dockerfile:1
# Nginx platform image — built on the CIS-hardened Alpine base, runs fully
# non-root on an unprivileged port (8080). Build context is the repo root.
ARG BASE_IMAGE=ghcr.io/your-org/alpine-hardened:3.24
FROM ${BASE_IMAGE}

ARG BUILD_DATE
ARG VCS_REF
ARG VERSION=1.0.0
ARG NGINX_VERSION=1.28

LABEL maintainer="Golden Image Build System" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.vendor="Golden Image Build System" \
      org.opencontainers.image.title="Nginx Platform (CIS-hardened)" \
      org.opencontainers.image.description="Nginx on a CIS-hardened Alpine base, non-root on :8080" \
      org.opencontainers.image.source="https://github.com/your-org/golden-image" \
      org.opencontainers.image.licenses="MIT" \
      io.golden-image.cis.benchmark="CIS Docker Benchmark v1.7.0"

USER root

# Install nginx + curl (curl is needed by the HEALTHCHECK), patch, prepare
# writable runtime dirs owned by the non-root appuser, then re-harden.
COPY configs/nginx.conf /etc/nginx/nginx.conf
COPY configs/default.conf /etc/nginx/conf.d/default.conf
COPY scripts/container/harden-runtime.sh /tmp/harden-runtime.sh
RUN apk update && apk upgrade --no-cache && \
    apk add --no-cache nginx curl && \
    mkdir -p /etc/nginx/conf.d /var/lib/nginx /var/log/nginx && \
    rm -f /etc/nginx/http.d/default.conf && \
    chown -R appuser:appuser /etc/nginx /var/lib/nginx /var/log/nginx /app && \
    sh /tmp/harden-runtime.sh && rm -f /tmp/harden-runtime.sh

USER appuser
WORKDIR /app

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -fsS http://127.0.0.1:8080/health || exit 1

ENTRYPOINT ["/sbin/tini", "--"]
CMD ["nginx", "-g", "daemon off;"]
