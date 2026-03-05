#!/bin/bash
IMAGE=$1
PUBLIC_KEY_PATH=$2

# Verify the image signature using cosign
cosign verify --key "$PUBLIC_KEY_PATH" "$IMAGE" > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "Image $IMAGE is properly signed"
    exit 0
else
    echo "Image $IMAGE signature verification failed"
    exit 1
fi
