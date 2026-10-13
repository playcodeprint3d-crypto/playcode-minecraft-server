#!/usr/bin/env python3
"""
Play Code — PaperMC Auto-Downloader
Downloads any PaperMC Minecraft server version from 1.8.8 to 1.21.x using the official v3 API.
"""

import sys
import os
import json
import urllib.request
import urllib.error

API_BASE = "https://fill.papermc.io/v3/projects/paper"

def get_latest_build(version):
    url = f"{API_BASE}/versions/{version}/builds"
    req = urllib.request.Request(url, headers={"User-Agent": "PlayCode-Minecraft/1.0"})
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            if not data or not isinstance(data, list):
                raise ValueError(f"No builds found for version {version}")
            # Last item in the list is the latest build
            latest = data[-1]
            build_id = latest.get("id")
            downloads = latest.get("downloads", {})
            server_default = downloads.get("server:default") or downloads.get("server:mojang")
            if not server_default or "url" not in server_default:
                raise ValueError(f"Download URL not found in build {build_id}")
            return build_id, server_default["name"], server_default["url"], server_default.get("size", 0)
    except Exception as e:
        print(f"[-] Error fetching build metadata for Paper {version}: {e}", file=sys.stderr)
        return None, None, None, None

def download_jar(download_url, dest_path, expected_size=0):
    print(f"[+] Descargando PaperMC desde {download_url}...")
    req = urllib.request.Request(download_url, headers={"User-Agent": "PlayCode-Minecraft/1.0"})
    with urllib.request.urlopen(req, timeout=60) as resp, open(dest_path, "wb") as f:
        downloaded = 0
        block_size = 65536
        while True:
            chunk = resp.read(block_size)
            if not chunk:
                break
            f.write(chunk)
            downloaded += len(chunk)
            if expected_size > 0:
                percent = (downloaded / expected_size) * 100
                sys.stdout.write(f"\r[+] Descargando: {percent:.1f}% ({downloaded // (1024*1024)} MB)")
                sys.stdout.flush()
    print(f"\n[+] Descarga completada exitosamente: {dest_path}")

def main():
    version = sys.argv[1] if len(sys.argv) > 1 else "1.20.4"
    dest_dir = sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.getcwd(), "server")
    os.makedirs(dest_dir, exist_ok=True)
    target_jar = os.path.join(dest_dir, "server.jar")
    version_file = os.path.join(dest_dir, ".installed_version")

    # Si ya está descargada la versión exacta y existe server.jar, no volver a descargar
    if os.path.exists(target_jar) and os.path.exists(version_file):
        with open(version_file, "r") as f:
            installed = f.read().strip()
        if installed == version and os.path.getsize(target_jar) > 10000000:
            print(f"[+] PaperMC versión {version} ya está instalada y lista.")
            return 0

    print(f"[+] Buscando build oficial de PaperMC para Minecraft {version}...")
    build_id, filename, download_url, size = get_latest_build(version)
    if not download_url:
        print(f"[-] No se pudo encontrar el build para {version}. Abortando.", file=sys.stderr)
        return 1

    temp_jar = target_jar + ".tmp"
    download_jar(download_url, temp_jar, size)
    os.replace(temp_jar, target_jar)

    with open(version_file, "w") as f:
        f.write(version)

    print(f"[+] Servidor PaperMC {version} (Build #{build_id}) preparado correctamente.")
    return 0

if __name__ == "__main__":
    sys.exit(main())
