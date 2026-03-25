#!/bin/bash
set -euo pipefail

# ─── Configuration ───────────────────────────────────────────
IMAGES=("node:16-alpine" "python:3.9-slim" "nginx:alpine")
DATE=$(date +%Y%m%d)
OUTPUT_DIR="./scan-results/${DATE}"
SEVERITY_THRESHOLD="HIGH,CRITICAL"
EXIT_CODE=0

# ─── Dependency Check ────────────────────────────────────────
if ! command -v trivy &>/dev/null; then
    echo "ERROR: trivy is not installed. https://aquasecurity.github.io/trivy"
    exit 1
fi

if ! command -v jq &>/dev/null; then
    echo "ERROR: jq is not installed."
    exit 1
fi

mkdir -p "${OUTPUT_DIR}"

# ─── Update DB once before scanning ──────────────────────────
echo "[*] Updating Trivy vulnerability database..."
trivy image --download-db-only --quiet

# ─── Scan Function ───────────────────────────────────────────
scan_image() {
    local image="$1"
    local safe_name="${image//[:\/]/_}"
    local json_out="${OUTPUT_DIR}/${safe_name}-scan-${DATE}.json"
    local sarif_out="${OUTPUT_DIR}/${safe_name}-scan-${DATE}.sarif"

    echo ""
    echo "══════════════════════════════════════════"
    echo "  Scanning: ${image}"
    echo "══════════════════════════════════════════"

    trivy image \
        --format json \
        --output "${json_out}" \
        --scanners vuln,secret \
        --quiet \
        "${image}"

    trivy image \
        --format sarif \
        --output "${sarif_out}" \
        --severity "${SEVERITY_THRESHOLD}" \
        --ignore-unfixed \
        --quiet \
        "${image}"

    local critical high medium
    critical=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="CRITICAL")] | length' "${json_out}" 2>/dev/null || echo 0)
    high=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="HIGH")] | length' "${json_out}" 2>/dev/null || echo 0)
    medium=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="MEDIUM")] | length' "${json_out}" 2>/dev/null || echo 0)

    echo "  CRITICAL : ${critical}"
    echo "  HIGH     : ${high}"
    echo "  MEDIUM   : ${medium}"
    echo "  Report   : ${json_out}"

    if [ "${critical}" -gt 0 ]; then
        echo "  ⚠️  WARNING: ${critical} CRITICAL vulnerabilities in ${image}!"
        EXIT_CODE=1
    elif [ "${high}" -gt 0 ]; then
        echo "  ⚠️  WARNING: ${high} HIGH vulnerabilities in ${image}!"
    else
        echo "  ✅ OK: No CRITICAL/HIGH vulnerabilities found."
    fi
}

# ─── Run Scans ───────────────────────────────────────────────
for image in "${IMAGES[@]}"; do
    scan_image "${image}"
done

# ─── Summary ─────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════"
echo "  Scan complete. Results in: ${OUTPUT_DIR}"
echo "══════════════════════════════════════════"

exit "${EXIT_CODE}"
