FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        openssh-server \
        && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash tunserver && \
    mkdir -p /var/run/sshd && \
    mkdir -p /home/tunserver/.ssh && \
    chmod 700 /home/tunserver/.ssh && \
    ssh-keygen -A

COPY ssh_config/sshd_config /etc/ssh/sshd_config
RUN chmod 600 /etc/ssh/sshd_config

EXPOSE 2222

CMD ["/usr/sbin/sshd", "-D", "-e"]
