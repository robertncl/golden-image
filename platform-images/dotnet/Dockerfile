# syntax=docker/dockerfile:1
# .NET Runtime platform image — built on the CIS-hardened Alpine base, runs
# non-root.
#
# The runtime comes from Alpine's signed dotnet<major>-runtime package rather
# than Microsoft's dotnet-install.sh: no unpinned script piped from the web, no
# curl/bash build deps, patches arrive through `apk upgrade` like every other
# package, and Trivy tracks it through the Alpine security database.
# Alpine's .NET depends on icu-data-full (all locales, ~31 MiB), which real
# globalization needs anyway; the English-only icu-data-en it supersedes is
# removed.
ARG BASE_IMAGE=ghcr.io/robertncl/alpine-hardened:3.24
FROM ${BASE_IMAGE}

ARG DOTNET_VERSION=10.0

LABEL maintainer="Golden Image Build System" \
      org.opencontainers.image.vendor="Golden Image Build System" \
      org.opencontainers.image.title=".NET Runtime Platform (CIS-hardened)" \
      org.opencontainers.image.description=".NET ${DOTNET_VERSION} runtime on a CIS-hardened Alpine base, non-root" \
      org.opencontainers.image.licenses="MIT" \
      io.golden-image.cis.benchmark="CIS Docker Benchmark v1.7.0"

USER root

ARG PATCH_EPOCH
RUN --mount=type=bind,source=scripts/container,target=/opt/golden-scripts \
    echo "patch epoch: ${PATCH_EPOCH:-unset}" && \
    apk upgrade --no-cache && \
    apk add --no-cache "dotnet${DOTNET_VERSION%%.*}-runtime" && \
    apk del --no-cache icu-data-en && \
    chown -R appuser:appuser /app && \
    sh /opt/golden-scripts/harden-runtime.sh

ENV DOTNET_ROOT=/usr/lib/dotnet \
    DOTNET_RUNNING_IN_CONTAINER=true \
    DOTNET_CLI_TELEMETRY_OPTOUT=1 \
    DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false

USER appuser
WORKDIR /app

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD dotnet --list-runtimes | grep -q 'Microsoft.NETCore.App ' || exit 1

ENTRYPOINT ["/sbin/tini", "--"]
CMD ["dotnet", "--info"]
