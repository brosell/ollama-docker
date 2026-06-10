# SSH Tunnel Docker

This project provides a complete solution for establishing SSH tunnels between a host on your local network and a remote endpoint using Docker containers.

## Features

- ✅ Unique SSH keypair per tunnel pair (Ed25519)
- ✅ Self-contained Docker containers
- ✅ Configurable ports (SSH port + forward ports)
- ✅ JSON-encoded config file for easy sharing
- ✅ Public key authentication only
- ✅ Persistent key storage
- ✅ Tested and verified setup

## Files Overview

```
ssh-tunnel/
├── server/              # SSH server container
├── client/              # SSH client container
├── generator/           # Key and config generation scripts
├── KEYS/                # Optional keypair storage
├── docker-compose.yml   # Full stack configuration
├── docker-compose.client.yml  # Client-only configuration
├── README.md            # This file
├── QUICKSTART.md        # Quick reference guide
├── SECURITY.md          # Security notes
├── test-setup.sh        # Setup verification
├── verify-config.sh     # Config validation
└── example_config.json  # Example configuration
```

## Quick Start

### 1. Generate Key and Configuration

```bash
cd ssh-tunnel/generator
./generate-tunnel-config.sh my-tunnel > ../config.json
```

This creates:
- Unique SSH keypair (`id_ed25519`, `id_ed25519.pub`)
- JSON config file with all connection info

### 2. Extract Client Setup

```bash
SSH_KEY_BASE64=$(jq -r '.client.ssh_key_base64' ../config.json)
```

### 3. Deploy Server (Local Network)

```bash
cd ../
docker-compose up -d ssh-server
```

Server listens on port `2222` by default.

### 4. Deploy Client (Remote Location)

```bash
docker run -d \
  --name ssh-tunnel-client \
  -e REMOTE_ADDR=<your_server_public_ip> \
  -e SSH_KEY_BASE64="${SSH_KEY_BASE64}" \
  -e LOCAL_PORT=8080 \
  -e REMOTE_PORT=8080 \
  --restart unless-stopped \
  ssh-tunnel-client:latest
```

The client establishes a reverse tunnel back to your server.

## Architecture

### SSH Server Container
- Runs `sshd` on configurable port
- Authenticate clients via public key
- Accept connections from remote clients
- Exposes tunnel endpoints

### SSH Client Container
- Connects to server using pre-configured key
- Establishes reverse SSH tunnel
- Forwards remote port to local service
- Auto-reconnects on failure

### Key Generation
- Generates Ed25519 keypairs (secure, compact)
- Creates JSON config with embedded base64-encoded private key
- Single file transfer to remote user

## Usage Workflow

1. **Generate Tunnel**: `./generator/generate-tunnel-config.sh <name> > config.json`
2. **Share Config**: Send `config.json` to remote user
3. **Deploy Server**: `docker-compose up -d ssh-server`
4. **Deploy Client**: Remote user deploys client with config
5. **Access Services**: through the established tunnel

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SSH_SERVER_PORT` | Server SSH listen port | `2222` |
| `REMOTE_ADDR` | Server address (client) | - |
| `SERVER_PORT` | Server SSH port (client) | `2222` |
| `LOCAL_PORT` | Local service port | `8080` |
| `REMOTE_PORT` | Remote exposed port | `8080` |
| `SSH_KEY_BASE64` | Base64-encoded private key | - |

### JSON Config Format

```json
{
  "tunnel_id": "my-tunnel",
  "server": {
    "ssh_port": 2222,
    "username": "tunserver"
  },
  "client": {
    "ssh_key_base64": "LS0tLS1CRU...BASE64...S0tLQo=",
    "public_key": "ssh-ed25519 AAAAC3Nza..."
  }
}
```

## Security

### Key Management
- Generate unique keypair per tunnel
- Keep `id_ed25519` private and secure
- Remove keys after deployment
- Store `config.json` securely

### Authentication
- Public key only (no passwords)
- Ed25519 algorithm (modern, secure)
- Host key verification enabled

### Network
- Minimal attack surface
- No exposed passwords
- Reverse tunnel limits exposure

## Advanced Usage

### Multiple Tunnels

```bash
./generate-tunnel-config.sh tunnel1 > tunnel1.json
./generate-tunnel-config.sh tunnel2 > tunnel2.json
```

### Change SSH Port

Edit `server/ssh_config/sshd_config`:
```
Port 2222  # Change as needed
```

### Manual Key Generation

```bash
ssh-keygen -t ed25519 -f id_ed25519 -N ""
SSH_KEY_BASE64=$(base64 -w0 id_ed25519)
```

### Test Connection

```bash
ssh -i id_ed25519 tunserver@server.ip -p 2222
```

### View Public Key

```bash
jq -r '.client.public_key' config.json
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Connection refused | Check server port, firewall, IP |
| Key authentication failed | Verify SSH_KEY_BASE64 is correct |
| Container won't start | Check environment variables |
| No tunnel established | Verify public key in authorized_keys |
| JSON parse error | Validate with `./verify-config.sh` |

## Cleanup

After successful deployment:

```bash
# Remove private key from generator
rm id_ed25519

# Keep only config.json and public key
mv id_ed25519.pub ../tunnel1.pub
```

## Files Reference

| File | Purpose |
|------|---------|
| `Dockerfile` | Container definition |
| `entrypoint.sh` | Client startup script |
| `sshd_config` | SSH server config |
| `generate-tunnel-config.sh` | Key and config generator |
| `generate-client-cmd.sh` | Docker run command generator |
| `docker-compose.yml` | Full stack compose file |
| `docker-compose.client.yml` | Client-only compose file |

## Security Checklist

- [ ] Remove `id_ed25519` after deployment
- [ ] Store `config.json` securely
- [ ] Use unique keys per tunnel
- [ ] Enable server firewall
- [ ] Monitor SSH logs
- [ ] Rotate keys periodically
- [ ] Don't commit keys to git

## License

MIT License - see LICENSE file for details.
