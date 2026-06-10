# Generated SSH Tunnel Configuration

This directory contains the output of `generate-tunnel-config.sh`.

**SECURITY WARNING**: Keep this file and the `client_config.json` private!
These files contain your SSH private key.

## Files

- `config.json`: Full configuration with both server and client info
- `id_ed25519`: SSH private key (do not share!)
- `id_ed25519.pub`: SSH public key (safe to share)
- `client_config.json`: Client-only config

## Usage

1. Copy `config.json` to remote location
2. Extract `client.ssh_key_base64` value
3. Deploy client container with that key

## Cleanup

After successfully deploying the client, delete unnecessary files:

```bash
rm id_ed25519 client_config.json
```
