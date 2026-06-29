# syntax=docker/dockerfile:1
# .NET Runtime platform image — built on the CIS-hardened Debian base, runs
# non-root. The runtime is installed from Microsoft's official, signed apt feed
# (CIS 4.11 — verified packages).
ARG BASE_IMAGE=ghcr.io/your-org/debian-hardened:12
FROM ${BASE_IMAGE}

ARG BUILD_DATE
ARG VCS_REF
ARG VERSION=1.0.0
ARG DOTNET_VERSION=8.0

LABEL maintainer="Golden Image Build System" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.vendor="Golden Image Build System" \
      org.opencontainers.image.title=".NET Runtime Platform (CIS-hardened)" \
      org.opencontainers.image.description=".NET ${DOTNET_VERSION} runtime on a CIS-hardened Debian base, non-root" \
      org.opencontainers.image.source="https://github.com/your-org/golden-image" \
      org.opencontainers.image.licenses="MIT" \
      io.golden-image.cis.benchmark="CIS Docker Benchmark v1.7.0"

USER root
ENV DEBIAN_FRONTEND=noninteractive

COPY scripts/container/harden-runtime.sh /tmp/harden-runtime.sh
# Use Microsoft's install script (multi-arch: auto-detects arm64/amd64) rather
# than the apt feed, which doesn't carry arm64 packages.
RUN mkdir -p /usr/share/man/man1 && \
    apt-get update && \
    apt-get upgrade -y --no-install-recommends && \
    apt-get install -y --no-install-recommends curl ca-certificates libicu72 && \
    curl -fsSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh && \
    chmod +x /tmp/dotnet-install.sh && \
    /tmp/dotnet-install.sh --runtime dotnet --version "${DOTNET_VERSION}.0" --install-dir /usr/share/dotnet && \
    ln -sf /usr/share/dotnet/dotnet /usr/bin/dotnet && \
    rm -f /tmp/dotnet-install.sh && \
    apt-get purge -y curl && apt-get autoremove -y && \
    chown -R appuser:appuser /app && \
    sh /tmp/harden-runtime.sh && rm -f /tmp/harden-runtime.sh && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

ENV DOTNET_RUNNING_IN_CONTAINER=true \
    DOTNET_CLI_TELEMETRY_OPTOUT=1 \
    DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false

USER appuser
WORKDIR /app

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD dotnet --info || exit 1

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["dotnet", "--info"]
