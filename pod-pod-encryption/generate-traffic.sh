#!/bin/bash
CLIENT_POD=$(kubectl get pod -l app=client -o jsonpath='{.items[0].metadata.name}')
while true; do
  kubectl exec -it $CLIENT_POD -- curl -s http://frontend.default.svc.cluster.local > /dev/null
  kubectl exec -it $CLIENT_POD -- curl -s http://backend.default.svc.cluster.local > /dev/null
  sleep 2
done
