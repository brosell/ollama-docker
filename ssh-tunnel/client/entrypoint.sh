#!/bin/bash
set -e

SSH_KEY_BASE64="${SSH_KEY_BASE64:-}"
SERVER_ADDRESS="${REMOTE_ADDR:-}"
SERVER_PORT="${SERVER_PORT:-2222}"
LOCAL_PORT="${LOCAL_PORT:-8080}"
REMOTE_PORT="${REMOTE_PORT:-8080}"
KEY_PATH="/home/tunclient/.ssh/id_ed25519"
KNOWN_HOSTS="/home/tunclient/.ssh/known_hosts"

if [ -z "${SSH_KEY_BASE64}" ]; then
    echo "ERROR: SSH_KEY_BASE64 environment variable not set"
    exit 1
fi

if [ -z "${SERVER_ADDRESS}" ]; then
    echo "ERROR: REMOTE_ADDR environment variable not set"
    exit 1
fi

mkdir -p /home/tunclient/.ssh
chmod 700 /home/tunclient/.ssh

echo "${SSH_KEY_BASE64}" | base64 -d > "${KEY_PATH}"
chmod 600 "${KEY_PATH}"

ssh-keyscan -p "${SERVER_PORT}" -H "${SERVER_ADDRESS}" >> "${KNOWN_HOSTS}" 2>/dev/null || true

echo "Connecting to ${SERVER_ADDRESS}:${SERVER_PORT}..."

ssh -o StrictHostKeyChecking=accept-new \
    -o ServerAliveInterval=30 \
    -o ServerAliveCountMax=3 \
    -o ExitOnForwardFailure=yes \
    -N \
    -R "${REMOTE_PORT}:localhost:${LOCAL_PORT}" \
    -i "${KEY_PATH}" \
    tunserver@"${SERVER_ADDRESS}" -p "${SERVER_PORT}"
