#!/bin/sh
# Alpine Linux Hardening Script
# Based on CIS Container Security Best Practices

set -e

echo "🔒 Starting Alpine Linux hardening process..."

# Update package index and upgrade all packages
apk update
apk upgrade

# Install essential security packages
apk add --no-cache \
    ca-certificates \
    curl \
    dumb-init \
    su-exec \
    tini

# Create non-root user
addgroup -g 1000 appuser
adduser -D -s /bin/sh -u 1000 -G appuser appuser

# Security hardening
echo "🔧 Applying security hardening..."

# Remove unnecessary packages and files
apk del --purge \
    apk-tools \
    busybox \
    libc-utils \
    ssl_client

# Clean package cache
rm -rf /var/cache/apk/*

# Set proper file permissions
chmod 755 /usr/bin
chmod 755 /usr/lib
chmod 755 /usr/sbin

# Create necessary directories with proper permissions
mkdir -p /app /tmp /var/tmp
chown appuser:appuser /app
chmod 755 /app

# Security configurations
echo "📝 Configuring security settings..."

# Disable core dumps
echo "* soft core 0" >> /etc/security/limits.conf
echo "* hard core 0" >> /etc/security/limits.conf

# Set umask for new files
echo "umask 027" >> /etc/profile

# Configure system limits
echo "appuser soft nofile 65536" >> /etc/security/limits.conf
echo "appuser hard nofile 65536" >> /etc/security/limits.conf

# Remove unnecessary files
find /var/log -type f -delete
find /tmp -type f -delete
find /var/tmp -type f -delete

# Set proper ownership
chown -R appuser:appuser /home/appuser

echo "✅ Alpine Linux hardening completed successfully!" 