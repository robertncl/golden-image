# syntax=docker/dockerfile:1
# Nginx platform image — built on the CIS-hardened Alpine base, runs fully
# non-root on an unprivileged port (8080). Build context is the repo root.
ARG BASE_IMAGE=ghcr.io/robertncl/alpine-hardened:3.24
FROM ${BASE_IMAGE}

ARG NGINX_VERSION=1.30

LABEL maintainer="Golden Image Build System" \
      org.opencontainers.image.vendor="Golden Image Build System" \
      org.opencontainers.image.title="Nginx Platform (CIS-hardened)" \
      org.opencontainers.image.description="Nginx ${NGINX_VERSION} on a CIS-hardened Alpine base, non-root on :8080" \
      org.opencontainers.image.licenses="MIT" \
      io.golden-image.cis.benchmark="CIS Docker Benchmark v1.7.0"

USER root

# Install nginx, prepare writable runtime dirs owned by the non-root appuser,
# then re-harden. No curl: the HEALTHCHECK uses busybox wget, which the base
# already ships, so curl/libcurl/nghttp2 (a steady CVE source) stay out.
# /etc/nginx stays root-owned: the worker never needs to write its own config,
# and a compromised worker must not be able to rewrite it.
ARG PATCH_EPOCH
RUN --mount=type=bind,source=scripts/container,target=/opt/golden-scripts \
    echo "patch epoch: ${PATCH_EPOCH:-unset}" && \
    apk upgrade --no-cache && \
    apk add --no-cache nginx && \
    mkdir -p /etc/nginx/conf.d /var/lib/nginx /var/log/nginx && \
    rm -f /etc/nginx/http.d/default.conf && \
    chown -R appuser:appuser /var/lib/nginx /var/log/nginx /app && \
    sh /opt/golden-scripts/harden-runtime.sh

# Config last so editing it never re-runs the package layer.
COPY --chown=root:root --chmod=0644 configs/nginx.conf /etc/nginx/nginx.conf
COPY --chown=root:root --chmod=0644 configs/default.conf /etc/nginx/conf.d/default.conf

USER appuser
WORKDIR /app

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget -q -O /dev/null http://127.0.0.1:8080/health || exit 1

ENTRYPOINT ["/sbin/tini", "--"]
CMD ["nginx", "-g", "daemon off;"]
