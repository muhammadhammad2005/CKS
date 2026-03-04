#!/bin/bash

echo "Monitoring secret access patterns..."

# List all secrets and their age
echo "=== Current Secrets ==="
kubectl get secrets -o custom-columns=NAME:.metadata.name,AGE:.metadata.creationTimestamp

# Check which pods are using secrets
echo "=== Pods using secrets ==="
kubectl get pods -o yaml | grep -A 5 -B 5 secretKeyRef

# List service accounts with secret access
echo "=== Service accounts with secret access ==="
kubectl get rolebindings -o yaml | grep -A 10 -B 5 secrets

echo "Monitoring completed"
