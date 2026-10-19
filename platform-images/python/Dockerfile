# syntax=docker/dockerfile:1
# Python platform image — built on the CIS-hardened Alpine base, runs non-root.
# Alpine ships a single python3 per release; PYTHON_VERSION is recorded as a
# label for traceability. Build context is the repo root.
#
# This is a RUNTIME image: it ships no pip. pip vendors its own urllib3,
# msgpack and setuptools, which carry fixable HIGH CVEs the gate would block
# (even the newest pip release bundles them), and a package installer has no
# job in production anyway. Install dependencies in a build stage instead:
#
#   FROM ghcr.io/robertncl/python-platform:3.14 AS deps
#   COPY requirements.txt .
#   RUN python -m ensurepip && python -m pip install -r requirements.txt \
#       && python -m pip uninstall -y pip
#   FROM ghcr.io/robertncl/python-platform:3.14
#   COPY --from=deps /opt/venv /opt/venv
ARG BASE_IMAGE=ghcr.io/robertncl/alpine-hardened:3.24
FROM ${BASE_IMAGE}

ARG PYTHON_VERSION=3.14

LABEL maintainer="Golden Image Build System" \
      org.opencontainers.image.vendor="Golden Image Build System" \
      org.opencontainers.image.title="Python Platform (CIS-hardened)" \
      org.opencontainers.image.description="Python ${PYTHON_VERSION} runtime on a CIS-hardened Alpine base, non-root" \
      org.opencontainers.image.licenses="MIT" \
      io.golden-image.cis.benchmark="CIS Docker Benchmark v1.7.0"

USER root

# The venv is owned by appuser so derived build stages can `ensurepip` into it.
ARG PATCH_EPOCH
RUN --mount=type=bind,source=scripts/container,target=/opt/golden-scripts \
    echo "patch epoch: ${PATCH_EPOCH:-unset}" && \
    apk upgrade --no-cache && \
    apk add --no-cache python3 && \
    python3 -m venv --without-pip /opt/venv && \
    chown -R appuser:appuser /opt/venv /app && \
    sh /opt/golden-scripts/harden-runtime.sh

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
