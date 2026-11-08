# SSH Bastion

Key-only SSH gateway. External users reach Ollama backends over local TCP
forwarding (`ssh -L`); the SSH key *is* the auth — no API key, no TLS.

Backends (`ollama-gpu`, `ollama-amd`, `ollama-cpu`) are bound to `${HOST_IP}`, so
LAN devices reach them directly. The bastion (key-only SSH on host port `2222`)
is the entry point for external users.

```
EXTERNAL (outside)                LAN (on your network)
 OpenAI client                     OpenAI client
 base_url = localhost:11434/v1     base_url = http://HOST_IP:11434/v1
 ssh -L ... relay@HOST_IP  ────>   (direct, no auth)
            tunnel (key-only)
            v                     v
 bastion (sshd, key-only) port 2222
 ollama-gpu:11434  ollama-cpu:11435  ollama-amd:11436
```

| Path         | Who           | Auth      | Reaches backend at           |
|--------------|---------------|-----------|------------------------------|
| External     | Outside LAN   | SSH key   | `ssh -L ... relay@HOST_IP`   |
| LAN (direct) | On your LAN   | none      | `http://HOST_IP:11434/v1`    |

## Layout

```
bastion/config/
├── authorized_keys    # one public key per user (PUBLIC_KEY_FILE)
└── sshd/
    └── sshd_config.d/
        └── bastion.conf   # HARDENING SNIPPET — the source of truth
```

`./bastion/config` is mounted **writable** into the container at `/config` (not
read-only). On startup the `linuxserver/openssh-server` image generates host keys,
`.ssh/`, logs, and a **stock** effective sshd config at `/config/sshd/sshd_config`
(it does NOT read any top-level `sshd_config`). sshd loads that generated file.

**Automation — no manual editing of the generated file.** The image's init script
(`/etc/s6-overlay/s6-rc.d/init-openssh-server-config/run`) auto-enables an
`Include /config/sshd/sshd_config.d/*.conf` directive **at the top** of the
generated config whenever that directory exists. sshd is **first-match-wins**, so
every directive in `bastion.conf` overrides the stock base (e.g. `AllowTcpForwarding
local` beats the stock `AllowTcpForwarding no`). This means:

- Edit **`bastion/config/sshd/sshd_config.d/bastion.conf`** — the single source of
  truth.
- On every restart the image regenerates the stock `sshd/sshd_config` and
  **automatically prepends your snippet**. Nothing to do manually, and it survives
  image updates.
- The generated `sshd/sshd_config` is runtime state → gitignored. The `sshd_config.d/
  ` snippet is committed (it is not secret).

## Setup

1. Set `HOST_IP` in `.env` to your LAN IP (e.g. `192.168.50.85`). See
   `.env.example` / `./gen-env.sh`.
2. Bring up the stack:

   ```bash
   podman-compose --profile bastion --profile gpu --profile cpu up -d
   # add --profile amd for ROCm
   ```

3. Verify the bastion is listening (check the **effective** config in
   `/config/sshd/sshd_config`, not the top-level file):

   ```bash
   podman exec bastion cat /config/sshd/sshd_config | grep -Ei \
     'passwordauthentication|pubkeyauthentication|allowtcpforwarding|forcecommand'
   ```

   Expect: `passwordauthentication no`, `pubkeyauthentication yes`,
   `allowtcpforwarding local`, `forcecommand /sbin/nologin`.

## How the config actually works (important)

The `linuxserver/openssh-server` image does **not** read a top-level `sshd_config`
as sshd's config. On startup it builds a **stock** `/config/sshd/sshd_config` from
its own base image config (which hardcodes `AllowTcpForwarding no` and leaves
`ForceCommand` commented out). To make the bastion's hardening policy take effect,
you edit the snippet **`bastion/config/sshd/sshd_config.d/bastion.conf`** and restart
— the image automatically prepends it via the `Include` hook, and sshd is
first-match-wins, so the snippet wins. No manual editing of the generated file.

- `AllowTcpForwarding local` — enables `-L` forwarding (required for tunnels).
- `ForceCommand /sbin/nologin` — drops the account to a non-interactive shell.
  Note the path is `/sbin/nologin` (busybox) on this image; `/usr/sbin/nologin`
does not exist and would make every login fail outright.
- `PUBLIC_KEY_FILE=/config/authorized_keys` (set in `docker-compose.yml`) tells
  the image to copy your keys from `authorized_keys` into
  `/config/.ssh/authorized_keys`, which is what sshd's `AuthorizedKeysFile`
  actually reads.

## Adding a user

1. Create a keypair (once per user, on their machine). Ed25519 is preferred:

   ```bash
   ssh-keygen -t ed25519 -C userA@example.com
   ```

   Leave the passphrase empty for unattended tunnels, or set one if they'll keep
   the key in an ssh-agent. This produces a private key (`id_ed25519`) they keep
   secret and a public key (`id_ed25519.pub`) that goes on the bastion.

2. Give you their **public** key (`~/.ssh/id_ed25519.pub`). Never ask for the
   private key.
3. Append one line to `bastion/config/authorized_keys`:

   ```
   ssh-ed25519 AAAA... userA@example.com
   ```

   The custom-init script (`custom-cont-init.d/01-sync-authorized-keys.sh`) copies
   these into `/config/.ssh/authorized_keys` (the file sshd actually reads) on
   restart — by **overwriting** it from the source, so additions AND removals
   take effect. (The image's own append-based copy is broken and is NOT relied
   on for syncing.)

4. Restart: the keys and any config edits are re-read.

   ```bash
   podman-compose --profile bastion restart bastion
   ```

   Verify the effective file matches the source:

   ```bash
   podman exec bastion cat /config/.ssh/authorized_keys
   ```

