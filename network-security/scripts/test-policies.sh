#!/bin/bash

echo "============================================"
echo "     NETWORK POLICY VALIDATION TESTS"
echo "============================================"
echo "Date: $(date)"
echo ""

FRONTEND_POD=$(kubectl get pods -n frontend -l app=frontend -o jsonpath='{.items[0].metadata.name}')
BACKEND_POD=$(kubectl get pods -n backend -l app=backend -o jsonpath='{.items[0].metadata.name}')
BACKEND_IP=$(kubectl get service backend-service -n backend -o jsonpath='{.spec.clusterIP}')
DATABASE_IP=$(kubectl get service database-service -n database -o jsonpath='{.spec.clusterIP}')
FRONTEND_IP=$(kubectl get service frontend-service -n frontend -o jsonpath='{.spec.clusterIP}')

echo "Target IPs:"
echo "  Frontend:  $FRONTEND_IP"
echo "  Backend:   $BACKEND_IP"
echo "  Database:  $DATABASE_IP"
echo ""

PASS=0
FAIL=0

run_test() {
  local desc=$1
  local expected=$2
  local cmd=$3
  echo -n "$desc: "
  eval "$cmd" > /dev/null 2>&1
  local result=$?
  if [ "$expected" = "pass" ] && [ $result -eq 0 ]; then
    echo "PASS ✓"
    PASS=$((PASS+1))
  elif [ "$expected" = "block" ] && [ $result -ne 0 ]; then
    echo "BLOCKED ✓"
    PASS=$((PASS+1))
  else
    echo "UNEXPECTED RESULT ✗"
    FAIL=$((FAIL+1))
  fi
}

echo "--- Legitimate Traffic Tests ---"
run_test "Frontend -> Backend   (expect PASS) " "pass" \
  "kubectl exec -n frontend $FRONTEND_POD -- sh -c 'wget -qO- --timeout=5 http://$BACKEND_IP > /dev/null'"

run_test "Backend  -> Database  (expect PASS) " "pass" \
  "kubectl exec -n backend $BACKEND_POD -- sh -c 'nc -w 3 -z $DATABASE_IP 3306'"

echo ""
echo "--- Blocked Traffic Tests ---"
run_test "Frontend -> Database  (expect BLOCK)" "block" \
  "kubectl exec -n frontend $FRONTEND_POD -- sh -c 'nc -w 3 $DATABASE_IP 3306'"

run_test "Backend  -> Frontend  (expect BLOCK)" "block" \
  "kubectl exec -n backend $BACKEND_POD -- sh -c 'nc -w 3 $FRONTEND_IP 80'"

run_test "Attacker -> Database  (expect BLOCK)" "block" \
  "kubectl exec -n attacker attacker-pod -- sh -c 'nc -w 3 $DATABASE_IP 3306'"

run_test "Attacker -> Backend   (expect BLOCK)" "block" \
  "kubectl exec -n attacker attacker-pod -- sh -c 'wget -qO- --timeout=5 http://$BACKEND_IP > /dev/null'"

run_test "Attacker -> Frontend  (expect BLOCK)" "block" \
  "kubectl exec -n attacker attacker-pod -- sh -c 'wget -qO- --timeout=5 http://$FRONTEND_IP > /dev/null'"

echo ""
echo "============================================"
echo "RESULTS: $PASS passed, $FAIL failed"
echo "============================================"
