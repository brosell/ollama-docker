# host-env-generation Specification

## Purpose

The host-env-generation capability defines how the operator's LAN host IP is detected and written to the `.env` file that podman-compose consumes. It captures the auto-detection behavior of `gen-env.sh`, the `.env` contract that the compose file depends on, and the safety constraints that keep the generated value from breaking the network bindings.

## Requirements

### Requirement: gen-env.sh detects the LAN host IP
The script SHALL determine the host's LAN IP address using the system routing table and write it to `.env`.

#### Scenario: IP is detected and written
- **WHEN** `./gen-env.sh` is run on a host with a LAN route
- **THEN** it extracts the source IP from `ip route get 1.1.1.1`
- **AND** it writes `HOST_IP=<detected-ip>` to `.env`

#### Scenario: Detection failure is reported, not silently ignored
- **WHEN** no LAN route can be determined
- **THEN** the script prints an error to stderr
- **AND** it exits non-zero without writing a bogus `.env`

### Requirement: .env supplies the HOST_IP the compose file reads
The `.env` file SHALL be the single source of `HOST_IP` that drives the backend LAN bindings and UI proxy settings.

#### Scenario: Compose reads HOST_IP from .env
- **WHEN** podman-compose evaluates the compose file
- **THEN** `${HOST_IP}` resolves to the value in `.env`
- **AND** a missing `HOST_IP` yields an empty/placeholder binding that disables direct LAN access

### Requirement: Generated value is a real LAN IP, not a placeholder
The placeholder in `.env.example` SHALL be replaced by a usable LAN IP before the stack provides LAN access.

#### Scenario: Placeholder disables LAN access
- **WHEN** `.env` still contains the placeholder `192.168.1.x`
- **THEN** the backend `HOST_IP:port` bindings are not valid LAN addresses
- **AND** direct LAN access does not work until `./gen-env.sh` writes a real IP

### Requirement: .env is the only file the script writes
The script SHALL write only `.env` and SHALL NOT overwrite unrelated configuration.

#### Scenario: Only .env is modified
- **WHEN** `./gen-env.sh` completes successfully
- **THEN** it overwrites `.env` with the current `HOST_IP`
- **AND** no other project files are changed
