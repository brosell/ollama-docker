#!/bin/bash
# custom-init step for the SSH bastion (linuxserver/openssh-server image).
#
# Runs on every container start, AFTER the image's init-openssh-server-config.
#
# Why this exists:
#   The image's init script copies PUBLIC_KEY_FILE (/config/authorized_keys) into
#   the file sshd actually reads (/config/.ssh/authorized_keys) using an
#   append-only, dedupe-guarded copy:
#
#       PUBLIC_KEY2=$(cat "$PUBLIC_KEY_FILE")
#       if ! grep -q "$PUBLIC_KEY2" /config/.ssh/authorized_keys; then
#           echo "$PUBLIC_KEY2" >> /config/.ssh/authorized_keys
#       fi
#
#   The guard is broken: grep -q treats the whole source as a pattern and matches
#   line-by-line, so it succeeds the moment ANY line overlaps — and the shared
#   comment header always overlaps. Result: additions are silently dropped and
#   removals / commented-out keys are completely invisible after a restart.
#
# Fix: overwrite the effective file from the source on every start, instead of
# append. This makes /config/authorized_keys the single source of truth for both
# additions and removals, and it is idempotent.
set -eu

SRC=/config/authorized_keys
DST=/config/.ssh/authorized_keys
OWNER=relay

mkdir -p /config/.ssh

if [ -f "$SRC" ]; then
    # Do the copy as the relay user so ownership/perms match what sshd expects
    # and what the init script's chmod 600 / lsiown set up.
    if command -v runuser >/dev/null 2>&1; then
        runuser -u "$OWNER" -- sh -c "cat '$SRC' > '$DST'"
    else
        su -s /bin/sh "$OWNER" -c "cat '$SRC' > '$DST'"
    fi
fi

# Guarantee the effective file has the perms sshd requires (600, owned by
# relay), regardless of how it was written.
if [ -f "$DST" ]; then
    chown "${OWNER}:${OWNER}" "$DST"
    chmod 600 "$DST"
fi
