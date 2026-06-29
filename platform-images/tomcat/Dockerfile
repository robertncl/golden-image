# syntax=docker/dockerfile:1
# Tomcat platform image — built on the CIS-hardened OpenJDK platform image,
# runs non-root. BASE_IMAGE must be an openjdk-platform image (has a JRE).
# The Tomcat tarball is verified against a pinned SHA-512 (CIS 4.11).
ARG BASE_IMAGE=ghcr.io/your-org/openjdk-platform:17-debian-12
FROM ${BASE_IMAGE}

ARG BUILD_DATE
ARG VCS_REF
ARG VERSION=1.0.0
ARG TOMCAT_VERSION=10.1.34

LABEL maintainer="Golden Image Build System" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.vendor="Golden Image Build System" \
      org.opencontainers.image.title="Tomcat Platform (CIS-hardened)" \
      org.opencontainers.image.description="Apache Tomcat ${TOMCAT_VERSION} on a CIS-hardened OpenJDK base, non-root" \
      org.opencontainers.image.source="https://github.com/your-org/golden-image" \
      org.opencontainers.image.licenses="MIT" \
      io.golden-image.cis.benchmark="CIS Docker Benchmark v1.7.0"

USER root
ENV DEBIAN_FRONTEND=noninteractive \
    CATALINA_HOME=/opt/tomcat \
    CATALINA_BASE=/opt/tomcat \
    CATALINA_TMPDIR=/opt/tomcat/temp \
    JAVA_OPTS="-Djava.awt.headless=true -Dfile.encoding=UTF-8"

# Download + verify Tomcat, install, then drop privileges back to appuser.
COPY scripts/container/harden-runtime.sh /tmp/harden-runtime.sh
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl && \
    TMAJOR="$(echo "${TOMCAT_VERSION}" | cut -d. -f1)" && \
    curl -fsSL -o /tmp/tomcat.tar.gz \
      "https://archive.apache.org/dist/tomcat/tomcat-${TMAJOR}/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz" && \
    curl -fsSL -o /tmp/tomcat.tar.gz.sha512 \
      "https://archive.apache.org/dist/tomcat/tomcat-${TMAJOR}/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz.sha512" && \
    ( cd /tmp && echo "$(cut -d' ' -f1 tomcat.tar.gz.sha512)  tomcat.tar.gz" | sha512sum -c - ) && \
    mkdir -p /opt/tomcat && \
    tar -C /opt/tomcat --strip-components=1 -xzf /tmp/tomcat.tar.gz && \
    rm -rf /opt/tomcat/webapps/examples /opt/tomcat/webapps/docs \
           /opt/tomcat/webapps/host-manager /opt/tomcat/webapps/manager && \
    chown -R appuser:appuser /opt/tomcat && \
    chmod -R go-w /opt/tomcat && \
    apt-get purge -y curl && apt-get autoremove -y && \
    sh /tmp/harden-runtime.sh && rm -f /tmp/harden-runtime.sh && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

USER appuser
WORKDIR /app
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD [ -d /opt/tomcat ] || exit 1

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/opt/tomcat/bin/catalina.sh", "run"]
