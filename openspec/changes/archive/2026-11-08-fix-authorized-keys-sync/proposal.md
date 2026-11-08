# Proposal

## Why

The bastion's key-sync is broken: editing `bastion/config/authorized_keys` and
restarting does **not** reliably update the keys sshd actually reads
(`/config/.ssh/authorized_keys`). The `linuxserver/openssh-server` init script
copies the source into the destination only with an append-only, "already
present?" guard, and that guard is broken — `grep -q "$WHOLE_FILE"` matches
line-by-line, so it reports "already present" as soon as any line overlaps (the
shared comment header always overlaps). The result: additions are silently
dropped, and **removals/comment-outs are completely invisible**. This is exactly
the failure observed live — a commented-out key still granted access after a
restart. The `ssh-bastion-access` spec currently *assumes* this copy works; it
does not, so the spec is also wrong about reality.

## What Changes

- Make key changes to `bastion/config/authorized_keys` take effect on restart by
  **overwriting** `/config/.ssh/authorized_keys` from the source on startup,
  instead of the image's append-only, guard-based copy.
- Wire this into the repo (a small custom-init step) so it runs automatically on
  every bastion start — no manual copy after each edit.
- Correct the `ssh-bastion-access` spec so its "add/remove a user" scenarios
  describe what actually happens: the source file is the single source of truth,
  and the effective key file is overwritten (not appended to) on start.
- Document the operator workflow (edit source, restart) and the fact that sshd
  re-reads keys per connection, so no reload signal is required.

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `ssh-bastion-access`: the requirement "Users authenticate with a per-user
  public key" is corrected — the mechanism that copies
  `bastion/config/authorized_keys` into `/config/.ssh/authorized_keys` must
  reliably reflect the source (including removals) on restart, not append-only
  with a broken dedupe guard. The add/remove scenarios are updated to match.

## Impact

- **`bastion/config/authorized_keys`** — remains the single source of truth for
  keys.
- **`/config/.ssh/authorized_keys`** (container, runtime state) — now overwritten
  from the source on each start.
- **`bastion/README.md`** — the "How the config actually works" / "Adding a
  user" / "Removing a user" sections describe the corrected mechanism.
- **`docker-compose.yml`** — may gain a mount for the custom-init step (or, if
  the image already supports a custom script dir, use it there). `PUBLIC_KEY_FILE`
  stays set but is no longer the sole authority for the effective key file.
- **`openspec/specs/ssh-bastion-access/spec.md`** — corrected add/remove
  scenarios.
- No change to authentication policy (`PasswordAuthentication no`,
  `PubkeyAuthentication yes`, `ForceCommand /sbin/nologin`, forwarding rules) —
  those are unaffected.
