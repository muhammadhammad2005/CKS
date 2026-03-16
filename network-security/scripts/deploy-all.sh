#!/bin/bash
set -e

echo "=== Lab 20: Advanced Network Security Deployment ==="
echo "Date: $(date)"
echo ""

echo "--- Step 1: Starting Minikube with Calico CNI ---"
minikube start --network-plugin=cni --cni=calico --driver=docker
kubectl wait --for=condition=Ready pods -n kube-system -l k8s-app=calico-node --timeout=180s
echo "Calico ready"

echo ""
echo "--- Step 2: Creating Namespaces ---"
kubectl apply -f manifests/namespaces/namespaces.yaml
kubectl get namespaces | grep -E "(frontend|backend|database|monitoring|attacker)"

echo ""
echo "--- Step 3: Deploying Applications ---"
kubectl apply -f manifests/applications/frontend.yaml
kubectl apply -f manifests/applications/backend.yaml
kubectl apply -f manifests/applications/database.yaml

kubectl rollout status deployment/frontend-app -n frontend
kubectl rollout status deployment/backend-app -n backend
kubectl rollout status deployment/database-app -n database

echo ""
echo "--- Step 4: Applying Network Policies ---"
kubectl apply -f manifests/network-policies/database-policies.yaml
kubectl apply -f manifests/network-policies/backend-policies.yaml
kubectl apply -f manifests/network-policies/frontend-policies.yaml
kubectl get networkpolicies -A

echo ""
echo "--- Step 5: Deploying Monitoring ---"
kubectl apply -f manifests/monitoring/network-monitor.yaml
kubectl wait --for=condition=Ready pod/network-monitor -n monitoring --timeout=120s

echo ""
echo "--- Step 6: Deploying Attacker Pod ---"
kubectl apply -f manifests/attacker/attacker-pod.yaml
kubectl wait --for=condition=Ready pod/attacker-pod -n attacker --timeout=120s

echo ""
echo "=== Deployment Complete ==="
kubectl get pods -A | grep -E "(frontend|backend|database|monitoring|attacker)"
