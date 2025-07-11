# .NET Runtime Platform Image
FROM ${GHCR_REGISTRY}/${GHCR_NAMESPACE}/debian-hardened:latest

# Set build arguments
ARG BUILD_DATE
ARG VCS_REF
ARG VERSION=8.0

# Set labels
LABEL maintainer="Golden Image Build System" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.vendor="Golden Image Build System" \
      org.opencontainers.image.title=".NET Runtime Platform" \
      org.opencontainers.image.description=".NET Runtime platform image based on hardened Debian" \
      org.opencontainers.image.source="https://github.com/your-org/golden-image" \
      org.opencontainers.image.licenses="MIT"

# Switch to root for installation
USER root

# Install .NET Runtime
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        wget \
        ca-certificates \
        curl \
    && wget -O /tmp/dotnet.tar.gz https://download.microsoft.com/download/8/4/c/84c6c430-e0f5-476d-bf3d-6b2b1c83c6f2/dotnet-runtime-8.0.0-linux-x64.tar.gz \
    && mkdir -p /usr/share/dotnet \
    && tar -C /usr/share/dotnet -xzf /tmp/dotnet.tar.gz \
    && ln -s /usr/share/dotnet/dotnet /usr/bin/dotnet \
    && rm /tmp/dotnet.tar.gz \
    && apt-get remove -y wget \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

# Create dotnet user
RUN groupadd -g 103 dotnet && \
    useradd -r -u 103 -g dotnet dotnet

# Set environment variables
ENV DOTNET_RUNNING_IN_CONTAINER=true \
    DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false

# Create application directory
RUN mkdir -p /app && \
    chown dotnet:dotnet /app

# Switch to dotnet user
USER dotnet

# Set working directory
WORKDIR /app

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD dotnet --version || exit 1

# Default command
CMD ["dotnet", "--version"] 