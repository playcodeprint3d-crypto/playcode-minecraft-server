#!/usr/bin/env python3
"""
Play Code — Minecraft Service Control API & Web Panel Server (Port 9000)
Provides REST endpoints and web dashboard for WordPress plugin and student control.
Zero external pip dependencies (uses built-in http.server, socket, json, subprocess).
"""

import os
import sys
import json
import struct
import socket
import subprocess
from http.server import HTTPServer, BaseHTTPRequestHandler
import urllib.parse

PORT = 9000
SERVER_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "server"))
WEB_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "web"))
CONFIG_FILE = os.path.join(SERVER_DIR, "server.properties")
WHITELIST_FILE = os.path.join(SERVER_DIR, "whitelist.json")
PLAYIT_STATUS_FILE = "/tmp/playit_status.json"

# RCON Configuration
RCON_HOST = "127.0.0.1"
RCON_PORT = 25575
RCON_PASS = "playcode123"

def send_rcon_command(command, timeout=2.0):
    """Sends a command to Minecraft server via native RCON protocol."""
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(timeout)
        sock.connect((RCON_HOST, RCON_PORT))

        def send_packet(req_id, req_type, payload):
            encoded = payload.encode("utf-8") + b"\x00\x00"
            length = 4 + 4 + len(encoded)
            header = struct.pack("<iii", length, req_id, req_type)
            sock.sendall(header + encoded)

        def read_packet():
            raw_len = sock.recv(4)
            if not raw_len or len(raw_len) < 4:
                return 0, 0, ""
            length = struct.unpack("<i", raw_len)[0]
            data = sock.recv(length)
            req_id, req_type = struct.unpack("<ii", data[:8])
            payload = data[8:-2].decode("utf-8", errors="ignore")
            return req_id, req_type, payload

        # Step 1: Login (Type 3)
        send_packet(1, 3, RCON_PASS)
        resp_id, _, _ = read_packet()
        if resp_id == -1:
            sock.close()
            return False, "RCON Authentication failed"

        # Step 2: Send Command (Type 2)
        send_packet(2, 2, command)
        _, _, response = read_packet()
        sock.close()
        return True, response.strip()
    except Exception as e:
        return False, str(e)

def is_minecraft_running():
    try:
        output = subprocess.check_output(["pgrep", "-f", "server.jar"]).decode().strip()
        return bool(output)
    except Exception:
        return False

def read_playit_status():
    if os.path.exists(PLAYIT_STATUS_FILE):
        try:
            with open(PLAYIT_STATUS_FILE, "r") as f:
                return json.load(f)
        except Exception:
            pass
    return {"status": "offline", "claim_url": "", "public_address": ""}

def read_whitelist():
    players = []
    if os.path.exists(WHITELIST_FILE):
        try:
            with open(WHITELIST_FILE, "r") as f:
                data = json.load(f)
                if isinstance(data, list):
                    players = [p.get("name", "") for p in data if isinstance(p, dict) and "name" in p]
        except Exception:
            pass
    return players

def is_whitelist_enabled():
    if os.path.exists(CONFIG_FILE):
        try:
            with open(CONFIG_FILE, "r") as f:
                for line in f:
                    if line.strip().startswith("white-list="):
                        return line.strip().split("=")[1].lower() == "true"
        except Exception:
            pass
    return False

def get_installed_version():
    ver_file = os.path.join(SERVER_DIR, ".installed_version")
    if os.path.exists(ver_file):
        try:
            with open(ver_file, "r") as f:
                return f.read().strip()
        except Exception:
            pass
    return "1.20.4"

class RequestHandler(BaseHTTPRequestHandler):
    def _send_json(self, data, status_code=200):
        body = json.dumps(data).encode("utf-8")
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")
        self.end_headers()

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path

        if path == "/api/status":
            running = is_minecraft_running()
            status_data = {
                "server_state": "running" if running else "stopped",
                "version": get_installed_version(),
                "playit": read_playit_status(),
                "whitelist": {
                    "enabled": is_whitelist_enabled(),
                    "players": read_whitelist()
                }
            }
            self._send_json(status_data)
            return

        # Serve static web dashboard
        if path == "/" or path == "/index.html":
            file_path = os.path.join(WEB_DIR, "index.html")
            if os.path.exists(file_path):
                with open(file_path, "rb") as f:
                    content = f.read()
                self.send_response(200)
                self.send_header("Content-Type", "text/html; charset=utf-8")
                self.send_header("Content-Length", str(len(content)))
                self.end_headers()
                self.wfile.write(content)
                return

        self._send_json({"error": "Not found"}, 404)

    def do_POST(self):
        content_len = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_len).decode("utf-8") if content_len > 0 else "{}"
        try:
            payload = json.loads(body)
        except Exception:
            payload = {}

        path = self.path

        if path == "/api/whitelist/toggle":
            enabled = payload.get("enabled", True)
            cmd = "whitelist on" if enabled else "whitelist off"
            success, msg = send_rcon_command(cmd)
            self._send_json({"success": success, "message": msg, "enabled": enabled})
            return

        if path == "/api/whitelist/add":
            player = payload.get("player", "").strip()
            if not player:
                self._send_json({"success": False, "error": "Player name required"}, 400)
                return
            success, msg = send_rcon_command(f"whitelist add {player}")
            self._send_json({"success": success, "message": msg, "player": player, "players": read_whitelist()})
            return

        if path == "/api/whitelist/remove":
            player = payload.get("player", "").strip()
            if not player:
                self._send_json({"success": False, "error": "Player name required"}, 400)
                return
            success, msg = send_rcon_command(f"whitelist remove {player}")
            self._send_json({"success": success, "message": msg, "player": player, "players": read_whitelist()})
            return

        if path == "/api/command":
            cmd = payload.get("command", "").strip()
            if not cmd:
                self._send_json({"success": False, "error": "Command required"}, 400)
                return
            success, msg = send_rcon_command(cmd)
            self._send_json({"success": success, "response": msg})
            return

        if path == "/api/server/stop":
            send_rcon_command("stop")
            self._send_json({"success": True, "message": "Stopping server"})
            return

        if path == "/api/server/restart":
            send_rcon_command("stop")
            subprocess.Popen(["/bin/bash", os.path.join(os.path.dirname(__file__), "start-server.sh")])
            self._send_json({"success": True, "message": "Restarting server"})
            return

        self._send_json({"error": "Unknown action"}, 404)

def run():
    server_address = ("0.0.0.0", PORT)
    httpd = HTTPServer(server_address, RequestHandler)
    print(f"[+] Play Code Service Control API activo en puerto {PORT}...")
    httpd.serve_forever()

if __name__ == "__main__":
    run()
