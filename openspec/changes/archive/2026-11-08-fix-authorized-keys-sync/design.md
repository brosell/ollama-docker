# Design

## Context

The bastion runs on the `linuxserver/openssh-server` image. sshd reads keys from
`/config/.ssh/authorized_keys` (`AuthorizedKeysFile .ssh/authorized_keys` in the
effective `/config/sshd/sshd_config`). The image's init script
(`/etc/s6-overlay/s6-rc.d/init-openssh-server-config/run`) is configured via
`PUBLIC_KEY_FILE=/config/authorized_keys` to copy the source into that file — but
only with an append-only, dedupe-guarded copy:

```
PUBLIC_KEY2 = cat "$PUBLIC_KEY_FILE"
if ! grep -q "$PUBLIC_KEY2" /config/.ssh/authorized_keys; then
    echo "$PUBLIC_KEY2" >> /config/.ssh/authorized_keys   # APPEND ONLY
fi
```

The guard is broken: `grep -q` treats the whole source as a pattern and matches
line-by-line, so it succeeds the moment any line overlaps (the shared comment
header always overlaps). Additions are dropped and **removals are invisible**.
`/config` is mounted writable from `./bastion/config`, and the init script runs
on every start. sshd re-reads `authorized_keys` per connection, so once the
effective file is correct, no `SIGHUP`/restart is needed for it to take effect.

## Goals / Non-Goals

**Goals:**
- Editing `bastion/config/authorized_keys` + restart reliably makes the effective
  key file match the source (additions, edits, removals).
- The fix is wired into the repo so it runs automatically on start — no manual
  copy after each edit.
- The `ssh-bastion-access` spec describes the mechanism as it actually behaves.

**Non-Goals:**
- Changing authentication policy (`PasswordAuthentication no`, `PubkeyAuthentication yes`,
  `ForceCommand /sbin/nologin`, forwarding rules) — out of scope.
- Replacing the image or the `relay` single-account model.
- Live hot-reload of keys without a restart — sshd already re-reads per connection,
  but the *sync* step runs at startup; a restart remains the trigger for syncing.

## Decisions

### Decision: Overwrite the effective file from the source at startup
Replace the append-only, guard-based copy with a plain overwrite:
`cat /config/authorized_keys > /config/.ssh/authorized_keys` (run as the `relay`
user, preserving the 600 perms the init script sets afterward). This makes the
source the single source of truth for both additions and removals, and it is
idempotent.

- **Alternative — fix the guard in the image:** patching the upstream init to
  diff/replace instead of append is fragile: it lives in the image, is lost on
  upgrade, and the "is the whole file present?" check is inherently unreliable for
  detecting removals. Overwrite is simpler and strictly more correct.
- **Alternative — manage `/config/.ssh/authorized_keys` directly:** drops the
  indirection but abandons the documented `authorized_keys` workflow and the
  `PUBLIC_KEY_FILE` contract the compose file already sets. Worse ergonomics.

### Decision: Where to run the overwrite
Prefer the image's own supported mechanism for extra init steps. The
`linuxserver/openssh-server` image runs scripts from a custom-init location on
startup; a small script that overwrites the effective file from the source is
mounted there and referenced from `docker-compose.yml`. If the image's supported
custom-init path is not available/usable, fall back to a one-line `command:`/
`entrypoint:` wrapper in the bastion service. The exact mount point is an
implementation detail to confirm against the image version at apply time.

### Decision: Keep `PUBLIC_KEY_FILE` but stop relying on it as the sole authority
`PUBLIC_KEY_FILE` stays set (harmless), but the effective key file is now driven
by the overwrite step, not by the image's append logic. Docs are updated so
operators know the source file is the single source of truth.

## Risks / Trade-offs

- **Overwrite clobbers out-of-band edits to `.ssh/authorized_keys`** → Acceptable:
  `authorized_keys` is documented as the single source of truth, so anything added
  directly to the effective file is already unsupported. Docs state this.
- **Custom-init mount depends on image version** → Mitigation: confirm the
  supported path against `ghcr.io/linuxserver/openssh-server` at apply time; fall
  back to a compose `command:`/`entrypoint:` wrapper if the supported path is
  unavailable. Either way the overwrite logic is identical.
- **Perms/ownership on the effective file** → The init script already `chmod 600`
  and `lsiown`s `/config/.ssh`; run the overwrite as `relay` (or before those
  steps) so perms stay correct.
- **Spec currently claims the (broken) copy works** → Fixed in this change's spec
  delta so the contract matches reality.

## Migration Plan

1. Add the overwrite step (custom-init script or compose wrapper).
2. Update `bastion/README.md` ("How the config actually works", "Adding a user",
   "Removing a user") to describe overwrite-on-restart and per-connection re-read.
3. Update the `ssh-bastion-access` spec delta (this change).
4. Rollback: remove the custom-init mount / restore the compose `command:` and the
   README/spec edits. The live bastion can be recovered immediately with a manual
   `cat /config/authorized_keys > /config/.ssh/authorized_keys` (no restart needed
   for the next connection).

## Open Questions

- Which custom-init mechanism the installed image version actually supports
  (custom script dir vs compose `command:`/`entrypoint:`). Does not change the
  overwrite approach — only where the one-line script is mounted.
