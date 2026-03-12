#!/bin/bash

echo "=== Kubernetes Secret Monitoring Tool ==="
echo "Timestamp: $(date)"
echo

info() { echo "[INFO] $1"; }

# Check kubectl availability
if ! command -v kubectl &> /dev/null
then
    echo "ERROR: kubectl is not installed."
    exit 1
fi

echo "=== Current Secrets ==="
kubectl get secrets --all-namespaces \
-o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,TYPE:.type,CREATED:.metadata.creationTimestamp"

echo
echo "=== Pods Referencing Secrets (Environment Variables) ==="
kubectl get pods --all-namespaces -o yaml | grep -E "namespace:|name:|secretKeyRef" -A2

echo
echo "=== Pods Using Secrets as Volumes ==="
kubectl get pods --all-namespaces -o yaml | grep -E "secretName"

echo
echo "=== RBAC Roles Accessing Secrets ==="
kubectl get roles,clusterroles --all-namespaces -o yaml | grep -A5 "resources:.*secrets"

echo
echo "=== Secret Monitoring Completed ==="
