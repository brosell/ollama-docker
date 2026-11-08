# podman-compose-deployment Specification

## Purpose

The podman-compose-deployment capability defines how the Ollama stack is brought up and torn down with `podman-compose`, organized around named profiles so operators can start exactly the backends and services they need. It captures the service inventory, profile membership, lifecycle behavior, and volume persistence that every other capability depends on.

## Requirements

### Requirement: Services are grouped behind profiles
Each service SHALL declare one or more `profiles` and SHALL start only when at least one of its profiles is activated with `--profile`. A service with no matching active profile SHALL NOT start.

#### Scenario: Activating a profile starts its services
- **WHEN** the operator runs `podman-compose --profile gpu up -d`
- **THEN** the `ollama-gpu` service (which declares `profiles: [gpu]`) is started
- **AND** services that belong only to inactive profiles (e.g. `ollama-cpu`, `bastion`) are not started

#### Scenario: No active profile starts no profiled service
- **WHEN** `podman-compose up -d` is run without any `--profile` flag
- **THEN** only services that declare no profile are started
- **AND** every profile-gated service (`ollama-gpu`, `ollama-amd`, `ollama-cpu`, `ollama-webui`, `app`, `bastion`) is skipped

### Requirement: Multiple profiles combine additively
Passing multiple `--profile` flags SHALL start the union of all matching services, so several backends can run at once.

#### Scenario: GPU and CPU backends start together
- **WHEN** the operator runs `podman-compose --profile gpu --profile cpu up -d`
- **THEN** both `ollama-gpu` and `ollama-cpu` are started
- **AND** the `ollama-docker` network is shared by both

#### Scenario: Full stack brings up every service
- **WHEN** the operator runs `podman-compose --profile gpu --profile amd --profile cpu --profile ui --profile bastion --profile dev up -d`
- **THEN** every service in the compose file is started

### Requirement: Teardown stops containers but preserves volumes
The down command SHALL stop and remove containers while leaving named volumes intact so model data and UI data survive.

#### Scenario: Down keeps volumes
- **WHEN** the operator runs `podman-compose --profile gpu --profile cpu down`
- **THEN** the started containers are removed
- **AND** the named volumes (`ollama-gpu-data`, `ollama-amd-data`, `ollama-cpu-data`, `ollama-webui-data`) are retained

### Requirement: Backends restart unless explicitly stopped
Backend and gateway services SHALL use `restart: unless-stopped` so they recover from crashes and host reboots without manual intervention.

#### Scenario: Container restarts after a crash
- **WHEN** an `ollama-*` backend container or the `bastion` container exits unexpectedly
- **THEN** the container runtime restarts it because `restart: unless-stopped` is set

#### Scenario: Restart policy does not restart on manual stop
- **WHEN** the operator explicitly stops a container via the down command
- **THEN** the `unless-stopped` policy does not bring it back

### Requirement: The dev app is built from the project Dockerfile
The `app` service SHALL build its image from the repository Dockerfile rather than pulling a prebuilt image.

#### Scenario: App image is built locally
- **WHEN** `podman-compose --profile dev up -d` is run
- **THEN** the `app` service executes `build: .` to assemble the image from the Dockerfile
- **AND** the image installs dependencies from `requirements.txt` before starting uvicorn

### Requirement: Backend images are pulled fresh
Backend services SHALL declare `pull_policy: always` so they fetch the latest image rather than reusing a stale local copy.

#### Scenario: Latest image is pulled
- **WHEN** a backend service (`ollama-gpu`, `ollama-amd`, `ollama-cpu`) starts
- **THEN** `pull_policy: always` causes the `docker.io/ollama/ollama` image to be pulled
