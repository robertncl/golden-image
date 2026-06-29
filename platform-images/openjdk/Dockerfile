# syntax=docker/dockerfile:1
# OpenJDK platform image — built on the CIS-hardened Debian base, runs non-root.
# Build context is the repo root.
ARG BASE_IMAGE=ghcr.io/your-org/debian-hardened:12
FROM ${BASE_IMAGE}

ARG BUILD_DATE
ARG VCS_REF
ARG VERSION=1.0.0
ARG OPENJDK_VERSION=17
ARG TARGETARCH

LABEL maintainer="Golden Image Build System" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.vendor="Golden Image Build System" \
      org.opencontainers.image.title="OpenJDK Platform (CIS-hardened)" \
      org.opencontainers.image.description="OpenJDK ${OPENJDK_VERSION} JRE on a CIS-hardened Debian base, non-root" \
      org.opencontainers.image.source="https://github.com/your-org/golden-image" \
      org.opencontainers.image.licenses="MIT" \
      io.golden-image.cis.benchmark="CIS Docker Benchmark v1.7.0"

USER root
ENV DEBIAN_FRONTEND=noninteractive

COPY scripts/container/harden-runtime.sh /tmp/harden-runtime.sh
# Recreate /usr/share/man/man1 (purged by the base hardening): the OpenJDK
# post-install runs update-alternatives, which fails without it on slim bases.
RUN mkdir -p /usr/share/man/man1 && \
    apt-get update && \
    apt-get upgrade -y --no-install-recommends && \
    apt-get install -y --no-install-recommends "openjdk-${OPENJDK_VERSION}-jre-headless" && \
    chown -R appuser:appuser /app && \
    sh /tmp/harden-runtime.sh && rm -f /tmp/harden-runtime.sh && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# JAVA_HOME is arch-specific on Debian; TARGETARCH (amd64/arm64) matches the
# package suffix so this works for multi-arch builds.
ENV JAVA_HOME="/usr/lib/jvm/java-${OPENJDK_VERSION}-openjdk-${TARGETARCH}" \
    PATH="/usr/lib/jvm/java-${OPENJDK_VERSION}-openjdk-${TARGETARCH}/bin:${PATH}"

USER appuser
WORKDIR /app

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD java -version || exit 1

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["java", "-version"]
