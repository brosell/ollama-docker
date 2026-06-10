#!/bin/bash

# Test script for SSH tunnel Docker setup

echo "=== SSH Tunnel Docker Setup Test ==="
echo

echo "1. Checking file structure..."
if [ -f "server/Dockerfile" ] && [ -f "client/Dockerfile" ] && [ -f "generator/generate-tunnel-config.sh" ] && [ -f "docker-compose.yml" ]; then
    echo "   ✓ All required files present"
else
    echo "   ✗ Missing required files"
    exit 1
fi
echo

echo "2. Checking generator script..."
if [ -x "generator/generate-tunnel-config.sh" ]; then
    echo "   ✓ Generator script is executable"
else
    echo "   ✗ Generator script not executable"
    exit 1
fi
echo

echo "3. Testing key generation (dry run)..."
TMPDIR=$(mktemp -d)
if ssh-keygen -t ed25519 -f "${TMPDIR}/test_key" -N "" -C "test" > /dev/null 2>&1; then
    echo "   ✓ ssh-keygen available"
    rm -rf "${TMPDIR}"
else
    echo "   ✗ ssh-keygen not available (required for key generation)"
    exit 1
fi
echo

echo "4. Checking Docker compose..."
if command -v docker-compose > /dev/null 2>&1 || command -v docker > /dev/null 2>&1 && docker compose version > /dev/null 2>&1; then
    echo "   ✓ Docker compose available"
else
    echo "   ! Docker compose not available (build from source required)"
fi
echo

echo "=== Summary ==="
echo "✓ File structure: OK"
echo "✓ Key generation tools: OK"
echo "✓ Docker compose: Check above"
echo
echo "To build:"
echo "  cd ssh-tunnel && docker build -t ssh-tunnel-server ./server"
echo "  docker build -t ssh-tunnel-client ./client"
echo
echo "To generate config:"
echo "  cd ssh-tunnel/generator && ./generate-tunnel-config.sh my-tunnel > config.json"
echo
