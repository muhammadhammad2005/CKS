#!/bin/bash
set -e

IMAGE_NAME="localhost:5000/secure-app"
IMAGE_TAG="v1.0.0"
FULL_IMAGE="$IMAGE_NAME:$IMAGE_TAG"

echo "=== Secure Container Pipeline ==="

echo "1. Tagging image..."
docker tag node:16-alpine "$FULL_IMAGE"

echo "2. Generating SBOM..."
syft "$FULL_IMAGE" -o json > "$IMAGE_TAG-sbom.json"
echo "   Packages found: $(cat $IMAGE_TAG-sbom.json | jq '.artifacts | length')"

echo "3. Scanning for vulnerabilities..."
trivy image --exit-code 0 --severity HIGH,CRITICAL "$FULL_IMAGE"

echo "4. Pushing image..."
docker push "$FULL_IMAGE"

echo "5. Signing image..."
cosign sign --key cosign.key --allow-insecure-registry "$FULL_IMAGE"

echo "6. Attaching SBOM..."
cosign attach sbom --sbom "$IMAGE_TAG-sbom.json" --allow-insecure-registry "$FULL_IMAGE"

echo "=== Pipeline completed successfully ==="
