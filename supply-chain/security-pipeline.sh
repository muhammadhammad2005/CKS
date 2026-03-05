#!/bin/bash
set -e

IMAGE_NAME=$1
if [ -z "$IMAGE_NAME" ]; then
    echo "Usage: $0 <image-name>"
    exit 1
fi

echo "=== Supply Chain Security Pipeline ==="
echo "Processing image: $IMAGE_NAME"

# Step 1: Generate SBOM
echo "Step 1: Generating SBOM..."
syft "$IMAGE_NAME" -o spdx-json > "${IMAGE_NAME//[:\/]/_}-sbom.json"
echo "SBOM generated: ${IMAGE_NAME//[:\/]/_}-sbom.json"

# Step 2: Vulnerability Scan
echo "Step 2: Scanning for vulnerabilities..."
trivy image --severity HIGH,CRITICAL "$IMAGE_NAME" > "${IMAGE_NAME//[:\/]/_}-vulnerabilities.txt"
VULN_COUNT=$(trivy image --severity HIGH,CRITICAL --quiet "$IMAGE_NAME" | wc -l)
echo "Found $VULN_COUNT HIGH/CRITICAL vulnerabilities"

# Step 3: Check if image is signed
echo "Step 3: Verifying image signature..."
if cosign verify --key cosign.pub "$IMAGE_NAME" > /dev/null 2>&1; then
    echo "✓ Image is properly signed"
    SIGNED=true
else
    echo "✗ Image is not signed or signature verification failed"
    SIGNED=false
fi

# Step 4: Generate security report
echo "Step 4: Generating security report..."
cat > "${IMAGE_NAME//[:\/]/_}-security-report.txt" << EOL
Supply Chain Security Report
============================
Image: $IMAGE_NAME
Scan Date: $(date)

SBOM: Generated (${IMAGE_NAME//[:\/]/_}-sbom.json)
Vulnerabilities: $VULN_COUNT HIGH/CRITICAL issues found
Signature Status: $SIGNED

Recommendation: 
$(if [ "$VULN_COUNT" -gt 0 ] || [ "$SIGNED" = false ]; then
    echo "⚠️  This image has security concerns. Review vulnerabilities and ensure proper signing."
else
    echo "✅ This image passes basic security checks."
fi)
EOL

echo "Security report generated: ${IMAGE_NAME//[:\/]/_}-security-report.txt"
echo "=== Pipeline Complete ==="
