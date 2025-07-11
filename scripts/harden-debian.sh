#!/bin/bash
# Debian Hardening Script
# Based on CIS Container Security Best Practices

set -e

echo "🔒 Starting Debian hardening process..."

# Update package lists and upgrade all packages
apt-get update
apt-get upgrade -y

# Install essential security packages
apt-get install -y --no-install-recommends \
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

# Remove unnecessary packages
apt-get purge -y \
    apt-utils \
    dialog \
    gnupg \
    gpg-agent \
    less \
    nano \
    vim-tiny

# Clean package cache
apt-get autoremove -y
apt-get autoclean
rm -rf /var/lib/apt/lists/*

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

# Remove unnecessary files and directories
find /var/log -type f -delete
find /tmp -type f -delete
find /var/tmp -type f -delete

# Remove unnecessary system files
rm -rf /usr/share/doc/*
rm -rf /usr/share/man/*
rm -rf /usr/share/locale/*
rm -rf /var/cache/debconf/*

# Set proper ownership
chown -R appuser:appuser /home/appuser

# Configure PAM security
cat > /etc/pam.d/common-password << EOF
password requisite pam_pwquality.so retry=3
password [success=1 default=ignore] pam_unix.so obscure sha512
password requisite pam_deny.so
password required pam_permit.so
EOF

echo "✅ Debian hardening completed successfully!" 