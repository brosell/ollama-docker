port to expose 4200

### host

```
mkdir openfang-data

podman run -ti --rm --name openfang \
           --network ollama-docker_ollama-docker \
           -p 4200:4200 \
           ubuntu bash
```

### to install

```
DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt update && apt install -y curl vim && \
curl -fsSL https://openfang.sh/install | sh && \
export PATH=/root/.openfang/bin:$PATH \
export OPENFANG_LISTEN=0.0.0.0:4200


openfang init --quick
```


### Config after init

replace `/root/.openfang/config.toml` with
```
api_key = "p"
api_listen = "0.0.0.0:4200"

[default_model]
provider = "ollama"
model = "gemma4:e4b"
base_url = "http://ollama-gpu:11434/v1"

[memory]
decay_rate = 0.05
```

### start up
```
openfang start

```
