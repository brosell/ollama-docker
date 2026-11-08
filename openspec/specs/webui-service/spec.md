# webui-service Specification

## Purpose

The webui-service capability defines the `ollama-webui` container as an owner-facing chat interface that fronts the Ollama backends. It captures how the UI is wired to the backends, its access and auth posture, and the constraint that it is not routed through the bastion, so changes to the UI configuration do not unexpectedly alter backend connectivity or security.

## Requirements

### Requirement: Web UI reaches every backend by internal name
The web UI SHALL be configured with a list of backend base URLs so a single UI can drive all active backends.

#### Scenario: UI is wired to all backends
- **WHEN** `ollama-webui` starts
- **THEN** `OLLAMA_BASE_URLS` lists `http://ollama-gpu:11434`, `http://ollama-amd:11434`, and `http://ollama-cpu:11434` separated by semicolons
- **AND** each URL uses the internal service name on the `ollama-docker` network

### Requirement: Web UI is owner-facing with auth disabled
The UI SHALL run in a mode intended for the owner, without web authentication.

#### Scenario: Web auth is off
- **WHEN** `ollama-webui` runs
- **THEN** `WEBUI_AUTH=False` disables web UI login
- **AND** the UI is reachable at `http://localhost:8080` for the owner

### Requirement: Web UI is not exposed through the bastion
The UI SHALL NOT be part of the external bastion access path.

#### Scenario: UI has no bastion route
- **WHEN** an external user sets up a bastion tunnel
- **THEN** the tunnel forwards only to the Ollama backends
- **AND** the web UI on port 8080 is not reachable through the bastion

### Requirement: Web UI resolves the host IP for direct access
The UI SHALL be configured so it can reach the host's LAN IP directly when needed.

#### Scenario: NO_PROXY covers the host IP
- **WHEN** `ollama-webui` makes outbound requests to the host
- **THEN** `NO_PROXY` includes `${HOST_IP}` so those requests bypass any proxy
- **AND** `host.containers.internal` is mapped to `${HOST_IP}` for host reachability

### Requirement: Web UI persists its data in a named volume
The UI SHALL store its state in a dedicated named volume so it survives container recreation.

#### Scenario: UI data persists
- **WHEN** `ollama-webui` writes its database and cache
- **THEN** data is stored under `/app/backend/data` mapped to the `ollama-webui-data` volume
- **AND** the data remains after the container is recreated
