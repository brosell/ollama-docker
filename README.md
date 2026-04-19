[![Open in Coder](https://coder.valiantlynx.com/open-in-coder.svg)](https://coder.valiantlynx.com/templates/docker/workspace?param.git_repo=git@github.com:mythrantic/ollama-docker.git)

# Ollama Podman Compose Setup

Welcome to the Ollama Podman Compose Setup! This project simplifies the deployment of Ollama using Podman Compose, making it easy to run Ollama with all its dependencies in a containerized environment.
[![Star History Chart](https://api.star-history.com/svg?repos=valiantlynx/ollama-docker&type=Date)](https://star-history.com/#valiantlynx/ollama-docker&Date)

## Getting Started

### Prerequisites

Make sure you have the following prerequisites installed on your machine:

- Podman v4+ and podman-compose

#### Installing Podman (Ubuntu 22.04)

Ubuntu 22.04's default repos only ship Podman 3.x. Add the Kubic repo to get a modern version:

```bash
. /etc/os-release
echo "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/unstable/xUbuntu_${VERSION_ID}/ /" \
  | sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:unstable.list
curl -fsSL "https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/unstable/xUbuntu_${VERSION_ID}/Release.key" \
  | sudo gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/devel_kubic_libcontainers_unstable.gpg
sudo apt update && sudo apt install -y podman
```

Then install podman-compose:

```bash
pip install podman-compose
```

Enable systemd lingering so containers can restart on boot:

```bash
sudo loginctl enable-linger $USER
```

#### GPU Support (Nvidia)

Install the NVIDIA Container Toolkit if not already present:

```bash
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
  && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit
```

Generate the CDI (Container Device Interface) config so Podman can access your GPU:

```bash
sudo mkdir -p /etc/cdi
sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml
```

Verify CDI config was generated:

```bash
nvidia-ctk cdi list
```

### Configuration

1. Clone the repository:

    ```bash
    git clone https://github.com/mythrantic/ollama-docker.git
    ```

2. Change to the project directory:

    ```bash
    cd ollama-docker
    ```

## Usage

Start Ollama and its dependencies using Podman Compose:

GPU only:
```bash
podman-compose --profile gpu up -d
```

CPU only:
```bash
podman-compose --profile cpu up -d
```

Both GPU and CPU backends:
```bash
podman-compose --profile gpu --profile cpu up -d
```

UI only (no Ollama backend — connect to an existing one):
```bash
podman-compose up -d
```

Visit [http://localhost:8080](http://localhost:8080) in your browser to access Ollama-webui.

### Pull a model

```bash
podman exec ollama-gpu ollama pull deepseek-r1:7b
podman exec ollama-cpu ollama pull codellama:7b
```

### Model Installation via UI

Navigate to Settings -> Model and install a model (e.g., llava-phi3). This may take a couple of minutes, but afterward, you can use it just like ChatGPT.

### Explore Langchain and Ollama

You can explore Langchain and Ollama within the project. A third container named **app** has been created for this purpose. Inside, you'll find some examples.

### Devcontainer and Virtual Environment

The **app** container serves as a devcontainer, allowing you to boot into it for experimentation. Additionally, the run.sh file contains code to set up a virtual environment if you prefer not to use Podman for your development environment.
If you have VS Code and the `Remote Development` extension, simply opening this project from the root will make VS Code ask you to reopen in container.

## Stop and Cleanup

Tear down containers (keeps volumes):

```bash
podman-compose --profile gpu --profile cpu down
```

## Contributing

We welcome contributions! If you'd like to contribute to the Ollama Podman Compose Setup, please follow our [Contribution Guidelines](CONTRIBUTING.md).

![Alt](https://repobeats.axiom.co/api/embed/d7581a324f7cb8cfcc18a1465b039157e3d1c8dc.svg "Repobeats analytics image")

## License

This project is licensed under the [RSOSL](https://github.com/mythrantic/ollama-docker/blob/main/LICENCE.md). Feel free to use, modify, and distribute it according to the terms of the license. Just give me a mention and some credit.

## Contact

If you have any questions or concerns, please contact us at [vantlynxz@gmail.com](mailto:vantlynxz@gmail.com).
