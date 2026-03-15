#!/bin/bash
LOG_FILE="supply-chain-monitor.log"
ALERT_THRESHOLD=5

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

check_image_security() {
    local image=$1
    log_message "Checking: $image"

    if cosign verify --key ~/lab14-keys/cosign.pub \
       --allow-insecure-registry "$image" >/dev/null 2>&1; then
        log_message "  ✓ Signature verified"
    else
        log_message "  ✗ Signature missing or invalid"
    fi

    CRIT=$(trivy image --severity CRITICAL --format json "$image" 2>/dev/null | \
           jq '[.Results[].Vulnerabilities[]] | length' 2>/dev/null || echo "0")

    if [ "$CRIT" -gt "$ALERT_THRESHOLD" ]; then
        log_message "  🚨 ALERT: $CRIT critical vulns (threshold: $ALERT_THRESHOLD)"
    else
        log_message "  ✓ Vuln check passed ($CRIT critical)"
    fi
}

log_message "=== Supply Chain Monitor Started ==="

IMAGES=("localhost:5000/node:16-alpine" "localhost:5000/secure-app:v1.0.0")
for img in "${IMAGES[@]}"; do
    check_image_security "$img"
done

log_message "=== Monitoring Complete ==="
