#!/bin/sh
# Runtime CIS hardening for platform images.
#
# Run this AFTER installing platform packages in a derived image. Installing
# packages can re-introduce setuid/setgid binaries, world-writable files and
# package-manager caches, so this re-applies the image-level CIS controls.
# It deliberately does NOT create users (the hardened base already did that),
# so it is safe to run in any of the alpine/debian/redhat hardened bases.
set -eu

echo "[harden-runtime] Removing setuid/setgid bits  [CIS 4.8 / CIS-DI-0008]"
find / -xdev -type f \( -perm -4000 -o -perm -2000 \) 2>/dev/null | while IFS= read -r f; do
  chmod -s "$f" 2>/dev/null || true
done

echo "[harden-runtime] Removing world-writable file permissions"
find / -xdev -type f -perm -0002 2>/dev/null | while IFS= read -r f; do
  chmod o-w "$f" 2>/dev/null || true
done

echo "[harden-runtime] Purging package caches, docs, man pages and tmp"
rm -rf /var/cache/apk/* /var/lib/apt/lists/* /var/cache/apt/* \
       /var/cache/dnf/* /var/cache/yum/* /tmp/* /var/tmp/* \
       /usr/share/man/* /usr/share/doc/* /usr/share/info/* 2>/dev/null || true

echo "[harden-runtime] Runtime hardening complete."
