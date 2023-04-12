FROM debian:11-slim


USER root

RUN apt-get update && apt-get install -y curl gnupg2 iproute2 && apt install -y --reinstall software-properties-common
RUN curl -fsSL https://apt.releases.hashicorp.com/gpg | apt-key add - \
    && apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
    && apt-get update \
    && apt-get install -y nomad unzip

RUN curl -L -o cni-plugins.tgz "https://github.com/containernetworking/plugins/releases/download/v1.0.0/cni-plugins-linux-$( [ $(uname -m) = aarch64 ] && echo arm64 || echo amd64)"-v1.0.0.tgz && \
      mkdir -p /opt/cni/bin && \
      tar -C /opt/cni/bin -xzf cni-plugins.tgz


#VOLUME ["/etc/nomad.d/"]

# We need to be able to communicate with the Docker engine
VOLUME ["/var/run/docker.sock"]

#ENTRYPOINT nomad -v
ENTRYPOINT nomad agent -config=/etc/config
