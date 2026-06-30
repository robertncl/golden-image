# syntax=docker/dockerfile:1
# OpenJDK platform image — built on the CIS-hardened Alpine base, runs non-root.
# Build context is the repo root.
ARG BASE_IMAGE=ghcr.io/your-org/alpine-hardened:3.24
FROM ${BASE_IMAGE}

ARG BUILD_DATE
ARG VCS_REF
ARG VERSION=1.0.0
ARG OPENJDK_VERSION=21

LABEL maintainer="Golden Image Build System" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.vendor="Golden Image Build System" \
      org.opencontainers.image.title="OpenJDK Platform (CIS-hardened)" \
      org.opencontainers.image.description="OpenJDK ${OPENJDK_VERSION} JRE on a CIS-hardened Alpine base, non-root" \
      org.opencontainers.image.source="https://github.com/your-org/golden-image" \
      org.opencontainers.image.licenses="MIT" \
      io.golden-image.cis.benchmark="CIS Docker Benchmark v1.7.0"

USER root

COPY scripts/container/harden-runtime.sh /tmp/harden-runtime.sh
RUN apk update && apk upgrade --no-cache && \
    apk add --no-cache "openjdk${OPENJDK_VERSION}-jre-headless" && \
    chown -R appuser:appuser /app && \
    sh /tmp/harden-runtime.sh && rm -f /tmp/harden-runtime.sh

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
