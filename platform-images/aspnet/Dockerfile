# syntax=docker/dockerfile:1
# ASP.NET Core platform image — built on the CIS-hardened Alpine base, runs
# non-root on an unprivileged port (8080). The musl .NET runtime is installed
# from Microsoft's official install script (auto-selects linux-musl-<arch>).
ARG BASE_IMAGE=ghcr.io/your-org/alpine-hardened:3.24
FROM ${BASE_IMAGE}

ARG BUILD_DATE
ARG VCS_REF
ARG VERSION=1.0.0
ARG ASPNET_VERSION=10.0

LABEL maintainer="Golden Image Build System" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.vendor="Golden Image Build System" \
      org.opencontainers.image.title="ASP.NET Core Platform (CIS-hardened)" \
      org.opencontainers.image.description="ASP.NET Core ${ASPNET_VERSION} runtime on a CIS-hardened Alpine base, non-root" \
      org.opencontainers.image.source="https://github.com/your-org/golden-image" \
      org.opencontainers.image.licenses="MIT" \
      io.golden-image.cis.benchmark="CIS Docker Benchmark v1.7.0"

USER root

# Runtime deps for musl .NET (icu-libs enables full globalization); bash + curl
# are only needed to run the install script and are removed afterwards.
COPY scripts/container/harden-runtime.sh /tmp/harden-runtime.sh
RUN apk update && apk upgrade --no-cache && \
    apk add --no-cache icu-libs libgcc libssl3 libstdc++ zlib && \
    apk add --no-cache --virtual .dotnet-install curl bash && \
    curl -fsSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh && \
    bash /tmp/dotnet-install.sh --runtime aspnetcore --channel "${ASPNET_VERSION}" --install-dir /usr/share/dotnet && \
    ln -sf /usr/share/dotnet/dotnet /usr/bin/dotnet && \
    rm -f /tmp/dotnet-install.sh && \
    apk del .dotnet-install && \
    chown -R appuser:appuser /app && \
    sh /tmp/harden-runtime.sh && rm -f /tmp/harden-runtime.sh

ENV DOTNET_RUNNING_IN_CONTAINER=true \
    DOTNET_CLI_TELEMETRY_OPTOUT=1 \
    DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false \
    ASPNETCORE_URLS=http://+:8080

USER appuser
WORKDIR /app
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD dotnet --info || exit 1

ENTRYPOINT ["/sbin/tini", "--"]
CMD ["dotnet", "--info"]
