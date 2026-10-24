# Running Ollama on AMD Strix Halo (gfx1151) with Podman

The AMD Ryzen AI Max ("Strix Halo") has up to 128 GB of unified memory shared between CPU and iGPU. That makes it one of the few machines that can run 70B+ models locally without a discrete GPU. Getting Ollama to actually use the iGPU took more work than it should. Here is what went wrong and what fixed it.

## The symptoms

After starting the container, `ollama ps` showed `100% CPU` no matter what. The model loaded, answered, and ran — just slowly, on the CPU.

## What we tried that did not work

**Vulkan path (`OLLAMA_VULKAN=1` with the standard image)**
Ollama's Vulkan backend cannot measure unified memory, so it sees `vram="0 B"` and refuses to offload. The model silently falls back to CPU. `OLLAMA_VULKAN=1` does nothing useful on Strix Halo right now.

**ROCm image with `HSA_OVERRIDE_GFX_VERSION=11.0.0`**
The Strix Halo iGPU is `gfx1151` (or `gfx1150` as ROCm reports it). `11.0.0` targets a different architecture. Ollama detected the GPU but reported `vram="0 B"` and dropped it.

**ROCm image with `HSA_OVERRIDE_GFX_VERSION=11.5.0`, no other changes**
Same result. The GPU was detected (`Radeon 8060S Graphics`, `gfx1150`) but the log showed:

```
dropping integrated GPU; to enable, set OLLAMA_IGPU_ENABLE=1
```

Ollama drops iGPUs silently by default. None of the guides mentioned this.

## What actually works

Use the ROCm image with `OLLAMA_IGPU_ENABLE=1`. That is the only thing that matters. Everything else is supporting configuration.

```yaml
ollama-amd:
  profiles: [amd]
  image: docker.io/ollama/ollama:rocm
  container_name: ollama-amd
  restart: unless-stopped
  ports:
    - 11436:11434
  volumes:
    - ollama-amd-data:/root/.ollama
  environment:
    - OLLAMA_HOST=0.0.0.0
    - OLLAMA_KEEP_ALIVE=24h
    - OLLAMA_CONTEXT_LENGTH=65536
    - HSA_OVERRIDE_GFX_VERSION=11.5.0   # correct version for gfx1151
    - HSA_ENABLE_UNIFIED_MEMORY=1        # let ROCm use RAM beyond carved-out VRAM
    - HSA_ENABLE_SDMA=0                  # known to help on gfx1151
    - OLLAMA_IGPU_ENABLE=1               # THE fix — Ollama drops iGPUs by default
    - OLLAMA_FLASH_ATTENTION=1
    - OLLAMA_NUM_PARALLEL=1
    - OLLAMA_MAX_LOADED_MODELS=1
  devices:
    - /dev/kfd:/dev/kfd
    - /dev/dri:/dev/dri
```

Start it:

```bash
podman-compose --profile amd up -d
```

Verify:

```bash
podman exec ollama-amd ollama run ornith:9b "say hi"
podman exec ollama-amd ollama ps
# NAME          SIZE    PROCESSOR    UNTIL
# ornith:9b     8.0 GB  100% GPU     24 hours from now
```

The logs confirm 96 GB of unified memory is available:

```
inference compute  description="Radeon 8060S Graphics"  type=iGPU  total="96.0 GiB"  available="95.8 GiB"
```

## Environment

- Machine: AMD Ryzen AI Max+ 395 (Strix Halo), 128 GB LPDDR5X
- OS: Ubuntu 26.04 LTS, kernel 7.0.0
- Ollama image: `docker.io/ollama/ollama:rocm` (ROCm 7.2 bundled)
- Container runtime: Podman

## Notes on model sizing with 128 GB

| Model size | Quantisation | Fits? |
|---|---|---|
| 7B–9B | any | yes, trivially |
| 30B–35B | Q4–Q8 | yes |
| 70B | Q4 (~40 GB) | yes |
| 70B | Q8 (~80 GB) | yes, leaves ~45 GB for KV cache |
| 120B MoE | Q4 (~65 GB) | yes |
| 120B dense | Q8 (~130 GB) | tight, reduce context |

Keep `OLLAMA_CONTEXT_LENGTH` at 65536 or below when running 70B+ models to leave room for the KV cache. The full 262144 context at 70B Q8 will exhaust RAM.

## ROCm stability on gfx1151 (as of October 2026)

ROCm HIP on gfx1151 has known issues: GPU page faults during model load, silent output corruption from HIP graph replay, and various upstream bugs tracked in ROCm/ROCm#5745 and ROCm/ROCm#6042. The configuration above avoids the worst of these (`HSA_ENABLE_SDMA=0`, single parallel, no graph capture issues at this scale), but treat it as working rather than fully stable. Check `ollama ps` after every model load.
