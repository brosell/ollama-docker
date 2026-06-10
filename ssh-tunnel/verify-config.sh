#!/bin/bash
# Verify JSON config validity

CONFIG_FILE="${1:-config.json}"

if [ ! -f "${CONFIG_FILE}" ]; then
    echo "Config file not found: ${CONFIG_FILE}"
    exit 1
fi

echo "Validating ${CONFIG_FILE}..."

# Check JSON syntax
if jq empty "${CONFIG_FILE}" 2>/dev/null; then
    echo "✓ JSON syntax valid"
else
    echo "✗ Invalid JSON"
    exit 1
fi

# Check required fields
REQUIRED_FIELDS=("tunnel_id" "server.ssh_port" "server.username" "client.ssh_key_base64" "client.public_key")
for field in "${REQUIRED_FIELDS[@]}"; do
    if jq -e ".${field}" "${CONFIG_FILE}" > /dev/null 2>&1; then
        echo "✓ ${field} present"
    else
        echo "✗ Missing ${field}"
        exit 1
    fi
done

echo ""
echo "Config validation passed!"
echo "Tunnel ID: $(jq -r '.tunnel_id' ${CONFIG_FILE})"
echo "Server port: $(jq -r '.server.ssh_port' ${CONFIG_FILE})"

exit 0
