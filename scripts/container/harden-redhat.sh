#!/usr/bin/env bash
# Container CIS hardening for RedHat UBI (ubi-minimal) base images.
#
# Build-time safe: applies ONLY controls valid inside an OCI image, mapping to
# the CIS Docker Benchmark v1.7.0 (section 4) and the CIS Docker-Image (CIS-DI)
# checks enforced by Dockle. Host/kernel controls live in scripts/vm/.
#
# ubi-minimal is heavily stripped: shadow-utils (useradd/passwd) may be absent.
# This script prefers the real tools when present and falls back to writing the
# account files directly so it works on the bare minimal image too.
set -euo pipefail

APP_USER="${APP_USER:-appuser}"
APP_UID="${APP_UID:-10001}"
APP_GID="${APP_GID:-10001}"
APP_HOME="${APP_HOME:-/app}"

echo "[harden-redhat] Creating non-root user ${APP_USER} (${APP_UID}:${APP_GID})  [CIS 4.1 / CIS-DI-0001]"
if command -v groupadd >/dev/null 2>&1 && command -v useradd >/dev/null 2>&1; then
  groupadd -g "${APP_GID}" "${APP_USER}"
  useradd --uid "${APP_UID}" --gid "${APP_GID}" --home-dir "${APP_HOME}" \
          --shell /sbin/nologin --no-create-home "${APP_USER}"
else
  if ! grep -q "^${APP_USER}:" /etc/group; then
    echo "${APP_USER}:x:${APP_GID}:" >> /etc/group
  fi
  if ! grep -q "^${APP_USER}:" /etc/passwd; then
    echo "${APP_USER}:x:${APP_UID}:${APP_GID}::${APP_HOME}:/sbin/nologin" >> /etc/passwd
  fi
fi
mkdir -p "${APP_HOME}"
chown "${APP_UID}:${APP_GID}" "${APP_HOME}"
chmod 0750 "${APP_HOME}"

echo "[harden-redhat] Locking default system accounts"
if command -v passwd >/dev/null 2>&1; then
  for u in bin daemon adm lp sync shutdown halt mail operator games ftp nobody; do
    if id "$u" >/dev/null 2>&1; then
      passwd -l "$u" 2>/dev/null || true
    fi
  done
fi

echo "[harden-redhat] Hardening /etc/login.defs (UMASK 027, SHA512, password aging)"
if [ -f /etc/login.defs ]; then
  sed -i 's/^[#[:space:]]*UMASK.*/UMASK 027/'                       /etc/login.defs || true
  sed -i 's/^[#[:space:]]*PASS_MAX_DAYS.*/PASS_MAX_DAYS 365/'       /etc/login.defs || true
  sed -i 's/^[#[:space:]]*PASS_MIN_DAYS.*/PASS_MIN_DAYS 1/'         /etc/login.defs || true
  sed -i 's/^[#[:space:]]*PASS_WARN_AGE.*/PASS_WARN_AGE 7/'         /etc/login.defs || true
  sed -i 's/^[#[:space:]]*ENCRYPT_METHOD.*/ENCRYPT_METHOD SHA512/'  /etc/login.defs || true
fi

echo "[harden-redhat] Setting ownership/permissions on account files"
chown root:root /etc/passwd /etc/group 2>/dev/null || true
chmod 0644 /etc/passwd /etc/group     2>/dev/null || true
chmod 0640 /etc/shadow /etc/gshadow   2>/dev/null || true

echo "[harden-redhat] Removing setuid/setgid bits from binaries  [CIS 4.8 / CIS-DI-0008]"
find / -xdev -type f \( -perm -4000 -o -perm -2000 \) 2>/dev/null | while IFS= read -r f; do
  chmod -s "$f" 2>/dev/null || true
done

echo "[harden-redhat] Removing world-writable file permissions"
find / -xdev -type f -perm -0002 2>/dev/null | while IFS= read -r f; do
  chmod o-w "$f" 2>/dev/null || true
done

echo "[harden-redhat] Purging dnf cache, docs, man pages and tmp"
rm -rf /var/cache/dnf/* /var/cache/yum/* /tmp/* /var/tmp/* \
       /usr/share/man/* /usr/share/doc/* /usr/share/info/* 2>/dev/null || true

echo "[harden-redhat] Container CIS hardening complete."
