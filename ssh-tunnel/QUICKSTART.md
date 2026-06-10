# SSH Tunnel Docker - Quick Reference

## Directory Structure

```
ssh-tunnel/
├── server/              # SSH server container
│   ├── Dockerfile
│   └── ssh_config/
│       └── sshd_config
├── client/              # SSH client container
│   ├── Dockerfile
│   └── entrypoint.sh
├── generator/           # Key/config generation scripts
│   ├── generate-tunnel-config.sh
│   └── generate-client-cmd.sh
├── KEYS/                # Store keypairs (optional)
├── docker-compose.yml   # Server and client services
├── docker-compose.client.yml  # Client-only compose file
├── README.md            # Full documentation
├── SECURITY.md          # Security notes
├── example_config.json  # Example config format
├── test-setup.sh        # Setup verification script
└── .gitignore
```

## Generation Workflow

### 1. Create Key and Config

```bash
cd generator
./generate-tunnel-config.sh my-tunnel > config.json
# Or: ./generate-tunnel-config.sh my-tunnel tunnel_keys/
```

### 2. Extract Client Key

```bash
SSH_KEY_BASE64=$(jq -r '.client.ssh_key_base64' config.json)
```

### 3. Start Server

```bash
cd ..
docker-compose up -d ssh-server
```

### 4. Deploy Client

```bash
docker run -d \
  --name ssh-tunnel-client \
  -e REMOTE_ADDR=your.server.ip \
  -e SSH_KEY_BASE64="${SSH_KEY_BASE64}" \
  -e LOCAL_PORT=8080 \
  -e REMOTE_PORT=8080 \
  --restart unless-stopped \
  ssh-tunnel-client:latest
```

## Files to Keep

| File | Location | Keep? | Reason |
|------|----------|-------|--------|
| `config.json` | Root | Yes | Need for client setup |
| `id_ed25519` | Generator dir | No | Private key, remove after use |
| `id_ed25519.pub` | Generator dir | Yes | Keep for reference |
| `server/` files | Docker build | Yes | Container definitions |
| `client/` files | Docker build | Yes | Container definitions |

## Common Tasks

### Change SSH Port

Edit `server/ssh_config/sshd_config`:
```
Port 2222  # Change to desired port
```

### Multiple Tunnels

```bash
./generate-tunnel-config.sh tunnel1 > tunnel1.json
./generate-tunnel-config.sh tunnel2 > tunnel2.json
```

### View Public Key

```bash
jq -r '.client.public_key' config.json
```

### Test Connection

```bash
# From remote machine
ssh -i id_ed25519 tunserver@your.server.ip -p 2222
```

## Troubleshooting

**Client can't connect:**
- Check firewall allows port 2222
- Verify SSH_KEY_BASE64 is correct (no truncation)
- Ensure public key added to server's authorized_keys

**Container won't start:**
- Verify Docker is running
- Check environment variables are set
- Review logs: `docker logs ssh-tunnel-client`

**Key errors:**
- Ensure Ed25519 key format
- Check permissions: private key should be 600
- Don't include header/trailer in base64

## Security Checklist

- [ ] Remove `id_ed25519` after client deployment
- [ ] Store `config.json` securely
- [ ] Use unique keypair per tunnel
- [ ] Enable server firewall
- [ ] Regular key rotation
- [ ] Monitor SSH logs
