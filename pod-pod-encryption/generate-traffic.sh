#!/bin/bash

echo "=== Istio mTLS Traffic Generator ==="
echo "Timestamp: $(date)"
echo

# Function for messages
info() { echo "[INFO] $1"; }
error() { echo "[ERROR] $1"; }

# Get client pod
CLIENT_POD=$(kubectl get pod -l app=client -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -z "$CLIENT_POD" ]; then
  error "Client pod not found. Ensure the client pod is running."
  exit 1
fi

info "Using client pod: $CLIENT_POD"
info "Starting traffic generation between frontend and backend services"
echo "Press Ctrl+C to stop"
echo

trap "echo; info 'Traffic generation stopped'; exit 0" SIGINT

while true; do

  kubectl exec $CLIENT_POD -- curl -s http://frontend.default.svc.cluster.local >/dev/null
  if [ $? -eq 0 ]; then
    info "Request sent to frontend service"
  else
    error "Failed to reach frontend service"
  fi

  kubectl exec $CLIENT_POD -- curl -s http://backend.default.svc.cluster.local >/dev/null
  if [ $? -eq 0 ]; then
    info "Request sent to backend service"
  else
    error "Failed to reach backend service"
  fi

  sleep 2
done
