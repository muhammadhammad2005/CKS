#!/bin/bash

SECRET_NAME="user-credentials"
NEW_PASSWORD=$(openssl rand -base64 32)

echo "Rotating password for secret: $SECRET_NAME"
echo "New password: $NEW_PASSWORD"

# Update the secret
kubectl patch secret $SECRET_NAME -p="{\"data\":{\"password\":\"$(echo -n $NEW_PASSWORD | base64 -w 0)\"}}"

echo "Secret rotation completed"
kubectl get secret $SECRET_NAME -o jsonpath='{.data.password}' | base64 --decode
echo ""
