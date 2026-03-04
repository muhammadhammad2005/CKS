#!/bin/bash

echo "Scanning for potential secret leaks..."

# Check for secrets in environment variables
echo "=== Checking environment variables ==="
kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{range .spec.containers[*]}{.env[*].name}{": "}{.env[*].value}{"\n"}{end}{"\n"}{end}' | grep -i -E "(password|secret|key|token)" || echo "No plain text secrets found in env vars"

# Check for secrets in pod specifications
echo "=== Checking pod specifications ==="
kubectl get pods -o yaml | grep -i -E "(password|secret|key|token):" | grep -v "secretKeyRef" || echo "No plain text secrets found in pod specs"

echo "Secret scan completed"
