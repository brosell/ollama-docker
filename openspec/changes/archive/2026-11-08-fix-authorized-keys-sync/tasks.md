# Tasks

## 1. Implement the key-sync fix

- [x] 1.1 Confirm which custom-init mechanism `ghcr.io/linuxserver/openssh-server` (installed version) supports (custom script dir vs compose `command:`/`entrypoint:`), and pick one — record the choice in the commit message
- [x] 1.2 Add a startup step that overwrites `/config/.ssh/authorized_keys` from `/config/authorized_keys` (`cat /config/authorized_keys > /config/.ssh/authorized_keys`), run as the `relay` user so the init script's `chmod 600`/ownership still apply — verify with `podman exec bastion stat -c '%a %U' /config/.ssh/authorized_keys` shows `600 relay`
- [x] 1.3 Wire the step into `docker-compose.yml` (mount the custom-init script, or set the bastion service `command:`/`entrypoint:`) — verify the bastion service definition is valid and starts with `podman-compose --profile bastion up -d`

## 2. Verify behavior

- [x] 2.1 Add a key to `bastion/config/authorized_keys`, restart, and verify it appears in `/config/.ssh/authorized_keys` and the user can authenticate — verify with `podman exec bastion grep <keyid> /config/.ssh/authorized_keys` and an `ssh` login attempt
- [x] 2.2 Comment out / remove a key in `bastion/config/authorized_keys`, restart, and verify it is GONE from `/config/.ssh/authorized_keys` and no longer authenticates — verify the stale key does not still work (the exact failure that motivated this change)

## 3. Update documentation and spec

- [x] 3.1 Update `bastion/README.md` ("How the config actually works", "Adding a user", "Removing a user") to describe overwrite-on-restart (not append) and that sshd re-reads keys per connection — verify the documented `grep`/restart commands run as written
- [x] 3.2 Confirm the `ssh-bastion-access` spec delta (already authored in this change) matches the implemented behavior — verify `openspec validate ssh-bastion-access --type spec` passes after archive

## 4. Integration check

- [x] 4.1 Full restart with mixed add/remove, confirm effective key file matches source exactly and both new and removed keys behave as expected — verify `podman exec bastion cat /config/.ssh/authorized_keys` equals `bastion/config/authorized_keys` (modulo the comment header)

## Workflow follow-up

- Archive the change after the project's review requirements are satisfied.
- Verify the archived result with `openspec list --specs` and `openspec show ssh-bastion-access --type spec`.
