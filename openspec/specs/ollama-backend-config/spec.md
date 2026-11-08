# ollama-backend-config Specification

## Purpose

The ollama-backend-config capability defines the per-backend runtime configuration for each Ollama container — the environment variables, device access, and GPU/Vulkan/ROCm flags that determine how a backend uses the underlying hardware. It captures the constraints that make each backend behave correctly, including the Strix Halo iGPU requirements, so changes to backend configuration do not silently break model loading or performance.

## Requirements

### Requirement: Backends keep models in persistent volumes
Each backend SHALL store its model store in a dedicated named volume so pulled models survive container recreation.

#### Scenario: Pulled model persists across restart
- **WHEN** a model is pulled into `ollama-gpu`
- **THEN** it is written under `/root/.ollama` mapped to the `ollama-gpu-data` volume
- **AND** the model remains available after the container is recreated

### Requirement: Backends keep loaded models resident
Each backend SHALL set `OLLAMA_KEEP_ALIVE` so a loaded model stays in memory for repeated requests instead of unloading immediately.

#### Scenario: Model stays loaded
- **WHEN** a model is loaded on a backend
- **THEN** `OLLAMA_KEEP_ALIVE=24h` keeps it resident for the configured duration

### Requirement: Backends set a bounded context length
Each backend SHALL set `OLLAMA_CONTEXT_LENGTH` to a value appropriate to its hardware so long models fit without exhausting RAM.

#### Scenario: GPU backend uses a large context
- **WHEN** `ollama-gpu` runs
- **THEN** `OLLAMA_CONTEXT_LENGTH=32000` is applied

#### Scenario: Large models reduce context to leave room for KV cache
- **WHEN** running 70B+ models on the AMD backend
- **THEN** `OLLAMA_CONTEXT_LENGTH` is reduced (e.g. to 65536) so the KV cache fits in unified RAM
- **AND** the full 262144 context is not used with a 70B Q8 model because it would exhaust RAM

### Requirement: AMD backend enables the Strix Halo iGPU
The AMD backend SHALL use the ROCm image and the specific flags required for Ollama to actually use the integrated GPU instead of silently falling back to CPU.

#### Scenario: iGPU is used instead of CPU
- **WHEN** `ollama-amd` runs on Strix Halo (gfx1151)
- **THEN** `OLLAMA_IGPU_ENABLE=1` is set so Ollama does not drop the iGPU
- **AND** `HSA_OVERRIDE_GFX_VERSION=11.5.0` targets the correct gfx1151 architecture

#### Scenario: ROCm stability flags are applied
- **WHEN** the AMD backend loads a model
- **THEN** `HSA_ENABLE_SDMA=0`, `OLLAMA_FLASH_ATTENTION=1`, and single-parallel settings are applied to avoid known gfx1151 HIP corruption and instability
- **AND** `ollama ps` after load reports the model on the GPU rather than 100% CPU

### Requirement: CPU backend uses the Vulkan path with iGPU device access
The CPU backend SHALL use the standard image with Vulkan acceleration and SHALL expose the iGPU device nodes.

#### Scenario: CPU backend accelerates via Vulkan
- **WHEN** `ollama-cpu` runs
- **THEN** `OLLAMA_VULKAN=1` is set
- **AND** the `/dev/dri` and `/dev/kfd` device nodes are passed through

### Requirement: Backends accept cross-origin requests from the UI
Each backend SHALL set `OLLAMA_ORIGINS=*` so the web UI can call it from a browser context.

#### Scenario: UI origins are allowed
- **WHEN** `ollama-webui` calls a backend
- **THEN** `OLLAMA_ORIGINS=*` permits the cross-origin request

### Requirement: Backend model load is verified after changes
Because the AMD/ROCm path is working but not fully stable, a backend's GPU usage SHALL be verified after any model load or configuration change.

#### Scenario: Verify GPU usage after load
- **WHEN** a model is loaded or backend configuration changes
- **THEN** `ollama ps` is expected to confirm the model runs on the GPU
- **AND** a silent CPU fallback is treated as a configuration problem to investigate
