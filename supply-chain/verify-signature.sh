#!/bin/bash

echo "=== Container Image Signature Verification ==="

IMAGE=$1
PUBLIC_KEY_PATH=$2

success() { echo "[SUCCESS] $1"; }
error() { echo "[ERROR] $1"; }

# Validate arguments
if [ -z "$IMAGE" ] || [ -z "$PUBLIC_KEY_PATH" ]; then
    error "Usage: ./verify-signature.sh <image> <public-key>"
    exit 1
fi

# Check if cosign is installed
if ! command -v cosign &> /dev/null
then
    error "Cosign is not installed. Please install cosign first."
    exit 1
fi

# Check if public key exists
if [ ! -f "$PUBLIC_KEY_PATH" ]; then
    error "Public key not found at $PUBLIC_KEY_PATH"
    exit 1
fi

echo "Verifying signature for image: $IMAGE"

cosign verify --key "$PUBLIC_KEY_PATH" "$IMAGE" > /dev/null 2>&1

if [ $? -eq 0 ]; then
    success "Image signature verified successfully"
    exit 0
else
    error "Image signature verification failed"
    exit 1
fi
