FROM mcr.microsoft.com/devcontainers/base:ubuntu-22.04

USER root
ENV DEBIAN_FRONTEND=noninteractive

# 1. Herramientas básicas de sistema
RUN apt-get update && apt-get install -y --no-install-recommends \
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
    gnupg \
    software-properties-common \
    python3 \
    python3-minimal \
    && rm -rf /var/lib/apt/lists/*

# 2. Instalar Java 8 y Java 17 (Runtimes oficiales ligeros)
RUN add-apt-repository -y universe \
    && apt-get update && apt-get install -y --no-install-recommends \
    openjdk-8-jre-headless \
    openjdk-17-jre-headless \
    && rm -rf /var/lib/apt/lists/*

# 3. Instalar Java 21 (Eclipse Temurin JRE oficial de Adoptium)
RUN mkdir -p /opt/java-21 \
    && curl -SsL "https://api.adoptium.net/v3/binary/latest/21/ga/linux/x64/jre/hotspot/normal/eclipse" -o /tmp/temurin21.tar.gz \
    && tar -xzf /tmp/temurin21.tar.gz -C /opt/java-21 --strip-components=1 \
    && rm -f /tmp/temurin21.tar.gz \
    && /opt/java-21/bin/java -version

# Por defecto el comando `java` apuntará a Java 17 (el estándar más compatible)
RUN update-alternatives --set java /usr/lib/jvm/java-17-openjdk-amd64/bin/java || true

# 4. Instalar cliente oficial de Playit.gg
RUN curl -SsL "https://github.com/playit-cloud/playit-agent/releases/latest/download/playit-linux-amd64" -o /usr/local/bin/playit \
    && chmod +x /usr/local/bin/playit

# 5. Permisos para el usuario codespace
USER codespace
WORKDIR /workspaces/playcode-minecraft-server
