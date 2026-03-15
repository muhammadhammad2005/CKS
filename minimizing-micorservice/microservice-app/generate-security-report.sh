#!/bin/bash

echo "=== MICROSERVICE SECURITY REPORT ==="
echo "Generated on: $(date)"
echo ""

echo "1. NAMESPACE SECURITY CONFIGURATION:"
kubectl get namespace secure-microservices --show-labels
echo ""

echo "2. POD SECURITY STANDARDS (runtime class + user):"
kubectl get pods -n secure-microservices \
  -o custom-columns="NAME:.metadata.name,RUNTIME:.spec.runtimeClassName,USER:.spec.securityContext.runAsUser,NON-ROOT:.spec.securityContext.runAsNonRoot"
echo ""

echo "3. IMAGE SIZES:"
docker images | grep -E "(microservice-app|REPOSITORY)"
echo ""

echo "4. RESOURCE USAGE:"
kubectl top pods -n secure-microservices 2>/dev/null || echo "Metrics server not available"
echo ""

echo "5. SECURITY CONTEXTS PER POD:"
kubectl get pods -n secure-microservices \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].securityContext}{"\n"}{end}'
echo ""

echo "6. NETWORK POLICIES:"
kubectl get networkpolicy -n secure-microservices
echo ""

echo "=== END OF REPORT ==="
