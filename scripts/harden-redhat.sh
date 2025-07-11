#!/bin/bash
set -euo pipefail

# Example CIS hardening script for RedHat (advanced)
# This script applies several CIS controls. Expand as needed.

# 1. Ensure password expiration is 90 days or less
chage --maxdays 90 root

# 2. Ensure password complexity (minlen=14, at least 1 upper/lower/digit/special)
sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS   90/' /etc/login.defs
sed -i 's/^PASS_MIN_DAYS.*/PASS_MIN_DAYS   7/' /etc/login.defs
sed -i 's/^PASS_MIN_LEN.*/PASS_MIN_LEN    14/' /etc/login.defs
yum install -y libpwquality
if ! grep -q pam_pwquality.so /etc/pam.d/system-auth; then
  echo 'password requisite pam_pwquality.so retry=3 minlen=14 ucredit=-1 lcredit=-1 dcredit=-1 ocredit=-1' >> /etc/pam.d/system-auth
fi

# 3. Disable unused filesystems
for fs in cramfs freevxfs jffs2 hfs hfsplus squashfs udf vfat; do
  echo "install $fs /bin/true" > "/etc/modprobe.d/$fs.conf"
done

# 4. Ensure SSH root login is disabled
sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config

# 5. Ensure SSH uses protocol 2 only
sed -i 's/^Protocol.*/Protocol 2/' /etc/ssh/sshd_config

# 6. Ensure firewalld is enabled and default deny
systemctl enable firewalld --now
firewall-cmd --set-default-zone=drop

# 7. Enable auditing
yum install -y audit
systemctl enable auditd --now

# 8. Harden sysctl settings (network, kernel)
cat <<EOF > /etc/sysctl.d/99-cis-hardening.conf
net.ipv4.ip_forward = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
kernel.randomize_va_space = 2
EOF
sysctl --system

# 9. Ensure permissions on /etc/passwd are configured
chmod 644 /etc/passwd
chown root:root /etc/passwd

# 10. Configure rsyslog for remote logging (example: loghost.example.com)
if ! grep -q '^*.* @' /etc/rsyslog.conf; then
  echo '*.* @loghost.example.com:514' >> /etc/rsyslog.conf
  systemctl restart rsyslog || service rsyslog restart
fi

# 11. Restart SSH to apply changes
systemctl restart sshd || service sshd restart

echo "Advanced CIS hardening for RedHat complete." 