**Lock a key to specific backends (optional):** prefix the line with
`permitopen`:

```
permitopen="ollama-gpu:11434" ssh-ed25519 AAAA... userA@example.com
permitopen="ollama-gpu:11434,ollama-cpu:11435" ssh-ed25519 AAAA... userB@example.com
```

Then restart the bastion.

## Using it

**Important — this is a forward-only bastion.** `relay` has no shell:
`ForceCommand /sbin/nologin` runs `This account is not available` and exits
immediately. That's fine for tunneling — the `LocalForward` is a separate
channel that stays up regardless of the (nonexistent) shell — but you must
make ssh **not wait for a shell**, and fail fast if the tunnel can't come up.
Two `~/.ssh/config` options do exactly that (no `-N` needed):

```sshconfig
Host skynet-bastion
  HostName 192.168.50.190
  Port 2222
  user relay
  IdentityFile ~/.ssh/id_ed25519
  LocalForward 11434 ollama-amd:11434
  ExitOnForwardFailure yes   # if the tunnel can't be established, exit at once
  RequestTTY no              # don't grab a shell/tty (relay has none)
```

- `ExitOnForwardFailure yes` — if the `LocalForward` fails (e.g. backend down),
  ssh exits immediately instead of dropping you at the `nologin` prompt.
- `RequestTTY no` — suppresses the `Pseudo-terminal will not be allocated`
  line, since `relay` has no real shell.

**External user** — start a tunnel, keep it open:

```bash
ssh -L 11434:ollama-gpu:11434 -p 2222 relay@YOUR_HOST_IP
```

```sshconfig
# or, with the config block above, just:
ssh skynet-bastion -N
```

```bash
curl http://localhost:11434/v1/models
```

Other backends:

```bash
ssh -L 11435:ollama-cpu:11434   -p 2222 relay@YOUR_HOST_IP   # ollama-cpu
ssh -L 11436:ollama-amd:11434   -p 2222 relay@YOUR_HOST_IP   # ollama-amd
```

**LAN user** — nothing to start. Point the client at the backend:

```
base_url = http://HOST_IP:11434/v1   # ollama-gpu
base_url = http://HOST_IP:11435/v1   # ollama-cpu
base_url = http://HOST_IP:11436/v1   # ollama-amd
```

This is **unauthenticated** — the SSH key only protects the external path.

## Removing a user

Delete their line from `authorized_keys` and restart:

```bash
podman-compose --profile bastion restart bastion
```

The custom-init script **overwrites** `/config/.ssh/authorized_keys` from the
source on restart, so the removed key is GONE from the effective file — not left
behind by the image's old append-based copy. Next connection is refused. Existing
sessions stay open until they end or the bastion restarts (`ClientAliveInterval`
in `sshd_config`).

The same applies to **commenting out** a key (`# ` prefix): on restart it is no
longer an active key in the effective file, so it can no longer authenticate.

## Security model

| Aspect       | External (bastion)                    | LAN (direct)                     |
|--------------|---------------------------------------|----------------------------------|
| Entry point  | SSH bastion, host port `2222`         | Backend port bound to `${HOST_IP}`|
| Auth         | Public/private key only               | none                             |
| Encryption   | SSH — no certificate                  | Plaintext on the LAN             |
| Attack surface | One host port, key-only             | LAN interface only               |
| Isolation    | `ForceCommand nologin` + `AllowTcpForwarding local` | —              |
| Audit        | `LogLevel VERBOSE` logs key fingerprint per login | —                |

**Does NOT do:**

- **No LAN auth.** LAN devices reach backends directly, no key. Gate LAN access
  with a proxy (e.g. LiteLLM), or remove the `${HOST_IP}` bindings and route
  everyone through the bastion.
- **No per-user API key.** The SSH key is the whole auth story; rotate on leak.
- **No per-user quota.** A user can exhaust the machine's unified RAM.
- **No per-request audit.** sshd logs logins, not API calls.
- **No rate limiting.** Add host `fail2ban` or front Ollama with a proxy.

## Troubleshooting

- **`kex_exchange_identification: read: Connection reset by peer`** — the
  bastion container can't start sshd. `/config` must be **writable** (not
  `:ro`); if it's read-only the image can't create host keys and sshd dies on
  startup. Check `podman logs bastion`.
- **`Permission denied (publickey)`** — the key isn't in the file sshd reads
  (`/config/.ssh/authorized_keys`), or the private key doesn't match. Confirm
  with `ssh-keygen -y -f ~/.ssh/id_ed25519` vs the `authorized_keys` line, and
  that `PUBLIC_KEY_FILE` is set and the bastion was restarted.
- **`administratively prohibited: open failed`** (tunnel) — `AllowTcpForwarding`
  is still `no` in the effective config. Your snippet isn't being prepended:
  check `bastion/config/sshd/sshd_config.d/bastion.conf` exists and matches
  `AllowTcpForwarding local`, then restart.
- **Tunnel connects but `curl localhost:11434` fails** — the `-L` listener binds
  to IPv4 `127.0.0.1` only and lives only while the `ssh -L` process runs, in
  that process's network namespace. Use `127.0.0.1`, not `localhost` (which may
  resolve to IPv6 `::1`), and run the client on the same machine/session as the
  tunnel.
- **Can't connect (external)** — key on the right line, no stray characters,
  bastion restarted.
- **Can't reach backend (LAN)** — `HOST_IP` in `.env` matches the LAN IP; same
  subnet.
- **Tunnel connects but `/v1/models` hangs** — backend not running or wrong
  name. Check `podman ps`; confirm the container is on the `ollama-docker`
  network.
- **`Connection refused` on 2222** — bastion isn't up:
  `podman-compose --profile bastion logs bastion`.
