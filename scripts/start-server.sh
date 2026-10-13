#!/usr/bin/env bash
# ==============================================================================
# Play Code — Minecraft Server Master Launcher (Self-Healing)
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
SERVER_DIR="$BASE_DIR/server"
CONFIG_DIR="$BASE_DIR/config"

mkdir -p "$SERVER_DIR"

# 0. Verificación y auto-reparación de dependencias básicas
if ! command -v playit >/dev/null 2>&1; then
    echo "[!] Playit no encontrado. Instalando cliente de emergencia..."
    sudo curl -SsL "https://github.com/playit-cloud/playit-agent/releases/latest/download/playit-linux-amd64" -o /usr/local/bin/playit 2>/dev/null || true
    sudo chmod a+rx /usr/local/bin/playit 2>/dev/null || true
fi

# 1. Determinar versión de Minecraft (desde LMS o variable de entorno)
CONFIG_URL="https://edu.playcode.com.ar/wp-json/playcode/v1/minecraft-config"

if [ -n "${PLAYCODE_USER_ID:-}" ]; then
    LOOKUP_QUERY="user_id=${PLAYCODE_USER_ID}"
    echo "[+] Consultando versión para user_id ${PLAYCODE_USER_ID}..."
else
    LOOKUP_QUERY="codespace=${CODESPACE_NAME}&login=${GITHUB_USER}"
    echo "[+] Fallback: consultando versión por codespace/login ($LOOKUP_QUERY)..."
fi

LMS_VERSION=$(curl -s --connect-timeout 5 "${CONFIG_URL}?${LOOKUP_QUERY}" 2>/dev/null | grep -o '"version":"[^"]*"' | head -n 1 | cut -d'"' -f4 || true)

MC_VERSION="${LMS_VERSION:-${MINECRAFT_VERSION:-${MC_VERSION:-1.21.1}}}"
echo "=========================================================="
echo " [>] PLAY CODE MINECRAFT SERVER LAUNCHER"
echo " [>] Versión solicitada: $MC_VERSION"
echo "=========================================================="

# 2. Descargar o verificar PaperMC
echo "[+] Comprobando PaperMC versión $MC_VERSION..."
python3 "$SCRIPT_DIR/download-paper.py" "$MC_VERSION" "$SERVER_DIR"

# 3. Aceptar EULA automáticamente
echo "eula=true" > "$SERVER_DIR/eula.txt"

# 4. Configurar server.properties inicial si no existe
if [ ! -f "$SERVER_DIR/server.properties" ]; then
    echo "[+] Aplicando configuración optimizada en server.properties..."
    cp "$CONFIG_DIR/server.properties.template" "$SERVER_DIR/server.properties"
fi

# 5. Seleccionar la versión de Java adecuada
MAJOR=$(echo "$MC_VERSION" | cut -d. -f2)
PATCH=$(echo "$MC_VERSION" | cut -d. -f3)
[ -z "$PATCH" ] && PATCH=0

JAVA_BIN="java"

if [ "$MAJOR" -le 16 ]; then
    echo "[+] Minecraft <= 1.16 detectado: Seleccionando Java 8"
    if [ -x "/usr/lib/jvm/java-8-openjdk-amd64/bin/java" ]; then
        JAVA_BIN="/usr/lib/jvm/java-8-openjdk-amd64/bin/java"
    elif [ -x "/usr/lib/jvm/java-8-openjdk/bin/java" ]; then
        JAVA_BIN="/usr/lib/jvm/java-8-openjdk/bin/java"
    else
        echo "[!] Instalando Java 8 de emergencia..."
        sudo apt-get update && sudo apt-get install -y openjdk-8-jre-headless
        JAVA_BIN="/usr/lib/jvm/java-8-openjdk-amd64/bin/java"
    fi
