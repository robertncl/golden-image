#!/bin/bash
# RedHat Hardening Script
# Based on CIS Container Security Best Practices

set -e

echo "🔒 Starting RedHat hardening process..."

# Update all packages
dnf update -y

# Install essential security packages
dnf install -y \
    ca-certificates \
    curl \
    dumb-init \
    gosu \
    tini

# Create non-root user
groupadd -g 1000 appuser
useradd -m -s /bin/bash -u 1000 -g appuser appuser

# Security hardening
echo "🔧 Applying security hardening..."

# Only remove packages that are safe to remove
dnf remove -y subscription-manager subscription-manager-rhsm subscription-manager-rhsm-certificates || true

# Clean package cache
dnf clean all

# Set proper file permissions
chmod 755 /usr/bin
chmod 755 /usr/lib
chmod 755 /usr/sbin

# Create necessary directories
mkdir -p /app /tmp /var/tmp
chown appuser:appuser /app
chmod 755 /app

# Security configurations
echo "📝 Configuring security settings..."

# Create limits.conf if it doesn't exist
touch /etc/security/limits.conf

# Disable core dumps
echo "* soft core 0" >> /etc/security/limits.conf
echo "* hard core 0" >> /etc/security/limits.conf

# Set umask
echo "umask 027" >> /etc/profile

# Configure system limits
echo "appuser soft nofile 65536" >> /etc/security/limits.conf
echo "appuser hard nofile 65536" >> /etc/security/limits.conf

# Remove unnecessary files (but be careful)
find /var/log -type f -delete 2>/dev/null || true
find /tmp -type f -delete 2>/dev/null || true
find /var/tmp -type f -delete 2>/dev/null || true

# Remove documentation (but be careful)
rm -rf /usr/share/doc/* 2>/dev/null || true
rm -rf /usr/share/man/* 2>/dev/null || true
rm -rf /usr/share/locale/* 2>/dev/null || true

# Set proper ownership
chown -R appuser:appuser /home/appuser

echo "✅ RedHat hardening completed successfully!" 