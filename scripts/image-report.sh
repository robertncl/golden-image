#!/usr/bin/env bash
# Size + vulnerability report for built images (Markdown table on stdout).
#
# For each image: uncompressed and compressed (pull) size, OS/library package
# count, and Trivy
# vulnerability counts at every severity (package instances, plus the number of
# distinct CVE IDs, since one CVE often hits several binary packages), and the
# "fixable HIGH/CRITICAL" count the CIS gate (scripts/cis-verify.sh) blocks on.
#
# Usage:   scripts/image-report.sh <image[:tag]> [...]
# Env:     REPORT_JSON_DIR=<dir>  keep the raw Trivy JSON per image
set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "usage: $0 <image[:tag]> [<image[:tag]> ...]" >&2
  exit 2
fi
command -v trivy >/dev/null 2>&1 || { echo "image-report: trivy is required (scripts/install-trivy.sh)" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "image-report: jq is required" >&2; exit 1; }

WORK="${REPORT_JSON_DIR:-$(mktemp -d)}"
mkdir -p "${WORK}"
[ -n "${REPORT_JSON_DIR:-}" ] || trap 'rm -rf "${WORK}"' EXIT

mb() { awk -v b="$1" 'BEGIN { printf "%.1f", b / 1000 / 1000 }'; }

echo "| Image | Size MB | Compressed MB | Packages | CRITICAL | HIGH | MEDIUM | LOW | Total | Unique CVEs | Fixable H/C |"
echo "|-------|--------:|--------------:|---------:|:--------:|:----:|:------:|:---:|:-----:|:-----------:|:-----------:|"
for image in "$@"; do
  out="${WORK}/$(echo "${image}" | tr '/:@' '___').json"
  trivy image --quiet --scanners vuln --list-all-pkgs --format json \
    --output "${out}" "${image}" >/dev/null
  # `docker save` streams the compressed layer blobs: a close proxy for the
  # bytes a registry pull transfers (the uncompressed size comes from Trivy).
  compressed="$(docker save "${image}" | wc -c)"
  jq -r --arg img "${image}" --arg comp "$(mb "${compressed}")" '
    [.Results[]? | .Vulnerabilities[]?] as $v
    | def n(s): [$v[] | select(.Severity == s)] | length;
    "| \($img) | \(.Metadata.Size / 1000000 * 10 | round / 10) | \($comp) | \([.Results[]? | .Packages[]?] | length) | \(n("CRITICAL")) | \(n("HIGH")) | \(n("MEDIUM")) | \(n("LOW")) | \($v | length) | \([$v[].VulnerabilityID] | unique | length) | \([$v[] | select((.Severity == "HIGH" or .Severity == "CRITICAL") and (.FixedVersion // "") != "")] | length) |"
  ' "${out}"
done
