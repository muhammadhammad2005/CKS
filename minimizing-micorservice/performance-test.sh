#!/bin/bash

NAMESPACE="secure-microservices"

echo "========================================"
echo "   MICROSERVICE PERFORMANCE TEST"
echo "========================================"

# Check namespace
if ! kubectl get ns $NAMESPACE > /dev/null 2>&1; then
  echo "[ERROR] Namespace $NAMESPACE not found"
  exit 1
fi

# Check deployments
check_deployment() {
  local name=$1
  if ! kubectl get deploy $name -n $NAMESPACE > /dev/null 2>&1; then
    echo "[ERROR] Deployment $name not found"
    exit 1
  fi
}

check_deployment "minimal-app"
check_deployment "sandboxed-app"

echo ""
echo "=== Regular container performance ==="
kubectl exec -n $NAMESPACE deployment/minimal-app -- python3 -c "
import time
start = time.time()
for i in range(1000000):
    pass
print('Execution time: {:.4f} seconds'.format(time.time() - start))
" || echo "[ERROR] Failed to execute test on minimal-app"

echo ""
echo "=== gVisor sandboxed container performance ==="
kubectl exec -n $NAMESPACE deployment/sandboxed-app -- python3 -c "
import time
start = time.time()
for i in range(1000000):
    pass
print('Execution time: {:.4f} seconds'.format(time.time() - start))
" || echo "[ERROR] Failed to execute test on sandboxed-app"

echo ""
echo "=== Pod resource usage ==="
if kubectl top pods -n $NAMESPACE > /dev/null 2>&1; then
  kubectl top pods -n $NAMESPACE
else
  echo "[WARNING] Metrics server not available"
  echo "Run: minikube addons enable metrics-server"
fi

echo ""
echo "========================================"
echo "        TEST COMPLETED"
echo "========================================"
