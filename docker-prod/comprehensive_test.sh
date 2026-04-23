#!/bin/bash
echo "Running comprehensive monitoring test..."
endpoints=("http://localhost:5001" "http://localhost:5002" "http://localhost:8080")
for endpoint in "${endpoints[@]}"; do
    echo "Testing $endpoint"
    for i in {1..20}; do
        curl -s "$endpoint/" > /dev/null
        curl -s "$endpoint/health" > /dev/null
        curl -s "$endpoint/load" > /dev/null
        curl -s "$endpoint/error" > /dev/null
        sleep 0.5
    done
done
echo "Test completed. Check Datadog for metrics and alerts."
