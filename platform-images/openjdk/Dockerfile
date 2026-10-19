# syntax=docker/dockerfile:1
# OpenJDK platform image — built on the CIS-hardened Alpine base, runs non-root.
# Build context is the repo root.
ARG BASE_IMAGE=ghcr.io/robertncl/alpine-hardened:3.24
FROM ${BASE_IMAGE}

ARG OPENJDK_VERSION=25

LABEL maintainer="Golden Image Build System" \
      org.opencontainers.image.vendor="Golden Image Build System" \
      org.opencontainers.image.title="OpenJDK Platform (CIS-hardened)" \
      org.opencontainers.image.description="OpenJDK ${OPENJDK_VERSION} JRE on a CIS-hardened Alpine base, non-root" \
      org.opencontainers.image.licenses="MIT" \
      io.golden-image.cis.benchmark="CIS Docker Benchmark v1.7.0"

USER root

# The JRE ships four CDS archives (~64 MB). Only classes.jsa serves the default
# JVM flags; the classes_nocoops* (heaps > 32 GB) and classes_*coh* (opt-in
# -XX:+UseCompactObjectHeaders) variants are dropped. A JVM started with those
# flags still runs, it just starts without a pre-built class-data archive.
ARG PATCH_EPOCH
RUN --mount=type=bind,source=scripts/container,target=/opt/golden-scripts \
    echo "patch epoch: ${PATCH_EPOCH:-unset}" && \
    apk upgrade --no-cache && \
    apk add --no-cache "openjdk${OPENJDK_VERSION}-jre-headless" && \
    find /usr/lib/jvm/ -path '*/lib/server/classes_*.jsa' -delete && \
    chown -R appuser:appuser /app && \
    sh /opt/golden-scripts/harden-runtime.sh

# Alpine maintains the /usr/lib/jvm/default-jvm symlink, so JAVA_HOME is
# version-agnostic and required by Tomcat/Spring Boot derived images.
ENV JAVA_HOME=/usr/lib/jvm/default-jvm \
    PATH=/usr/lib/jvm/default-jvm/bin:${PATH}

USER appuser
WORKDIR /app

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD java -version || exit 1

ENTRYPOINT ["/sbin/tini", "--"]
CMD ["java", "-version"]
