#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
95-intercambio.py — pasar ficheros entre Ubuntu y el Windows de la VM.

POR QUÉ ASÍ (y no con un disco compartido): un disco compartido habría que
formatearlo, montarlo en Linux (eso pide root cada vez) y desmontarlo antes de
arrancar. Con el AGENTE DE INVITADO que ya está instalado no hace falta nada de
eso: se lee y se escribe dentro de Windows en caliente, sin root, sin drivers y
sin carpetas de red. El agente viaja por un canal virtio-serial, no por USB, así
que tampoco estorba al Kemper.

Uso:
    scripts/95-intercambio.py enviar  <fichero_local> [ruta_en_windows]
    scripts/95-intercambio.py recibir <ruta_en_windows> <fichero_local>
    scripts/95-intercambio.py lista   [ruta_en_windows]

Ejemplos:
    scripts/95-intercambio.py enviar mi_libreria.rmbackup
        -> copia a C:\\INTERCAMBIO\\mi_libreria.rmbackup
    scripts/95-intercambio.py recibir "C:\\INTERCAMBIO\\backup.rmbackup" ./backup.rmbackup
    scripts/95-intercambio.py lista
"""

import base64
import json
import os
import subprocess
import sys
import time

import os as _os, sys as _sys
_sys.path.insert(0, _os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "..", "lib"))
from config import nombre_vm as _nombre_vm
# Textos en varios idiomas (español e inglés), los mismos ficheros que usa el
# resto del proyecto. msg()/msgln() DEVUELVEN el texto (no imprimen).
from i18n import msg, msgln
DOM = _os.environ.get("DOMINIO") or _nombre_vm()
URI = "qemu:///system"
CARPETA = r"C:\INTERCAMBIO"          # carpeta de intercambio dentro de la VM
TAM = 512 * 1024                     # tamaño de bloque


def qga(comando, argumentos=None, timeout=60):
    payload = {"execute": comando}
    if argumentos:
        payload["arguments"] = argumentos
    r = subprocess.run(
        ["virsh", "-c", URI, "qemu-agent-command", DOM, json.dumps(payload)],
        capture_output=True, text=True, timeout=timeout)
    if r.returncode != 0:
        raise RuntimeError((r.stdout + r.stderr).strip())
    salida = json.loads(r.stdout) if r.stdout.strip().startswith("{") else r.stdout.strip()
    if isinstance(salida, dict) and "error" in salida:
        raise RuntimeError(salida["error"].get("desc", str(salida)))
    return salida.get("return") if isinstance(salida, dict) else salida


def ejecutar(ps, timeout=90):
    """Ejecuta PowerShell dentro de Windows y devuelve su salida."""
    res = qga("guest-exec", {"path": "powershell.exe",
                             "arg": ["-NoProfile", "-Command", ps],
                             "capture-output": True})
    pid = res["pid"]
    fin = time.time() + timeout
    while time.time() < fin:
        d = qga("guest-exec-status", {"pid": pid})
        if d.get("exited"):
            return base64.b64decode(d.get("out-data", "")).decode("utf-8", "replace").strip()
        time.sleep(1)
    raise RuntimeError(msg("INTERCAMBIO_TIEMPO_AGOTADO"))


def preparar_carpeta():
    ejecutar(f"New-Item -ItemType Directory -Force -Path '{CARPETA}' | Out-Null; 'ok'")


def enviar(local, remoto=None):
    remoto = remoto or CARPETA + "\\" + os.path.basename(local)
    tam = os.path.getsize(local)
    preparar_carpeta()
    # OJO: guest-file-open devuelve UN NUMERO (el descriptor), no un objeto.
    h = qga("guest-file-open", {"path": remoto, "mode": "wb"})
    enviado = 0
    try:
        with open(local, "rb") as f:
            while True:
                trozo = f.read(TAM)
                if not trozo:
                    break
                qga("guest-file-write", {"handle": h,
                                         "buf-b64": base64.b64encode(trozo).decode()})
                enviado += len(trozo)
                sys.stdout.write(msg("INTERCAMBIO_ENVIANDO",
                                     enviado * 100 // max(tam, 1), enviado, tam))
                sys.stdout.flush()
    finally:
        # Se cierra SIEMPRE, incluso si falló a mitad: un descriptor abierto
        # deja el fichero bloqueado dentro de Windows ("being used by another
        # process") y no se puede volver a abrir ni borrar.
        try:
            qga("guest-file-close", {"handle": h})
        except Exception as e:
            sys.stderr.write(msgln("INTERCAMBIO_AVISO_CERRAR", e))
    sys.stdout.write(msgln("INTERCAMBIO_ENVIADO", local, remoto, enviado))
    leido = ejecutar(f"(Get-Item '{remoto}').Length")
    sys.stdout.write(msg("INTERCAMBIO_COMPROBACION", leido))
    if leido.strip() == str(tam):
        sys.stdout.write(msgln("INTERCAMBIO_OK_SUFIJO"))
    else:
        sys.stdout.write(msgln("INTERCAMBIO_NO_COINCIDE_SUFIJO"))


def recibir(remoto, local):
    h = qga("guest-file-open", {"path": remoto, "mode": "rb"})
    total = 0
    try:
        with open(local, "wb") as f:
            while True:
                d = qga("guest-file-read", {"handle": h, "count": TAM})
                trozo = base64.b64decode(d.get("buf-b64", "") or "")
                if not trozo or d.get("eof"):
                    if trozo:
                        f.write(trozo)
                        total += len(trozo)
                    break
                f.write(trozo)
                total += len(trozo)
                sys.stdout.write(msg("INTERCAMBIO_RECIBIENDO", total))
                sys.stdout.flush()
    finally:
        try:
            qga("guest-file-close", {"handle": h})
        except Exception:
            pass
    sys.stdout.write(msgln("INTERCAMBIO_RECIBIDO", remoto, local, total))


def lista(ruta=CARPETA):
    print(ejecutar(f"Get-ChildItem '{ruta}' -ErrorAction SilentlyContinue | "
                   f"Select-Object Name,Length,LastWriteTime | Format-Table -AutoSize"))


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.stdout.write(msg("INTERCAMBIO_USO"))
        sys.exit(2)
    accion = sys.argv[1]
    try:
        if accion == "enviar" and len(sys.argv) >= 3:
            enviar(sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else None)
        elif accion == "recibir" and len(sys.argv) >= 4:
            recibir(sys.argv[2], sys.argv[3])
        elif accion == "lista":
            lista(sys.argv[2] if len(sys.argv) > 2 else CARPETA)
        else:
            sys.stdout.write(msg("INTERCAMBIO_USO"))
            sys.exit(2)
    except Exception as e:
        sys.stderr.write(msgln("INTERCAMBIO_ERROR", e))
        sys.exit(1)