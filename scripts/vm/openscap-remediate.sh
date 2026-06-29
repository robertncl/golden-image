#!/usr/bin/env bash
# OpenSCAP CIS remediation + verification gate for Linux VM images.
#
# Installs the SCAP Security Guide (SSG), applies the CIS profile via
# `oscap xccdf eval --remediate`, then re-scans and FAILS the build if the
# compliance score is below MIN_SCORE. Reports (HTML + ARF) are written to
# /var/log/openscap so Packer can copy them out as build artifacts.
#
# Supported: rhel/centos/rocky/almalinux (ssg-rhel*), debian/ubuntu (ssg-debian*/
# ssg-ubuntu*). Alpine has no SSG content and is hardened by harden-alpine.sh.
set -uo pipefail

MIN_SCORE="${MIN_SCORE:-70}"
REPORT_DIR="${REPORT_DIR:-/var/log/openscap}"
mkdir -p "${REPORT_DIR}"

. /etc/os-release || true
OS_ID="${ID:-unknown}"
VER_MAJOR="${VERSION_ID%%.*}"

install_ssg() {
  case "${OS_ID}" in
    rhel|centos|rocky|almalinux|fedora)
      (command -v dnf >/dev/null 2>&1 && dnf install -y openscap-scanner scap-security-guide) || \
        yum install -y openscap-scanner scap-security-guide ;;
    debian|ubuntu)
      export DEBIAN_FRONTEND=noninteractive
      apt-get update
      apt-get install -y --no-install-recommends openscap-scanner ssg-debderived ssg-base ;;
    *)
      echo "[openscap] No SSG content for '${OS_ID}'. Skipping OpenSCAP (script-based hardening only)."
      exit 0 ;;
  esac
}

datastream() {
  # Pick the SSG data stream for this distro/version.
  case "${OS_ID}" in
    rhel|centos|rocky|almalinux) echo "/usr/share/xml/scap/ssg/content/ssg-rhel${VER_MAJOR}-ds.xml" ;;
    fedora)                      echo "/usr/share/xml/scap/ssg/content/ssg-fedora-ds.xml" ;;
    debian)                      echo "/usr/share/xml/scap/ssg/content/ssg-debian${VER_MAJOR}-ds.xml" ;;
    ubuntu)                      echo "/usr/share/xml/scap/ssg/content/ssg-ubuntu${VERSION_ID//./}-ds.xml" ;;
  esac
}

cis_profile() {
  # CIS Level 1 server profile id is consistent across SSG content.
  echo "xccdf_org.ssgproject.content_profile_cis"
}

install_ssg
DS="$(datastream)"
PROFILE="$(cis_profile)"

if [ ! -f "${DS}" ]; then
  echo "[openscap] Data stream not found at ${DS}; cannot run CIS remediation." >&2
  ls -1 /usr/share/xml/scap/ssg/content/ 2>/dev/null || true
  exit 1
fi

echo "[openscap] Remediating against ${PROFILE} using ${DS}"
# `--remediate` returns non-zero when rules were applied/failed; that is expected.
oscap xccdf eval --remediate \
  --profile "${PROFILE}" \
  --results "${REPORT_DIR}/cis-remediate-results.xml" \
  "${DS}" || true

echo "[openscap] Re-scanning to score compliance"
oscap xccdf eval \
  --profile "${PROFILE}" \
  --results-arf "${REPORT_DIR}/cis-arf.xml" \
  --report "${REPORT_DIR}/cis-report.html" \
  "${DS}" || true

SCORE="$(grep -oE 'score system="[^"]*">[0-9.]+' "${REPORT_DIR}/cis-arf.xml" 2>/dev/null | grep -oE '[0-9.]+$' | head -1)"
SCORE="${SCORE:-0}"
echo "[openscap] CIS compliance score: ${SCORE} (minimum required: ${MIN_SCORE})"

# Numeric comparison without bc.
if awk "BEGIN{exit !(${SCORE} >= ${MIN_SCORE})}"; then
  echo "[openscap] PASS — VM image meets the CIS compliance threshold."
  exit 0
else
  echo "[openscap] FAIL — CIS compliance score ${SCORE} is below ${MIN_SCORE}." >&2
  exit 1
fi
