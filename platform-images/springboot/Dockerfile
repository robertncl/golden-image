# syntax=docker/dockerfile:1
# Spring Boot platform image — built on the CIS-hardened OpenJDK platform image,
# runs non-root. BASE_IMAGE must be an openjdk-platform image (has a JRE).
ARG BASE_IMAGE=ghcr.io/your-org/openjdk-platform:21-debian-13
FROM ${BASE_IMAGE}

ARG BUILD_DATE
ARG VCS_REF
ARG VERSION=1.0.0
ARG SPRINGBOOT_VERSION=3.5

LABEL maintainer="Golden Image Build System" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.vendor="Golden Image Build System" \
      org.opencontainers.image.title="Spring Boot Platform (CIS-hardened)" \
      org.opencontainers.image.description="Spring Boot ${SPRINGBOOT_VERSION} runtime base on a CIS-hardened OpenJDK base, non-root" \
      org.opencontainers.image.source="https://github.com/your-org/golden-image" \
      org.opencontainers.image.licenses="MIT" \
      io.golden-image.cis.benchmark="CIS Docker Benchmark v1.7.0"

USER root
ENV DEBIAN_FRONTEND=noninteractive

COPY scripts/container/harden-runtime.sh /tmp/harden-runtime.sh
RUN apt-get update && \
    apt-get upgrade -y --no-install-recommends && \
    chown -R appuser:appuser /app && \
    sh /tmp/harden-runtime.sh && rm -f /tmp/harden-runtime.sh && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

ENV SPRING_PROFILES_ACTIVE=docker \
    SERVER_PORT=8080 \
    JAVA_OPTS="-Xmx512m -Xms256m -Djava.security.egd=file:/dev/./urandom"

USER appuser
WORKDIR /app
EXPOSE 8080

# Drop an application jar at /app/app.jar in your derived image; this base just
# provides a hardened, non-root JRE runtime.
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD java -version || exit 1

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["java", "-version"]
