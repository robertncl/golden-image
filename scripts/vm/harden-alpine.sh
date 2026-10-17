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
# sshd keeps the FIRST value it reads, so these must come before anything else:
# an early-sorting drop-in when sshd_config includes sshd_config.d, otherwise
# prepended to sshd_config (appending would let earlier lines win).
if [ -f /etc/ssh/sshd_config ]; then
  CIS_SSHD="PermitRootLogin no
PasswordAuthentication no
PermitEmptyPasswords no
X11Forwarding no
MaxAuthTries 4
ClientAliveInterval 300
ClientAliveCountMax 0"
  if grep -qE '^[[:space:]]*Include[[:space:]]+/etc/ssh/sshd_config\.d/' /etc/ssh/sshd_config; then
    install -d -m 0700 /etc/ssh/sshd_config.d
    printf '%s\n' "${CIS_SSHD}" > /etc/ssh/sshd_config.d/00-cis.conf
    chmod 0600 /etc/ssh/sshd_config.d/00-cis.conf
  else
    { printf '%s\n' "${CIS_SSHD}"; cat /etc/ssh/sshd_config; } > /etc/ssh/sshd_config.new
    chmod 0600 /etc/ssh/sshd_config.new
    mv /etc/ssh/sshd_config.new /etc/ssh/sshd_config
  fi
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

echo "[vm-harden-alpine] Default-deny firewall (iptables + ip6tables)  [CIS 4.x]"
# Allow rules first, then the DROP policy, so the live SSH session survives.
for ipt in iptables ip6tables; do
  $ipt -A INPUT -i lo -j ACCEPT 2>/dev/null || true
  $ipt -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || true
  $ipt -A INPUT -p tcp --dport 22 -j ACCEPT 2>/dev/null || true
  $ipt -P INPUT DROP   2>/dev/null || true
  $ipt -P FORWARD DROP 2>/dev/null || true
  $ipt -P OUTPUT ACCEPT 2>/dev/null || true
done
# ICMPv6 neighbour discovery is required for IPv6 to function at all.
ip6tables -I INPUT 2 -p ipv6-icmp -j ACCEPT 2>/dev/null || true
# Persist the rules: the OpenRC services restore /etc/iptables/rules{,6}-save at
# boot, so without a save the image boots with an empty, allow-all ruleset.
/etc/init.d/iptables save
/etc/init.d/ip6tables save
rc-update add iptables default
rc-update add ip6tables default

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
