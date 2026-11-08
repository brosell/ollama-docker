# backend-networking Specification

## Purpose

The backend-networking capability defines how Ollama backends, the web UI, and the bastion communicate and how they are (or are not) exposed beyond the host. It captures the internal network topology, the LAN-only host-port bindings, the internal hostnames used between containers, and the port scheme so that backends are reachable without being published to the public interface.

## Requirements

### Requirement: All services share one internal network
Every service SHALL attach to the internal `ollama-docker` network so containers reach each other by service name.

#### Scenario: Services resolve each other by name
- **WHEN** `ollama-webui` needs to reach a backend
- **THEN** it connects using the service name `ollama-gpu` (and `ollama-amd`, `ollama-cpu`) on port `11434`
- **AND** the connection is carried over the `ollama-docker` network

#### Scenario: Network is created by the stack
- **WHEN** the stack is brought up
- **THEN** the `ollama-docker` network is created with `external: false`

### Requirement: Backends are not published to the public interface
Backend services SHALL NOT publish their Ollama ports to the host's public interface; they SHALL be reachable only over the internal network and via the bastion's local TCP forwarding.

#### Scenario: No public host port for a backend
- **WHEN** the `ollama-gpu` service starts
- **THEN** it does not declare a `0.0.0.0:11434:11434` host port binding
- **AND** the only ways to reach `ollama-gpu:11434` from outside the host are the bastion tunnel or the LAN binding below

### Requirement: Backends bind to the LAN host IP only
Each backend SHALL publish its Ollama port bound to `${HOST_IP}` (the operator's LAN IP), not to `0.0.0.0`, so LAN devices can reach it directly while it stays off the public interface.

#### Scenario: LAN device reaches a backend directly
- **WHEN** `HOST_IP` is set to the host's LAN IP (e.g. `192.168.1.50`)
- **THEN** a device on the same LAN can reach `ollama-gpu` at `http://HOST_IP:11434/v1`
- **AND** the binding is `HOST_IP:11434:11434`, not a wildcard address

#### Scenario: Missing host IP disables LAN binding
- **WHEN** `HOST_IP` is unset or left as the placeholder `192.168.1.x`
- **THEN** the LAN binding is not valid and direct LAN access does not work
- **AND** the operator is expected to run `./gen-env.sh` to set a real LAN IP

### Requirement: Distinct host ports identify each backend
The three backends SHALL be distinguished on the host by consecutive ports so clients can select a backend by port.

#### Scenario: Port maps to the correct backend
- **WHEN** a client connects to `HOST_IP:11434`
- **THEN** it reaches `ollama-gpu`
- **WHEN** a client connects to `HOST_IP:11435`
- **THEN** it reaches `ollama-cpu`
- **WHEN** a client connects to `HOST_IP:11436`
- **THEN** it reaches `ollama-amd`

### Requirement: The web UI listens on a fixed local port
The web UI service SHALL publish its port on the default host interface for owner-facing access and SHALL NOT be routed through the bastion.

#### Scenario: UI reachable on 8080
- **WHEN** the `ui` profile is active
- **THEN** `ollama-webui` is reachable at `http://localhost:8080`
- **AND** it is not exposed via the bastion
