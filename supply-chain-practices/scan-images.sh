#!/bin/bash
IMAGES=("node:16-alpine" "python:3.9-slim" "nginx:alpine")
DATE=$(date +%Y%m%d)

for image in "${IMAGES[@]}"; do
    echo "Scanning $image..."
    trivy image --format json "$image" > "${image//[:\/]/_}-scan-$DATE.json"

    CRITICAL_COUNT=$(trivy image --severity CRITICAL --format json "$image" | \
      jq '[.Results[].Vulnerabilities[]] | length' 2>/dev/null || echo "0")

    if [ "$CRITICAL_COUNT" -gt 0 ]; then
        echo "WARNING: $image has $CRITICAL_COUNT critical vulnerabilities!"
    else
        echo "OK: $image - no critical vulnerabilities"
    fi
done
