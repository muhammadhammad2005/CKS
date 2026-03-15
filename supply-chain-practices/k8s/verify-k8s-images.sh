#!/bin/bash
NAMESPACE=${1:-default}
echo "=== Verifying images in namespace: $NAMESPACE ==="

kubectl get pods -n "$NAMESPACE" \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].image}{"\n"}{end}' | \
while read pod_name images; do
    echo "Pod: $pod_name"
    for image in $images; do
        echo "  Image: $image"
        if [[ $image == localhost:5000/* ]]; then
            if cosign verify --key ~/lab14-keys/cosign.pub \
               --allow-insecure-registry "$image" >/dev/null 2>&1; then
                echo "    ✓ Signature VERIFIED"
            else
                echo "    ✗ Signature FAILED or missing"
            fi
        else
            echo "    - External image (skipped)"
        fi
    done
    echo ""
done
