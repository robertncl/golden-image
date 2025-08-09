# OpenJDK Platform Image
ARG BASE_IMAGE
FROM ${BASE_IMAGE}

# Set build arguments
ARG BUILD_DATE
ARG VCS_REF
ARG VERSION
ARG OPENJDK_VERSION=17
ARG JAVA_HOME=/usr/local/openjdk-17

# Set labels
LABEL maintainer="Golden Image Build System" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.vendor="Golden Image Build System" \
      org.opencontainers.image.title="OpenJDK Platform" \
      org.opencontainers.image.description="OpenJDK platform image based on hardened Debian" \
      org.opencontainers.image.source="https://github.com/your-org/golden-image" \
      org.opencontainers.image.licenses="MIT"

# Switch to root for installation
USER root

# Install OpenJDK
RUN apt-get update && \
    apt-get upgrade -y --no-install-recommends && \
    apt-get install -y --no-install-recommends \
        openjdk-${OPENJDK_VERSION}-jdk-headless \
        ca-certificates \
        curl \
    && rm -rf /var/lib/apt/lists/*

# Set environment variables
ENV JAVA_HOME=${JAVA_HOME} \
    PATH=${JAVA_HOME}/bin:$PATH

# Create application directory
RUN mkdir -p /app && \
    chown appuser:appuser /app

# Switch back to non-root user
USER appuser

# Set working directory
WORKDIR /app

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD java -version || exit 1

# Default command
CMD ["java", "-version"] 