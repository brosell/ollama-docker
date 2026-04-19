#!/usr/bin/env bash
# Detects the host IP and writes it to .env for podman-compose.
HOST_IP=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')
if [ -z "$HOST_IP" ]; then
  echo "ERROR: could not detect host IP" >&2
  exit 1
fi
echo "HOST_IP=${HOST_IP}" > .env
echo "Written .env with HOST_IP=${HOST_IP}"
