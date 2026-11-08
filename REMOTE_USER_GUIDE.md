# Remote SSH User Guide

This bastion is **key-only**: the SSH key *is* your authentication. There is no
password, no API key, and no TLS cert to manage. You connect by opening a local
TCP tunnel to an Ollama backend, then point your OpenAI-compatible client at
`localhost`.

Prerequisites on your machine:

- An SSH client (OpenSSH, or any compatible client).
- A keypair, or permission to use an existing one.
- Network reachability to the bastion host:port (default `HOST:2222`).

---

## Quick start

Once your public key is registered by the admin:

```bash
# 1. Open a tunnel (keep this running)
ssh -L 11434:ollama-gpu:11434 -p 2222 relay@<BASTION_HOST>

# 2. In ANOTHER terminal, verify
curl http://127.0.0.1:11434/v1/models

# 3. Point your client at the tunnel
#    base_url = http://127.0.0.1:11434/v1
```

That's it. First-time setup (generating your key, getting it onto the bastion) is
in the full walkthrough below.

---

## Full walkthrough

## 1. Generate a keypair (once, on your machine)

Ed25519 is preferred. Leave the passphrase empty for unattended/automated
tunnels; set one if you'll keep the key in an ssh-agent.

```bash
ssh-keygen -t ed25519 -C you@example.com
```

This creates:

- `~/.ssh/id_ed25519`      — private key. **Keep secret. Never share this.**
- `~/.ssh/id_ed25519.pub`  — public key. **This is what you give the admin.**

If you already have a key you use for other servers, you can reuse it — just
send the admin your `*.pub` line.

## 2. Send the admin your public key

Send **only** the public key (one line, from `~/.ssh/id_ed25519.pub`):

```bash
cat ~/.ssh/id_ed25519.pub
```

The admin adds it to the bastion's `authorized_keys` and restarts the service.
You cannot connect until they confirm this is done.

## 3. Verify connectivity

Once the admin confirms your key is registered, test the SSH path (no tunnel yet):

```bash
ssh -o ConnectTimeout=10 -p 2222 relay@<BASTION_HOST>
```

Expected: the account has no shell, so you'll see something like
`This account is not available` and the connection closes. **That is correct** —
it confirms your key was accepted. A `Permission denied (publickey)` means your
key isn't registered yet; ask the admin.

## 4. Open a tunnel

Pick the backend you need and forward its port to a local port of your choice.

| Backend   | Remote port | Typical local port |
|-----------|-------------|--------------------|
| `ollama-gpu`  | 11434 | 11434 |
| `ollama-cpu`  | 11434 | 11435 |
| `ollama-amd`  | 11434 | 11436 |

Minimal one-liner (GPU backend → local 11434):

```bash
ssh -L 11434:ollama-gpu:11434 -p 2222 relay@<BASTION_HOST>
```

This command blocks and keeps the tunnel open. Leave it running. To use another
backend, open another terminal with the matching local port.

### Optional: an SSH config entry

Adding this to `~/.ssh/config` lets you drop the flags and just run `ssh skynet -N`:

```sshconfig
Host skynet
  HostName <BASTION_HOST>
  Port 2222
  user relay
  IdentityFile ~/.ssh/id_ed25519
  LocalForward 11434 ollama-gpu:11434
  ExitOnForwardFailure yes   # exit immediately if the tunnel can't come up
  RequestTTY no              # relay has no shell; don't wait for one
```

Then:

```bash
ssh skynet -N
```

- `ExitOnForwardFailure yes` — if the backend is down or forwarding is refused,
  ssh exits at once instead of dropping you at the `nologin` prompt.
- `RequestTTY no` — suppresses the "no tty" noise.
- `-N` — no remote command; this connection exists only for the tunnel.

## 5. Confirm the tunnel works

In a **separate** terminal (the tunnel from step 4 must stay running):

```bash
curl http://127.0.0.1:11434/v1/models
```

You should get a JSON model list. Use `127.0.0.1`, not `localhost` — the tunnel
listener binds IPv4 only, and `localhost` may resolve to IPv6 `::1`.

## 6. Point your client at the tunnel

Any OpenAI-compatible client works. Set the base URL to the local tunnel port:

```
base_url = http://127.0.0.1:11434/v1
```

There is no API key to enter (or send any placeholder — auth is the SSH tunnel).

---

## Accessing other backends

Open additional tunnels on different local ports, then point each client at its
own port:

```bash
ssh -L 11435:ollama-cpu:11434 -p 2222 relay@<BASTION_HOST>   # CPU backend  -> 127.0.0.1:11435
ssh -L 11436:ollama-amd:11434 -p 2222 relay@<BASTION_HOST>   # AMD backend  -> 127.0.0.1:11436
```

If your key is locked to specific backends (`permitopen` in `authorized_keys`),
only the permitted `host:port` forward will succeed; others return
`administratively prohibited: open failed`.

---

## Keeping the tunnel alive

- The tunnel dies whenever the `ssh` process exits. For long-running/automated
  use, run it under a process manager, `tmux`/`screen`, or a systemd user unit.
- Add keepalive so a idle connection isn't dropped:

  ```sshconfig
  ServerAliveInterval 30
  ServerAliveCountMax 3
  ```

- To auto-reconnect, wrap the `ssh` command in a restart loop or use a tool like
  `autossh`:

  ```bash
  autossh -M 0 -L 11434:ollama-gpu:11434 -p 2222 relay@<BASTION_HOST>
  ```

---

## Removing access (your side)

- Delete your private key file (`~/.ssh/id_ed25519`) and any `Host` entry from
  `~/.ssh/config`.
- Ask the admin to remove your line from the bastion's `authorized_keys`. Your
  next connection is then refused; existing sessions close on the admin's next
  bastion restart.

---

## Troubleshooting

| Symptom | Cause / fix |
|---------|-------------|
| `Permission denied (publickey)` | Key not registered, or wrong key. Confirm the admin added your `*.pub`, that you reference the right `IdentityFile`, and retry. |
| `Connection refused` on `2222` | Bastion is down or the host/port is wrong. Verify reachability with the admin. |
| `Connection reset by peer` | Bastion sshd failed to start server-side — contact the admin. |
| `administratively prohibited: open failed` | Your key is `permitopen`-locked and can't forward that backend, or TCP forwarding is disabled. Use a permitted backend. |
| SSH connects but `curl` fails | You used `localhost` — switch to `127.0.0.1`. Or the tunnel listener isn't up: confirm the `ssh -L` process is still running. |
| `/v1/models` hangs | Backend container isn't running or the remote name is wrong — ask the admin to check `podman ps`. |
| Tunnel drops after a while | Idle timeout. Add `ServerAliveInterval` or use `autossh`. |

---

## Security notes

- Your **private key never leaves your machine**. The admin only ever sees your
  public key. If a private key is lost or suspected compromised, tell the admin
  to remove your line and generate a new keypair.
- This is a **forward-only** gateway: `relay` has no shell. You cannot run
  commands on the bastion — only tunnel to the permitted backends.
- The SSH tunnel is encrypted. Note that the direct-LAN path to the same
  backends is **unauthenticated** — that's an admin concern, not yours.
