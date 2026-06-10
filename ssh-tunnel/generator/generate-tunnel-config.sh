#!/bin/bash

TUNNEL_NAME="${1:-tunnel}"
OUTPUT_FILE="${2:-}"

TMPDIR=$(mktemp -d)
trap "rm -rf ${TMPDIR}" EXIT

PRIVATE_KEY="${TMPDIR}/id_ed25519"
PUBLIC_KEY="${TMPDIR}/id_ed25519.pub"

ssh-keygen -t ed25519 -f "${PRIVATE_KEY}" -N "" -C "tunnel-${TUNNEL_NAME}"

if [ ! -f "${PRIVATE_KEY}" ] || [ ! -f "${PUBLIC_KEY}" ]; then
    echo "ERROR: Failed to generate SSH keypair" >&2
    exit 1
fi

read -r -d '' CONFIG << EOF || true
{
    "tunnel_id": "${TUNNEL_NAME}",
    "server": {
        "ssh_port": 2222,
        "username": "tunserver",
        "public_key_file": "id_ed25519.pub"
    },
    "client": {
        "ssh_key_base64": "$(base64 -w0 ${PRIVATE_KEY})",
        "public_key": "$(cat ${PUBLIC_KEY})"
    }
}
EOF

if [ -n "${OUTPUT_FILE}" ]; then
    echo "${CONFIG}" > "${OUTPUT_FILE}"
    echo "Config written to: ${OUTPUT_FILE}"
else
    echo "${CONFIG}"
fi
