# Spec Delta

## MODIFIED Requirements

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
