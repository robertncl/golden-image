# Tomcat Platform Image
FROM ${GHCR_REGISTRY}/${GHCR_NAMESPACE}/openjdk-platform:latest

# Set build arguments
ARG BUILD_DATE
ARG VCS_REF
ARG VERSION=10.1

# Set labels
LABEL maintainer="Golden Image Build System" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.vendor="Golden Image Build System" \
      org.opencontainers.image.title="Tomcat Platform" \
      org.opencontainers.image.description="Tomcat platform image based on OpenJDK" \
      org.opencontainers.image.source="https://github.com/your-org/golden-image" \
      org.opencontainers.image.licenses="MIT"

# Switch to root for installation
USER root

# Install Tomcat
RUN apt-get update && \
    apt-get upgrade -y --no-install-recommends && \
    apt-get install -y --no-install-recommends \
        wget \
        ca-certificates \
    && wget -O /tmp/tomcat.tar.gz https://archive.apache.org/dist/tomcat/tomcat-10/v10.1.17/bin/apache-tomcat-10.1.17.tar.gz \
    && mkdir -p /opt/tomcat \
    && tar -C /opt/tomcat --strip-components=1 -xzf /tmp/tomcat.tar.gz \
    && rm /tmp/tomcat.tar.gz \
    && apt-get remove -y wget \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

# Create tomcat user
RUN groupadd -g 105 tomcat && \
    useradd -r -u 105 -g tomcat tomcat

# Configure Tomcat
RUN chown -R tomcat:tomcat /opt/tomcat && \
    chmod +x /opt/tomcat/bin/*.sh

# Set environment variables
ENV CATALINA_HOME=/opt/tomcat \
    CATALINA_BASE=/opt/tomcat \
    CATALINA_TMPDIR=/opt/tomcat/temp \
    JAVA_OPTS="-Djava.awt.headless=true -Dfile.encoding=UTF-8"

# Create application directory
RUN mkdir -p /app && \
    chown tomcat:tomcat /app

# Switch to tomcat user
USER tomcat

# Set working directory
WORKDIR /app

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/ || exit 1

# Default command
CMD ["/opt/tomcat/bin/catalina.sh", "run"] 