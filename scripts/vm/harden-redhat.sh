#!/usr/bin/env bash
# Host CIS hardening for RHEL/RedHat VM images (run by Packer on a real VM).
#
# Runs on a full VM with systemd, so kernel/host controls are valid here. It
# applies supplementary CIS RHEL Benchmark items that complement the OpenSCAP
# SSG remediation in scripts/vm/openscap-remediate.sh, and runs BEFORE it.
#
# Optional: set REMOTE_LOG_HOST=loghost.example.com to enable remote logging.
set -euo pipefail

PKG=dnf; command -v dnf >/dev/null 2>&1 || PKG=yum

echo "[vm-harden-redhat] Installing hardening tooling"
$PKG install -y audit libpwquality firewalld chrony

echo "[vm-harden-redhat] Password policy (login.defs + pwquality)  [CIS 5.4]"
sed -i 's/^[#[:space:]]*PASS_MAX_DAYS.*/PASS_MAX_DAYS 365/' /etc/login.defs
sed -i 's/^[#[:space:]]*PASS_MIN_DAYS.*/PASS_MIN_DAYS 1/'   /etc/login.defs
sed -i 's/^[#[:space:]]*PASS_WARN_AGE.*/PASS_WARN_AGE 7/'   /etc/login.defs
sed -i 's/^[#[:space:]]*UMASK.*/UMASK 027/'                 /etc/login.defs
if [ -f /etc/security/pwquality.conf ]; then
  sed -i 's/^[#[:space:]]*minlen.*/minlen = 14/'   /etc/security/pwquality.conf
  sed -i 's/^[#[:space:]]*dcredit.*/dcredit = -1/' /etc/security/pwquality.conf
  sed -i 's/^[#[:space:]]*ucredit.*/ucredit = -1/' /etc/security/pwquality.conf
  sed -i 's/^[#[:space:]]*ocredit.*/ocredit = -1/' /etc/security/pwquality.conf
  sed -i 's/^[#[:space:]]*lcredit.*/lcredit = -1/' /etc/security/pwquality.conf
fi

echo "[vm-harden-redhat] Disable unused filesystem & protocol kernel modules  [CIS 1.1 / 3.4]"
for mod in cramfs freevxfs jffs2 hfs hfsplus squashfs udf usb-storage dccp sctp rds tipc; do
  echo "install $mod /bin/false" > "/etc/modprobe.d/${mod}.conf"
done

echo "[vm-harden-redhat] SSH daemon hardening  [CIS 5.2]"
if [ -f /etc/ssh/sshd_config ]; then
  install -d -m 0700 /etc/ssh/sshd_config.d 2>/dev/null || true
  cat > /etc/ssh/sshd_config.d/99-cis.conf <<'EOF'
PermitRootLogin no
PasswordAuthentication no
PermitEmptyPasswords no
X11Forwarding no
MaxAuthTries 4
ClientAliveInterval 300
ClientAliveCountMax 0
LoginGraceTime 60
Banner /etc/issue.net
Ciphers aes256-gcm@openssh.com,chacha20-poly1305@openssh.com,aes256-ctr
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com
EOF
  chmod 0600 /etc/ssh/sshd_config.d/99-cis.conf
fi

echo "[vm-harden-redhat] Kernel network/sysctl hardening  [CIS 3.x / 1.5]"
cat > /etc/sysctl.d/99-cis-hardening.conf <<'EOF'
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
net.ipv4.conf.all.rp_filter = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv6.conf.all.accept_redirects = 0
kernel.randomize_va_space = 2
fs.suid_dumpable = 0
EOF
sysctl --system >/dev/null || true

echo "[vm-harden-redhat] Host firewall default-deny  [CIS 4.x]"
systemctl enable firewalld
systemctl start firewalld 2>/dev/null || true
firewall-cmd --set-default-zone=drop 2>/dev/null || true
firewall-cmd --permanent --add-service=ssh 2>/dev/null || true
firewall-cmd --reload 2>/dev/null || true

echo "[vm-harden-redhat] Enable auditing  [CIS 4.1 / 6.2]"
systemctl enable auditd

echo "[vm-harden-redhat] Permissions on sensitive files  [CIS 6.1]"
chown root:root /etc/passwd /etc/group; chmod 0644 /etc/passwd /etc/group
chown root:root /etc/shadow /etc/gshadow 2>/dev/null || true
chmod 0000 /etc/shadow /etc/gshadow 2>/dev/null || true

if [ -n "${REMOTE_LOG_HOST:-}" ]; then
  echo "[vm-harden-redhat] Configuring remote logging to ${REMOTE_LOG_HOST}"
  echo "*.* @@${REMOTE_LOG_HOST}:514" > /etc/rsyslog.d/99-remote.conf
  systemctl restart rsyslog || true
fi

echo "[vm-harden-redhat] Supplementary host hardening complete."
