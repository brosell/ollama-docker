# SSH Key Pairs Generated for SSH Tunnel

Each directory contains a unique keypair for a specific tunnel.

## Key Management

- Keys are generated once per tunnel
- Store keys securely, never commit to git
- Regenerate if security is compromised

## Directory Structure

Each subdirectory (e.g., `tunnel-001/`) contains:

```
tunnel-001/
├── id_ed25519      # Private key (secret!)
├── id_ed25519.pub  # Public key (share with server)
└── README.md       # Tunnel-specific notes
```

## Rotating Keys

To rotate keys for an existing tunnel:

1. Generate new keypair in temporary location
2. Copy public key to server's `authorized_keys`
3. Update client with new private key
4. Restart client container
5. Remove old key from server

## Backups

Backup keys securely (e.g., password manager, encrypted storage).

**DO NOT** backup in this repository.
