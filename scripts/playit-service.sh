#!/usr/bin/env bash
# ==============================================================================
# Play Code — Playit.gg Background Daemon & Tunnel Manager
# ==============================================================================
set -e

PLAYIT_BIN="/usr/local/bin/playit"
STATUS_FILE="/tmp/playit_status.json"
LOG_FILE="/tmp/playit.log"
CONFIG_DIR="$HOME/.config/playit"

mkdir -p "$CONFIG_DIR" 2>/dev/null || true

# Escribir estado inicial
echo '{"status": "starting", "claim_url": "", "public_address": "", "last_updated": '$(date +%s)'}' > "$STATUS_FILE"

# Si el usuario pasó un Secret Key por variable de entorno y no hay config previa:
if [ -n "$PLAYIT_SECRET_KEY" ] && [ ! -f "$CONFIG_DIR/playit.toml" ]; then
    echo "[+] Configurando Playit con Secret Key provisto..."
    cat > "$CONFIG_DIR/playit.toml" << EOF
secret_key = "$PLAYIT_SECRET_KEY"
EOF
fi

echo "[+] Iniciando daemon de Playit.gg..."
# Matar instancias previas si existieran
pkill -f "playit" 2>/dev/null || true
sleep 1

# Iniciar daemon redirigiendo logs
nohup "$PLAYIT_BIN" run > "$LOG_FILE" 2>&1 &
PLAYIT_PID=$!
echo "[+] Playit iniciado con PID: $PLAYIT_PID"

# Bucle monitor en segundo plano para parsear claim url y dirección pública
(
    CLAIM_URL=""
    PUBLIC_ADDR=""
    
    while kill -0 $PLAYIT_PID 2>/dev/null; do
        # Buscar claim URL si aún no fue vinculado
        if [ -z "$CLAIM_URL" ]; then
            FOUND_CLAIM=$(grep -oE "https://playit.gg/claim/[a-zA-Z0-9]+" "$LOG_FILE" | head -n 1 || true)
            if [ -n "$FOUND_CLAIM" ]; then
                CLAIM_URL="$FOUND_CLAIM"
                echo "=========================================================="
                echo " [!] PLAYIT.GG REQUIERE VINCULACIÓN:"
                echo " Abre este enlace para autorizar tu servidor gratis:"
                echo " $CLAIM_URL"
                echo "=========================================================="
                echo "{\"status\": \"claim_needed\", \"claim_url\": \"$CLAIM_URL\", \"public_address\": \"\", \"last_updated\": $(date +%s)}" > "$STATUS_FILE"
            fi
        fi

        # Buscar dirección asignada (ej: *.gl.at.ply.gg:port o similar)
        FOUND_ADDR=$(grep -oE "[a-zA-Z0-9.-]+\.ply\.gg:[0-9]+" "$LOG_FILE" | tail -n 1 || true)
        if [ -z "$FOUND_ADDR" ]; then
            FOUND_ADDR=$(grep -oE "[a-zA-Z0-9.-]+\.joinmc\.link" "$LOG_FILE" | tail -n 1 || true)
        fi

        if [ -n "$FOUND_ADDR" ]; then
            PUBLIC_ADDR="$FOUND_ADDR"
            echo "{\"status\": \"active\", \"claim_url\": \"$CLAIM_URL\", \"public_address\": \"$PUBLIC_ADDR\", \"last_updated\": $(date +%s)}" > "$STATUS_FILE"
        fi

        sleep 3
    done
) &

exit 0
