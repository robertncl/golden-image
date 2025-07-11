# Spring Boot Platform Image
FROM ${ACR_LOGIN_SERVER}/openjdk-platform:latest

# Set build arguments
ARG BUILD_DATE
ARG VCS_REF
ARG VERSION=3.2

# Set labels
LABEL maintainer="Golden Image Build System" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.vendor="Golden Image Build System" \
      org.opencontainers.image.title="Spring Boot Platform" \
      org.opencontainers.image.description="Spring Boot platform image based on OpenJDK" \
      org.opencontainers.image.source="https://github.com/your-org/golden-image" \
      org.opencontainers.image.licenses="MIT"

# Switch to root for installation
USER root

# Install additional packages for Spring Boot
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create spring user
RUN groupadd -g 106 spring && \
    useradd -r -u 106 -g spring spring

# Set environment variables
ENV SPRING_PROFILES_ACTIVE=docker \
    JAVA_OPTS="-Xmx512m -Xms256m -Djava.security.egd=file:/dev/./urandom"

# Create application directory
RUN mkdir -p /app && \
    chown spring:spring /app

# Switch to spring user
USER spring

# Set working directory
WORKDIR /app

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/actuator/health || exit 1

# Default command
CMD ["java", "-version"] 