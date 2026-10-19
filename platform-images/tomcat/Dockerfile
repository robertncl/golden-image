# syntax=docker/dockerfile:1
# Tomcat platform image — built on the CIS-hardened Alpine OpenJDK platform image,
# runs non-root. BASE_IMAGE must be an openjdk-platform image (has a JRE).
# The Tomcat tarball is verified against a pinned SHA-512 (CIS 4.11).
ARG BASE_IMAGE=ghcr.io/robertncl/openjdk-platform:25-alpine3.24

# ---- fetch: download + verify + lay out Tomcat (never shipped) ---------------
FROM ${BASE_IMAGE} AS fetch
USER root
ARG TOMCAT_VERSION=11.0.27
# SHA-512 of apache-tomcat-${TOMCAT_VERSION}.tar.gz, pinned here rather than
# fetched alongside the tarball (a checksum from the same server proves
# nothing). Bump together with TOMCAT_VERSION; overriding only the version
# fails the build by design. With the hash pinned the download source does not
# matter, so try the Apache CDN first (fast) and fall back to the archive
# (complete, but heavily throttled: it took ~6.5 minutes of a 7-minute build).
ARG TOMCAT_SHA512=a617896307cada4884b24f80c4e977ddad8b3e0f88ce0e2a6eea29d5f332498e276ae5976c227a9c8daecf05c7c90def684a3766dd5a81f47a56d8b1adf43dc3
# busybox wget/tar from the base are enough: no curl or GNU tar, and nothing
# from this stage except /opt/tomcat reaches the final image. All bundled
# webapps go, ROOT included (its welcome page discloses the server version);
# Windows scripts and the native-library source tarballs go too. The install is
# root-owned and read-only; appuser can write only the runtime dirs (logs,
# temp, work, webapps, conf/Catalina), so a compromised app cannot rewrite
# bin/, lib/ or the server config.
RUN TMAJOR="${TOMCAT_VERSION%%.*}" && \
    TPATH="tomcat/tomcat-${TMAJOR}/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz" && \
    { wget -q -O /tmp/tomcat.tar.gz "https://dlcdn.apache.org/${TPATH}" || \
      wget -q -O /tmp/tomcat.tar.gz "https://archive.apache.org/dist/${TPATH}"; } && \
    echo "${TOMCAT_SHA512}  /tmp/tomcat.tar.gz" | sha512sum -c - && \
    mkdir -p /opt/tomcat && \
    tar -C /opt/tomcat --strip-components=1 -xzf /tmp/tomcat.tar.gz && \
    rm -rf /opt/tomcat/webapps/* /opt/tomcat/bin/*.bat /opt/tomcat/bin/*.tar.gz && \
    mkdir -p /opt/tomcat/conf/Catalina/localhost && \
    chown -R root:appuser /opt/tomcat && \
    chmod -R g+rX,g-w,o-rwx /opt/tomcat && \
    chown -R appuser:appuser /opt/tomcat/logs /opt/tomcat/temp /opt/tomcat/work \
                             /opt/tomcat/webapps /opt/tomcat/conf/Catalina

# ---- runtime -----------------------------------------------------------------
FROM ${BASE_IMAGE}

ARG TOMCAT_VERSION=11.0.27

LABEL maintainer="Golden Image Build System" \
      org.opencontainers.image.vendor="Golden Image Build System" \
      org.opencontainers.image.title="Tomcat Platform (CIS-hardened)" \
      org.opencontainers.image.description="Apache Tomcat ${TOMCAT_VERSION} on a CIS-hardened Alpine OpenJDK base, non-root" \
      org.opencontainers.image.licenses="MIT" \
      io.golden-image.cis.benchmark="CIS Docker Benchmark v1.7.0"

USER root
ENV CATALINA_HOME=/opt/tomcat \
    CATALINA_BASE=/opt/tomcat \
    CATALINA_TMPDIR=/opt/tomcat/temp \
    JAVA_OPTS="-Djava.awt.headless=true -Dfile.encoding=UTF-8"

ARG PATCH_EPOCH
RUN --mount=type=bind,source=scripts/container,target=/opt/golden-scripts \
    echo "patch epoch: ${PATCH_EPOCH:-unset}" && \
    apk upgrade --no-cache && \
    sh /opt/golden-scripts/harden-runtime.sh

# Ownership and modes are carried over from the fetch stage.
COPY --from=fetch /opt/tomcat /opt/tomcat

USER appuser
WORKDIR /app
EXPOSE 8080

# Healthy once the connector answers HTTP at all (any status: a fresh image has
# no ROOT app, so 404 is the expected answer). busybox wget prints "HTTP/" only
# when a server actually responded.
HEALTHCHECK --interval=30s --timeout=3s --start-period=20s --retries=3 \
    CMD wget -q -S -O /dev/null http://127.0.0.1:8080/ 2>&1 | grep -q 'HTTP/' || exit 1

ENTRYPOINT ["/sbin/tini", "--"]
CMD ["/opt/tomcat/bin/catalina.sh", "run"]
