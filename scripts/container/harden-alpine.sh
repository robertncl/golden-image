#!/bin/sh
# Container CIS hardening for Alpine base images.
#
# Build-time safe: applies ONLY controls that are valid inside an OCI image
# and that map to the CIS Docker Benchmark v1.7.0 (section 4) and the
# CIS Docker-Image (CIS-DI) checks enforced by Dockle.
#
# Host/kernel controls (sshd, auditd, firewall, sysctl, iptables) are
# intentionally NOT applied here -- those belong to the VM hardening path
# in scripts/vm/.  Running them during `docker build` is a no-op at best and
# aborts the build at worst, which is the bug this rewrite fixes.
set -eu

APP_USER="${APP_USER:-appuser}"
APP_UID="${APP_UID:-10001}"
APP_GID="${APP_GID:-10001}"
APP_HOME="${APP_HOME:-/app}"

echo "[harden-alpine] Creating non-root user ${APP_USER} (${APP_UID}:${APP_GID})  [CIS 4.1 / CIS-DI-0001]"
addgroup -g "${APP_GID}" "${APP_USER}"
adduser -D -H -u "${APP_UID}" -G "${APP_USER}" -h "${APP_HOME}" -s /bin/sh "${APP_USER}"
mkdir -p "${APP_HOME}"
chown "${APP_UID}:${APP_GID}" "${APP_HOME}"
chmod 0750 "${APP_HOME}"

echo "[harden-alpine] Locking default system accounts"
for u in daemon bin sys adm lp sync shutdown halt mail news uucp operator man \
         cron ftp sshd at squid xfs games postgres nut smmsp guest nobody; do
  if id "$u" >/dev/null 2>&1; then
    passwd -l "$u" 2>/dev/null || true
  fi
done

echo "[harden-alpine] Hardening /etc/login.defs (UMASK 027, password aging)"
if [ -f /etc/login.defs ]; then
  sed -i 's/^[#[:space:]]*UMASK.*/UMASK 027/'                 /etc/login.defs || true
  sed -i 's/^[#[:space:]]*PASS_MAX_DAYS.*/PASS_MAX_DAYS 365/' /etc/login.defs || true
  sed -i 's/^[#[:space:]]*PASS_MIN_DAYS.*/PASS_MIN_DAYS 1/'   /etc/login.defs || true
  sed -i 's/^[#[:space:]]*PASS_WARN_AGE.*/PASS_WARN_AGE 7/'   /etc/login.defs || true
  grep -q '^UMASK'         /etc/login.defs || echo 'UMASK 027'         >> /etc/login.defs
  grep -q '^PASS_MAX_DAYS' /etc/login.defs || echo 'PASS_MAX_DAYS 365' >> /etc/login.defs
fi

echo "[harden-alpine] Setting ownership/permissions on account files"
chown root:root /etc/passwd /etc/group 2>/dev/null || true
chmod 0644 /etc/passwd /etc/group     2>/dev/null || true
chmod 0640 /etc/shadow /etc/gshadow   2>/dev/null || true

echo "[harden-alpine] Removing setuid/setgid bits from binaries  [CIS 4.8 / CIS-DI-0008]"
find / -xdev -type f \( -perm -4000 -o -perm -2000 \) 2>/dev/null | while IFS= read -r f; do
  chmod -s "$f" 2>/dev/null || true
done

echo "[harden-alpine] Removing world-writable file permissions"
find / -xdev -type f -perm -0002 2>/dev/null | while IFS= read -r f; do
  chmod o-w "$f" 2>/dev/null || true
done

echo "[harden-alpine] Purging package caches, docs, man pages and tmp"
rm -rf /var/cache/apk/* /tmp/* /var/tmp/* \
       /usr/share/man/* /usr/share/doc/* /usr/share/info/* 2>/dev/null || true

echo "[harden-alpine] Container CIS hardening complete."
