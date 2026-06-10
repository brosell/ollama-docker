FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        openssh-client \
        jq \
        curl \
        base64 \
        && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash tunclient

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /home/tunclient

CMD ["/entrypoint.sh"]
