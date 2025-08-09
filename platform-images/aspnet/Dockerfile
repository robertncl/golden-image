# ASP.NET Core Platform Image
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
      org.opencontainers.image.title="ASP.NET Core Platform" \
      org.opencontainers.image.description="ASP.NET Core platform image based on hardened Debian" \
      org.opencontainers.image.source="https://github.com/your-org/golden-image" \
      org.opencontainers.image.licenses="MIT"

# Switch to root for installation
USER root

# Install ASP.NET Core Runtime
RUN apt-get update && \
    apt-get upgrade -y --no-install-recommends && \
    apt-get install -y --no-install-recommends \
        wget \
        ca-certificates \
        curl \
    && wget -O /tmp/aspnetcore.tar.gz https://download.microsoft.com/download/8/4/c/84c6c430-e0f5-476d-bf3d-6b2b1c83c6f2/aspnetcore-runtime-8.0.0-linux-x64.tar.gz \
    && mkdir -p /usr/share/dotnet \
    && tar -C /usr/share/dotnet -xzf /tmp/aspnetcore.tar.gz \
    && ln -s /usr/share/dotnet/dotnet /usr/bin/dotnet \
    && rm /tmp/aspnetcore.tar.gz \
    && apt-get remove -y wget \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

# Create aspnet user
RUN groupadd -g 104 aspnet && \
    useradd -r -u 104 -g aspnet aspnet

# Set environment variables
ENV DOTNET_RUNNING_IN_CONTAINER=true \
    DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false \
    ASPNETCORE_URLS=http://+:80

# Create application directory
RUN mkdir -p /app && \
    chown aspnet:aspnet /app

# Switch to aspnet user
USER aspnet

# Set working directory
WORKDIR /app

# Expose port
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost/health || exit 1

# Default command
CMD ["dotnet", "--version"] 