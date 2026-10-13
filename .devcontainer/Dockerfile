FROM mcr.microsoft.com/devcontainers/base:ubuntu-22.04

USER root
ENV DEBIAN_FRONTEND=noninteractive

# 1. Asegurar usuario codespace con permisos sudo sin password
RUN if ! id -u codespace >/dev/null 2>&1; then \
        useradd -m -s /bin/bash -G sudo codespace; \
    fi \
    && echo "codespace ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/codespace \
    && chmod 0440 /etc/sudoers.d/codespace

# 2. Habilitar repositorio universe e instalar herramientas esenciales y Java 8 y 17
RUN sed -i 's/main/main universe/g' /etc/apt/sources.list \
    && apt-get update && apt-get install -y --no-install-recommends \
    curl \
    wget \
    git \
    jq \
    unzip \
    screen \
    tmux \
    procps \
    lsof \
    ca-certificates \
    python3 \
    python3-minimal \
    openjdk-8-jre-headless \
    openjdk-17-jre-headless \
    && rm -rf /var/lib/apt/lists/*

# 3. Instalar Java 21 (Eclipse Temurin JRE oficial de Adoptium en /opt/java-21)
RUN mkdir -p /opt/java-21 \
    && curl -SsL "https://api.adoptium.net/v3/binary/latest/21/ga/linux/x64/jre/hotspot/normal/eclipse" -o /tmp/temurin21.tar.gz \
    && tar -xzf /tmp/temurin21.tar.gz -C /opt/java-21 --strip-components=1 \
    && rm -f /tmp/temurin21.tar.gz \
    && chmod -R a+rX /opt/java-21 \
    && /opt/java-21/bin/java -version

# Por defecto java apunta a Java 17
RUN update-alternatives --set java /usr/lib/jvm/java-17-openjdk-amd64/bin/java || true

# 4. Instalar cliente oficial de Playit.gg
RUN curl -SsL "https://github.com/playit-cloud/playit-agent/releases/latest/download/playit-linux-amd64" -o /usr/local/bin/playit \
    && chmod a+rx /usr/local/bin/playit

# 5. Usuario por defecto
USER codespace
WORKDIR /workspaces/playcode-minecraft-server
