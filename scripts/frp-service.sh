#!/usr/bin/env bash
# ==============================================================================
# Play Code — Fast Reverse Proxy Client (frpc) Manager
# Conecta el servidor de Minecraft en Codespaces directamente al Relay de Google Cloud
# ==============================================================================
set -e

FRP_BIN="/usr/local/bin/frpc"
STATUS_FILE="/tmp/tunnel_status.json"
LOG_FILE="/tmp/frpc.log"
CONFIG_FILE="/tmp/frpc.toml"

FRP_SERVER="${FRP_SERVER_ADDR:-35.209.249.255}"
FRP_PORT="${FRP_SERVER_PORT:-7000}"
FRP_TOKEN="${FRP_AUTH_TOKEN:-PlayCodeMcSecret2026!}"
REMOTE_PORT="${FRP_REMOTE_PORT:-25565}"
CLIENT_NAME="${FRP_CLIENT_NAME:-mc-$(hostname | cut -c 1-12)}"

# 0. Consultar configuración dinámica desde la plataforma Play Code
CONFIG_URL="https://edu.playcode.com.ar/wp-json/playcode/v1/minecraft-config"
LOOKUP_QUERY="codespace=${CODESPACE_NAME}&login=${GITHUB_USER}"
echo "[+] Consultando configuración de red en Play Code LMS ($LOOKUP_QUERY)..."
CFG_JSON=$(curl -s --connect-timeout 4 "$CONFIG_URL?$LOOKUP_QUERY" || true)

if [ -n "$CFG_JSON" ]; then
    FETCH_PORT=$(echo "$CFG_JSON" | grep -o '"port":[0-9]*' | head -n 1 | cut -d: -f2 || true)
    FETCH_HOST=$(echo "$CFG_JSON" | grep -o '"relay_host":"[^"]*"' | head -n 1 | cut -d'"' -f4 || true)
    if [ -n "$FETCH_PORT" ]; then
        REMOTE_PORT="$FETCH_PORT"
    fi
    if [ -n "$FETCH_HOST" ]; then
        FRP_SERVER="$FETCH_HOST"
    fi
fi

echo "[+] Relay Host: $FRP_SERVER | Puerto Remoto Asignado: $REMOTE_PORT"

# 1. Instalar binario de frpc si no existe
if [ ! -x "$FRP_BIN" ]; then
    echo "[+] Descargando cliente oficial de FRP (frpc)..."
    TMP_DIR=$(mktemp -d)
    curl -SsL "https://github.com/fatedier/frp/releases/download/v0.61.0/frp_0.61.0_linux_amd64.tar.gz" -o "$TMP_DIR/frp.tar.gz"
    tar -xzf "$TMP_DIR/frp.tar.gz" -C "$TMP_DIR"
    sudo mv "$TMP_DIR"/frp_*/frpc /usr/local/bin/
    sudo chmod +x /usr/local/bin/frpc
    rm -rf "$TMP_DIR"
fi

# 2. Generar configuración TOML
echo "[+] Generando configuración de FRP hacia $FRP_SERVER:$FRP_PORT..."
cat > "$CONFIG_FILE" << EOF
serverAddr = "$FRP_SERVER"
serverPort = $FRP_PORT

auth.method = "token"
auth.token = "$FRP_TOKEN"

[[proxies]]
name = "$CLIENT_NAME"
type = "tcp"
localIP = "127.0.0.1"
localPort = 25565
remotePort = $REMOTE_PORT
transport.useEncryption = true
transport.useCompression = true
EOF

# 3. Matar instancias previas y arrancar en segundo plano
pkill -f "frpc" 2>/dev/null || true
sleep 1

echo "[+] Conectando túnel FRP con el Relay de Play Code..."
nohup "$FRP_BIN" -c "$CONFIG_FILE" > "$LOG_FILE" 2>&1 &
FRP_PID=$!
sleep 2

# 4. Verificar si arrancó exitosamente
if kill -0 $FRP_PID 2>/dev/null; then
    echo "[+] Túnel FRP activo con PID: $FRP_PID"
    if [ "$REMOTE_PORT" -eq 25565 ]; then
        PUBLIC_CONN="$FRP_SERVER"
    else
        PUBLIC_CONN="$FRP_SERVER:$REMOTE_PORT"
    fi
    echo "{\"type\": \"frp\", \"status\": \"online\", \"server\": \"$FRP_SERVER\", \"port\": $REMOTE_PORT, \"public_address\": \"$PUBLIC_CONN\", \"last_updated\": $(date +%s)}" > "$STATUS_FILE"
    echo "=========================================================="
    echo " [✓] TÚNEL DE PLAY CODE (GOOGLE CLOUD) CONECTADO"
    echo " [✓] Dirección directa de Minecraft: $PUBLIC_CONN"
    echo "=========================================================="
else
    echo "[-] Error iniciando frpc. Revisa $LOG_FILE"
    cat "$LOG_FILE"
    exit 1
fi

exit 0