elif [ "$MAJOR" -ge 21 ] || { [ "$MAJOR" -eq 20 ] && [ "$PATCH" -ge 5 ]; }; then
    echo "[+] Minecraft 1.20.5+ detectado: Seleccionando Java 21"
    if [ -x "/opt/java-21/bin/java" ]; then
        JAVA_BIN="/opt/java-21/bin/java"
    elif [ -x "/usr/lib/jvm/java-21-openjdk-amd64/bin/java" ]; then
        JAVA_BIN="/usr/lib/jvm/java-21-openjdk-amd64/bin/java"
    else
        echo "[!] Descargando Java 21 Temurin de emergencia..."
        sudo mkdir -p /opt/java-21
        sudo curl -SsL "https://api.adoptium.net/v3/binary/latest/21/ga/linux/x64/jre/hotspot/normal/eclipse" -o /tmp/temurin21.tar.gz
        sudo tar -xzf /tmp/temurin21.tar.gz -C /opt/java-21 --strip-components=1
        sudo rm -f /tmp/temurin21.tar.gz
        sudo chmod -R a+rX /opt/java-21
        JAVA_BIN="/opt/java-21/bin/java"
    fi
else
    echo "[+] Minecraft 1.17 - 1.20.4 detectado: Seleccionando Java 17"
    if [ -x "/usr/lib/jvm/java-17-openjdk-amd64/bin/java" ]; then
        JAVA_BIN="/usr/lib/jvm/java-17-openjdk-amd64/bin/java"
    elif [ -x "/usr/lib/jvm/java-17-openjdk/bin/java" ]; then
        JAVA_BIN="/usr/lib/jvm/java-17-openjdk/bin/java"
    else
        echo "[!] Instalando Java 17 de emergencia..."
        sudo apt-get update && sudo apt-get install -y openjdk-17-jre-headless
        JAVA_BIN="/usr/lib/jvm/java-17-openjdk-amd64/bin/java"
    fi
fi

echo "[+] Binario Java seleccionado: $JAVA_BIN"
"$JAVA_BIN" -version 2>&1 | head -n 1

# 6. Iniciar túnel de Play Code (FRP hacia Google Cloud) si no está corriendo
if ! pgrep -f "frpc" >/dev/null 2>&1; then
    echo "[+] Levantando túnel FRP con Google Cloud Relay..."
    bash "$SCRIPT_DIR/frp-service.sh" || true
fi

# 7. Iniciar Service Control API en puerto 9000 si no está corriendo
if ! pgrep -f "service-control.py" >/dev/null 2>&1; then
    echo "[+] Levantando Service Control API (puerto 9000)..."
    nohup python3 "$SCRIPT_DIR/service-control.py" > /tmp/service_control.log 2>&1 &
fi

# 8. Arrancar servidor de Minecraft si no está corriendo
if ! pgrep -f "server.jar" >/dev/null 2>&1; then
    echo "[+] Iniciando Minecraft PaperMC en background con 5GB de RAM..."
    cd "$SERVER_DIR"
    if command -v tmux >/dev/null 2>&1; then
        tmux new-session -d -s minecraft "$JAVA_BIN -Xms2G -Xmx5G -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1ReservePercent=20 -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 -XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem -XX:MaxTenuringThreshold=1 -jar server.jar --nogui"
    else
        nohup "$JAVA_BIN" -Xms2G -Xmx5G \
            -XX:+UseG1GC \
            -XX:+ParallelRefProcEnabled \
            -XX:MaxGCPauseMillis=200 \
            -XX:+UnlockExperimentalVMOptions \
            -XX:+DisableExplicitGC \
            -XX:+AlwaysPreTouch \
            -XX:G1NewSizePercent=30 \
            -XX:G1MaxNewSizePercent=40 \
            -XX:G1ReservePercent=20 \
            -XX:G1HeapWastePercent=5 \
            -XX:G1MixedGCCountTarget=4 \
            -XX:InitiatingHeapOccupancyPercent=15 \
            -XX:G1MixedGCLiveThresholdPercent=90 \
            -XX:G1RSetUpdatingPauseTimePercent=5 \
            -XX:SurvivorRatio=32 \
            -XX:+PerfDisableSharedMem \
            -XX:MaxTenuringThreshold=1 \
            -jar server.jar --nogui > /tmp/minecraft.log 2>&1 &
    fi
    sleep 3
    echo "[+] Servidor de Minecraft iniciado con éxito."
else
    echo "[+] El servidor de Minecraft ya se encuentra en ejecución."
fi

echo "=========================================================="
echo " [✓] PLAY CODE LAB LISTO"
echo " [✓] Control API & Web: http://localhost:9000"
echo " [✓] Minecraft Port: 25565"
echo "=========================================================="
