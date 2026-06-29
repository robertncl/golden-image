# syntax=docker/dockerfile:1
# Python platform image — built on the CIS-hardened Alpine base, runs non-root.
# Alpine ships a single python3 per release; PYTHON_VERSION is recorded as a
# label for traceability. Build context is the repo root.
ARG BASE_IMAGE=ghcr.io/your-org/alpine-hardened:3.24
FROM ${BASE_IMAGE}

ARG BUILD_DATE
ARG VCS_REF
ARG VERSION=1.0.0
ARG PYTHON_VERSION=3.13

LABEL maintainer="Golden Image Build System" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.vendor="Golden Image Build System" \
      org.opencontainers.image.title="Python Platform (CIS-hardened)" \
      org.opencontainers.image.description="Python ${PYTHON_VERSION} on a CIS-hardened Alpine base, non-root" \
      org.opencontainers.image.source="https://github.com/your-org/golden-image" \
      org.opencontainers.image.licenses="MIT" \
      io.golden-image.cis.benchmark="CIS Docker Benchmark v1.7.0"

USER root

COPY scripts/container/harden-runtime.sh /tmp/harden-runtime.sh
RUN apk update && apk upgrade --no-cache && \
    apk add --no-cache python3 py3-pip && \
    python3 -m venv /opt/venv && \
    chown -R appuser:appuser /opt/venv /app && \
    sh /tmp/harden-runtime.sh && rm -f /tmp/harden-runtime.sh

ENV PATH="/opt/venv/bin:${PATH}" \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

USER appuser
WORKDIR /app

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python3 --version || exit 1

ENTRYPOINT ["/sbin/tini", "--"]
CMD ["python3"]
