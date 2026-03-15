#!/bin/bash

echo "=== Regular container performance ==="
kubectl exec -n secure-microservices deployment/minimal-app -- python3 -c "
import time
start = time.time()
for i in range(10000):
    pass
print('Execution time: {:.4f} seconds'.format(time.time() - start))
"

echo ""
echo "=== gVisor sandboxed container performance ==="
kubectl exec -n secure-microservices deployment/sandboxed-app -- python3 -c "
import time
start = time.time()
for i in range(10000):
    pass
print('Execution time: {:.4f} seconds'.format(time.time() - start))
"

echo ""
echo "=== Pod resource usage ==="
kubectl top pods -n secure-microservices 2>/dev/null || echo "Metrics server not available — run: minikube addons enable metrics-server"
