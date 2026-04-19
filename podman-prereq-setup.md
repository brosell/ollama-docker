# Podman Prerequisites Setup (Ubuntu 22.04)

Run these commands once to prepare your system before using `podman-compose`.

## 1. Upgrade Podman

Ubuntu 22.04 ships Podman 3.x by default. Add the Kubic repo to get a modern version:

```bash
. /etc/os-release
echo "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/unstable/xUbuntu_${VERSION_ID}/ /" \
  | sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:unstable.list
curl -fsSL "https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/unstable/xUbuntu_${VERSION_ID}/Release.key" \
  | sudo gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/devel_kubic_libcontainers_unstable.gpg
sudo apt update && sudo apt install -y podman
```

## 2. Install podman-compose

```bash
pip install podman-compose
```

## 3. Generate CDI config for Nvidia GPU

Podman uses CDI (Container Device Interface) for GPU passthrough instead of Docker's runtime hook:

```bash
sudo mkdir -p /etc/cdi
sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml
```

Verify the GPU device was detected:

```bash
nvidia-ctk cdi list
```

## 4. Enable systemd lingering

Allows Podman containers to restart on boot in rootless mode:

```bash
sudo loginctl enable-linger $USER
```

## Verify everything is ready

```bash
podman --version
podman-compose --version
nvidia-ctk cdi list
```
