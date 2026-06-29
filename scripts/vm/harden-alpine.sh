#!/bin/sh
# Host CIS hardening for Alpine VM images (run by Packer on a real VM).
#
# Alpine uses OpenRC (not systemd) and has NO official CIS SCAP Security Guide
# content, so there is no OpenSCAP remediation/scan for Alpine — this script is
# the hardening source of truth for Alpine VMs. (Documented in CIS-COMPLIANCE.md.)
#
# Optional: set REMOTE_LOG_HOST=loghost.example.com to enable remote logging.
set -eu

echo "[vm-harden-alpine] Installing hardening tooling"
apk update
apk add --no-cache audit openssh-server iptables ip6tables chrony

echo "[vm-harden-alpine] Password policy  [CIS 5.4]"
if [ -f /etc/login.defs ]; then
  sed -i 's/^[#[:space:]]*PASS_MAX_DAYS.*/PASS_MAX_DAYS 365/' /etc/login.defs || true
  sed -i 's/^[#[:space:]]*PASS_MIN_DAYS.*/PASS_MIN_DAYS 1/'   /etc/login.defs || true
  sed -i 's/^[#[:space:]]*UMASK.*/UMASK 027/'                 /etc/login.defs || true
fi

echo "[vm-harden-alpine] Disable unused filesystem & protocol kernel modules  [CIS 1.1 / 3.4]"
for mod in cramfs freevxfs jffs2 hfs hfsplus squashfs udf usb-storage dccp sctp rds tipc; do
  echo "install $mod /bin/false" > "/etc/modprobe.d/${mod}.conf"
done

echo "[vm-harden-alpine] SSH daemon hardening  [CIS 5.2]"
if [ -f /etc/ssh/sshd_config ]; then
  {
    echo "PermitRootLogin no"
    echo "PasswordAuthentication no"
    echo "PermitEmptyPasswords no"
    echo "X11Forwarding no"
    echo "MaxAuthTries 4"
    echo "ClientAliveInterval 300"
    echo "ClientAliveCountMax 0"
  } >> /etc/ssh/sshd_config
fi

echo "[vm-harden-alpine] Kernel network/sysctl hardening  [CIS 3.x]"
cat > /etc/sysctl.d/99-cis-hardening.conf <<EOF
net.ipv4.ip_forward = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
kernel.randomize_va_space = 2
fs.suid_dumpable = 0
EOF
sysctl -p /etc/sysctl.d/99-cis-hardening.conf >/dev/null 2>&1 || true

echo "[vm-harden-alpine] Default-deny firewall (iptables)  [CIS 4.x]"
iptables -P INPUT DROP   2>/dev/null || true
iptables -P FORWARD DROP 2>/dev/null || true
iptables -P OUTPUT ACCEPT 2>/dev/null || true
iptables -A INPUT -i lo -j ACCEPT 2>/dev/null || true
iptables -A INPUT -p tcp --dport 22 -j ACCEPT 2>/dev/null || true
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || true
rc-update add iptables default 2>/dev/null || true

echo "[vm-harden-alpine] Enable auditing  [CIS 4.1]"
rc-update add auditd default 2>/dev/null || true

echo "[vm-harden-alpine] Permissions on sensitive files  [CIS 6.1]"
chown root:root /etc/passwd /etc/group; chmod 0644 /etc/passwd /etc/group
chmod 0640 /etc/shadow /etc/gshadow 2>/dev/null || true

if [ -n "${REMOTE_LOG_HOST:-}" ]; then
  echo "[vm-harden-alpine] Configuring remote logging to ${REMOTE_LOG_HOST}"
  echo "*.* @${REMOTE_LOG_HOST}:514" >> /etc/rsyslog.conf 2>/dev/null || true
fi

echo "[vm-harden-alpine] Alpine VM hardening complete."
