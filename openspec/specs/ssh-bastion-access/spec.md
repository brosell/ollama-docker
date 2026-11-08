# ssh-bastion-access Specification

## Purpose

The ssh-bastion-access capability defines the SSH bastion as the sole public entry point for external users to reach the Ollama backends. It uses key-only authentication and local TCP forwarding so that the SSH key itself is the only access control — there is no API key and no TLS. It captures how users are added and removed, how forwarding is scoped, and the hardening invariants that keep the gateway safe.

## Requirements

### Requirement: Bastion permits key-only authentication only
The bastion SHALL run an SSH server that accepts public-key login and SHALL reject all password-based authentication.

#### Scenario: Password login is refused
- **WHEN** a client attempts to authenticate with a password
- **THEN** the server refuses it because `PasswordAuthentication no` is set
- **AND** `PubkeyAuthentication yes` is the only accepted method

#### Scenario: Root login is refused
- **WHEN** a client attempts to log in as `root`
- **THEN** the connection is refused because `PermitRootLogin no` is set

### Requirement: Users authenticate with a per-user public key
Access SHALL be granted by editing `bastion/config/authorized_keys` (the single
source of truth for keys) and restarting the bastion. On each start, the image
MUST make `/config/.ssh/authorized_keys` — the file sshd reads per its
`AuthorizedKeysFile .ssh/authorized_keys` directive — an exact reflection of the
source, so that additions, edits, and removals all take effect. The copy MUST
NOT be append-only: a stale key that was removed or commented out in the source
MUST NOT remain in the effective file after a restart. sshd re-reads
`authorized_keys` on every connection, so no separate reload signal is required.

#### Scenario: Adding a user grants access
- **WHEN** an operator adds a user's public key line to `bastion/config/authorized_keys` and restarts the bastion
- **THEN** `/config/.ssh/authorized_keys` reflects the source and contains the new key
- **AND** that user can authenticate to the `relay` account using the matching private key

#### Scenario: Removing a user revokes access
- **WHEN** an operator removes a key line from `bastion/config/authorized_keys` and restarts the bastion
- **THEN** `/config/.ssh/authorized_keys` no longer contains that key
- **AND** the next connection attempt with that key is refused
- **AND** the previously working key does not still authenticate from a stale copy

#### Scenario: Commenting out a key revokes access
- **WHEN** an operator comments out a key line in `bastion/config/authorized_keys` and restarts the bastion
- **THEN** the commented key is not present as an active key in `/config/.ssh/authorized_keys`
- **AND** the next connection attempt with that key is refused

#### Scenario: Existing sessions are reaped on restart
- **WHEN** the bastion is restarted to apply new keys
- **THEN** existing sessions remain open only until they end or the restart closes them
- **AND** new connections use the freshly synced key set

### Requirement: The account is forwarding-only with no shell
The `relay` account SHALL NOT be usable for general shell access; it SHALL exist only to forward local TCP connections to the backends. This is enforced in the **effective** sshd config (`/config/sshd/sshd_config`, the file sshd loads), where `ForceCommand /sbin/nologin` replaces the login shell with a non-interactive command. (The `linuxserver/openssh-server` image builds this file from its own base, which does not carry the hardening over — see the deployment note below.)

#### Scenario: No interactive shell is provided
- **WHEN** a user connects to the bastion
- **THEN** `ForceCommand /sbin/nologin` prevents an interactive shell
- **AND** only `-L` local TCP forwarding is permitted

### Requirement: Forwarding is local-only and scoped per key
The bastion SHALL allow only local (`-L`) TCP forwarding and SHALL support pinning each key to a specific set of backends via a `permitopen` prefix.

#### Scenario: Remote forwarding is blocked
- **WHEN** a client attempts remote (`-R`) or tunnel (`-D`) forwarding
- **THEN** it is refused because `AllowTcpForwarding local`, `PermitTunnel no`, `AllowAgentForwarding no`, and `AllowStreamLocalForwarding no` are set

#### Scenario: Key is locked to specific backends
- **WHEN** a key line is prefixed with `permitopen="ollama-gpu:11434"`
- **THEN** that key may forward only to `ollama-gpu:11434`
- **AND** forwarding to any other host:port is refused

### Requirement: External users reach backends through a local tunnel
An external client SHALL establish an SSH tunnel from a local port to a backend and point its OpenAI-compatible client at that local port.

#### Scenario: Tunnel to the GPU backend
- **WHEN** the user runs `ssh -L 11434:ollama-gpu:11434 -p 2222 relay@HOST_IP`
- **THEN** a local port `11434` forwards to `ollama-gpu:11434` through the bastion on host port `2222`
- **AND** the client can call `http://localhost:11434/v1` as if the backend were local

#### Scenario: Client API key is ignored
- **WHEN** the client sends any `api_key` value over the tunnel
- **THEN** the value is ignored because the SSH key is the sole authentication

### Requirement: Bastion hardening limits brute-force attempts
The SSH server SHALL enforce limits that reduce exposure to brute-force and idle-session abuse.

#### Scenario: Excessive auth attempts are rejected
- **WHEN** a client exceeds `MaxAuthTries` (3) failed attempts
- **THEN** the connection is dropped

#### Scenario: Idle sessions are reaped
- **WHEN** a tunnel is idle for longer than the keepalive window
- **THEN** `ClientAliveInterval` (300s) with `ClientAliveCountMax` (2) closes the dead session

### Requirement: Bastion activity is logged for audit
The SSH server SHALL log enough detail to determine who connected and with which key.

#### Scenario: Login is recorded with key fingerprint
- **WHEN** a user authenticates
- **THEN** `LogLevel VERBOSE` with `SyslogFacility AUTH` records the connection with the key fingerprint
- **AND** `ClientAliveInterval` (300s) with `ClientAliveCountMax` (2) reaps idle sessions

### Requirement: The effective config reflects the intended policy
The hardening directives SHALL be present in the **effective** sshd config that sshd loads (`/config/sshd/sshd_config`), not only in the human-edited reference file. Because the `linuxserver/openssh-server` image regenerates that file from its own base config (which hardcodes `AllowTcpForwarding no` and leaves `ForceCommand`/`LogLevel` commented), the intended policy must be written into the effective file directly.

#### Scenario: Hardening survives a container restart
- **WHEN** the bastion is restarted
- **THEN** `/config/sshd/sshd_config` still contains `AllowTcpForwarding local`, `ForceCommand /sbin/nologin`, `PasswordAuthentication no`, `LogLevel VERBOSE`, and the keepalive limits
- **AND** the reference `bastion/config/sshd_config` documents the same policy

## Related Decisions

- [decisions.md](./decisions.md) — ADRs for this capability, including the
deliberate choice of a single unprivileged `relay` account (no privileged or
jumpbox account) and exposing only host port 2222.
