# Python Platform Image
FROM ${ACR_LOGIN_SERVER}/debian-hardened:latest

# Set build arguments
ARG BUILD_DATE
ARG VCS_REF
ARG VERSION=3.11

# Set labels
LABEL maintainer="Golden Image Build System" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.vendor="Golden Image Build System" \
      org.opencontainers.image.title="Python Platform" \
      org.opencontainers.image.description="Python platform image based on hardened Debian" \
      org.opencontainers.image.source="https://github.com/your-org/golden-image" \
      org.opencontainers.image.licenses="MIT"

# Switch to root for installation
USER root

# Install Python and essential packages
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        python3.11 \
        python3.11-dev \
        python3-pip \
        python3-setuptools \
        python3-wheel \
        ca-certificates \
        curl \
        build-essential \
    && rm -rf /var/lib/apt/lists/*

# Create python user
RUN groupadd -g 102 python && \
    useradd -r -u 102 -g python python

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Create application directory
RUN mkdir -p /app && \
    chown python:python /app

# Switch to python user
USER python

# Set working directory
WORKDIR /app

# Create virtual environment
RUN python3 -m venv /app/venv
ENV PATH="/app/venv/bin:$PATH"

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python3 --version || exit 1

# Default command
CMD ["python3", "--version"] 