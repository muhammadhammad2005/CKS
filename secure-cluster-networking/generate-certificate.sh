#!/bin/bash

echo "=== TLS Certificate Generator ==="
echo "Timestamp: $(date)"
echo

# Check if openssl exists
if ! command -v openssl &> /dev/null
then
    echo "ERROR: OpenSSL is not installed."
    exit 1
fi

echo "[1/3] Generating private key..."
openssl genrsa -out tls.key 2048

if [ $? -ne 0 ]; then
    echo "Failed to generate private key"
    exit 1
fi

echo "[2/3] Creating certificate signing request..."
openssl req -new \
  -key tls.key \
  -out tls.csr \
  -subj "/CN=secure-app.local/O=secure-app"

if [ $? -ne 0 ]; then
    echo "Failed to create CSR"
    exit 1
fi

echo "[3/3] Generating self-signed certificate..."
openssl x509 -req \
  -in tls.csr \
  -signkey tls.key \
  -out tls.crt \
  -days 365

if [ $? -ne 0 ]; then
    echo "Certificate generation failed"
    exit 1
fi

echo
echo "TLS Certificate Successfully Generated"
echo "Files created:"
echo " - tls.key"
echo " - tls.csr"
echo " - tls.crt"
