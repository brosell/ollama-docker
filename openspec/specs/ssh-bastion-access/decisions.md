# Bastion Decisions (ADR)

Architecture decisions recorded for the `ssh-bastion-access` capability.
Each entry follows the Context / Decision / Consequences format. These are
deliberate, not aspirational — re-reading one means re-opening the tradeoff.

Related: [`spec.md`](./spec.md), [`bastion/README.md`](../../../bastion/README.md)

---

## ADR-001: Single unprivileged `relay` account only

### Context

The bastion is the sole public entry point for external users to reach the
Ollama backends. Its security model is "the SSH key *is* the access control":
no API key, no TLS. A question was raised about adding a second, privileged
account (a shell prompt, or a jumpbox for onward SSH / SOCKS) so the owner
could manage the host through the bastion.

The bastion account `relay` is the account an *untrusted external* client is
given. Any privilege bolted onto `relay` is inherited by every external user,
which would defeat the locked-down design.

### Decision

The bastion runs **one account, `relay`, with no privileges beyond `-L`
forwarding to the Ollama backends.** No separate privileged or jumpbox account
is added. A privileged account (shell + agent forwarding, `Match User`-carved
out) was considered and **deliberately deferred**.

### Consequences

- External users remain locked to local TCP forwarding to the backends; the
  bastion is not usable as a host shell or a network pivot.
- The owner does **not** get a shell on the host through the bastion. Host
  management happens out-of-band (see ADR-003).
- If a privileged account is ever needed, it must be a separate account
  authorized by its own key(s), carved out with `Match User` so `relay`
  stays exactly as locked as today. It must also be IP-pinned (`from=`) and
  protected by rate-limiting before being exposed to the internet, because the
  SSH key would be the only control on a host-accessible login.

---

## ADR-002: `relay` stays `ForceCommand nologin` + `AllowTcpForwarding local`

### Context

A bastion account can be configured in two directions at once: as a dumb pipe
(forwarding only) or as a real login (shell + pivoting). The `linuxserver/openssh-server`
image supports both. Choosing which capabilities `relay` gets defines the
attack surface of the one account every external user shares.

### Decision

`relay` retains:

- `ForceCommand /usr/sbin/nologin` — no interactive shell / prompt.
- `AllowTcpForwarding local` — only `-L` forwarding; `-R`, `-D`, tunnels and
  agent forwarding are refused.

### Consequences

- The account cannot be used to obtain a shell, run arbitrary commands, or
  pivot across the network.
- It can only forward local TCP connections to the backends, which is its
  entire purpose.
- This is a hardening invariant: loosening it on `relay` loosens it for every
  external user, so it is deliberately conservative.
- **Implementation gotcha (2026-11-06):** the `linuxserver/openssh-server`
  image builds its **effective** sshd config at `/config/sshd/sshd_config` from
  its own base config, which hardcodes `AllowTcpForwarding no` and leaves
  `ForceCommand`/`LogLevel` commented. The reference file `bastion/config/sshd_config`
  is therefore *not* what sshd loads. The policy must be written into
  `/config/sshd/sshd_config` directly, and `ForceCommand` must point at the
  real path `/sbin/nologin` (busybox) — `/usr/sbin/nologin` does not exist on
  this image and would make every login fail outright. `LogLevel VERBOSE` and
  the keepalive limits likewise need to be uncommented in the effective file.

---

## ADR-003: Single forwarded port (`2222`); do not forward host:22

### Context

The goal was a single internet-facing entry point. Two facts were established
about this environment:

- The host runs its own sshd on `0.0.0.0:22`. This is *listening* on all
  interfaces, which is **not** the same as being internet-exposed — it is only
  reachable from the internet if the router/firewall forwards port 22.
- Podman here is **rootless** (`rootless: true`, `graphRoot` under the user's
  home) and runs **socketless** (no `/run/podman/podman.sock`, no
  `/run/docker.sock`). The bastion container therefore cannot reach the host's
  own network stack: from inside the container, the gateway `10.89.0.1:22`
  refuses connections.

Because rootless podman does not route back to the host, a "jump from the
bastion to the host's sshd over the internal network" is **not possible** on
this box without giving the bastion host networking (which would weaken its
isolation).

### Decision

The bastion exposes **only host port `2222`**, and host port `22` is **not**
forwarded to the internet. Host management happens from the LAN or a VPN,
directly against the host's sshd — never through the bastion.

### Consequences

- The internet sees one forwarded port (`2222`) and one account (`relay`),
  matching the single-entry-point goal.
- Host management is only possible when on the LAN/VPN, or by forwarding port
  22 separately (a deliberate change to this decision, not the default).
- Mounting the podman socket into the bastion would not grant host root here —
  rootless podman acts as uid 1000 — so it is not a shortcut to host control
  and is not used for that purpose.
- **Action for the owner (outside this repo):** confirm the router/firewall
  does not forward port 22 to the internet. If it does, harden the host sshd
  (key-only + rate-limiting) before relying on the single-port model.
