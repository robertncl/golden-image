# syntax=docker/dockerfile:1
# Tomcat platform image — built on the CIS-hardened Alpine OpenJDK platform image,
# runs non-root. BASE_IMAGE must be an openjdk-platform image (has a JRE).
# The Tomcat tarball is verified against a pinned SHA-512 (CIS 4.11).
ARG BASE_IMAGE=ghcr.io/your-org/openjdk-platform:25-alpine-3.24
FROM ${BASE_IMAGE}

ARG BUILD_DATE
ARG VCS_REF
ARG VERSION=1.0.0
ARG TOMCAT_VERSION=11.0.27
# SHA-512 of apache-tomcat-${TOMCAT_VERSION}.tar.gz, pinned here rather than
# fetched alongside the tarball (a checksum from the same server proves
# nothing). Bump together with TOMCAT_VERSION; overriding only the version
# fails the build by design.
ARG TOMCAT_SHA512=a617896307cada4884b24f80c4e977ddad8b3e0f88ce0e2a6eea29d5f332498e276ae5976c227a9c8daecf05c7c90def684a3766dd5a81f47a56d8b1adf43dc3

LABEL maintainer="Golden Image Build System" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.vendor="Golden Image Build System" \
      org.opencontainers.image.title="Tomcat Platform (CIS-hardened)" \
      org.opencontainers.image.description="Apache Tomcat ${TOMCAT_VERSION} on a CIS-hardened Alpine OpenJDK base, non-root" \
      org.opencontainers.image.source="https://github.com/your-org/golden-image" \
      org.opencontainers.image.licenses="MIT" \
      io.golden-image.cis.benchmark="CIS Docker Benchmark v1.7.0"

USER root
ENV CATALINA_HOME=/opt/tomcat \
    CATALINA_BASE=/opt/tomcat \
    CATALINA_TMPDIR=/opt/tomcat/temp \
    JAVA_OPTS="-Djava.awt.headless=true -Dfile.encoding=UTF-8"

# Download + verify Tomcat (GNU tar from apk for --strip-components). The
# install stays root-owned and read-only; appuser can write only the runtime
# dirs (logs, temp, work, webapps, conf/Catalina), so a compromised app cannot
# rewrite bin/, lib/ or the server config.
COPY scripts/container/harden-runtime.sh /tmp/harden-runtime.sh
RUN apk add --no-cache --virtual .build-deps curl tar && \
    TMAJOR="$(echo "${TOMCAT_VERSION}" | cut -d. -f1)" && \
    curl -fsSL -o /tmp/tomcat.tar.gz \
      "https://archive.apache.org/dist/tomcat/tomcat-${TMAJOR}/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz" && \
    echo "${TOMCAT_SHA512}  /tmp/tomcat.tar.gz" | sha512sum -c - && \
    mkdir -p /opt/tomcat && \
    tar -C /opt/tomcat --strip-components=1 --no-same-owner -xzf /tmp/tomcat.tar.gz && \
    rm -rf /opt/tomcat/webapps/examples /opt/tomcat/webapps/docs \
           /opt/tomcat/webapps/host-manager /opt/tomcat/webapps/manager /tmp/tomcat.tar.gz* && \
    mkdir -p /opt/tomcat/conf/Catalina/localhost && \
    chown -R root:appuser /opt/tomcat && \
    chmod -R g+rX,g-w,o-rwx /opt/tomcat && \
    chown -R appuser:appuser /opt/tomcat/logs /opt/tomcat/temp /opt/tomcat/work \
                             /opt/tomcat/webapps /opt/tomcat/conf/Catalina && \
    apk del .build-deps && \
    sh /tmp/harden-runtime.sh && rm -f /tmp/harden-runtime.sh

USER appuser
WORKDIR /app
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD [ -d /opt/tomcat ] || exit 1

ENTRYPOINT ["/sbin/tini", "--"]
CMD ["/opt/tomcat/bin/catalina.sh", "run"]
