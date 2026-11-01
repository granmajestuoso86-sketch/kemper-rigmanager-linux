#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
90-clic.py — ratón inyectado en la máquina virtual, por coordenadas.

Por qué existe: `virsh` sólo sabe mandar TECLAS. Para pulsar botones hace falta
el ratón. La VM tiene un dispositivo de puntero ABSOLUTO (tablet USB), así que se
puede clicar en coordenadas exactas sin saber dónde estaba el puntero.

DOS TRAMPAS APRENDIDAS AQUÍ (costaron dos diagnósticos):
 1. Si se envían mover+apretar+soltar en el MISMO lote de eventos, el invitado
    ve el movimiento pero NO la pulsación: el botón queda apretado y soltado en
    el mismo instante y el sondeo del HID no llega a verlo. Hay que separar la
    orden en tres: mover, apretar (esperar ~150 ms), soltar.
 2. Un diálogo modal bloquea los clics a la ventana de debajo. Si algo no
    responde a un clic, lo primero es mirar si hay un diálogo encima.

Uso:
    scripts/90-clic.py 640 400            # clic izquierdo en (640, 400)
    scripts/90-clic.py 640 400 --derecho
    scripts/90-clic.py 640 400 --doble
"""

import json
import subprocess
import sys
import time

import os as _os, sys as _sys
_sys.path.insert(0, _os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "..", "lib"))
from config import nombre_vm as _nombre_vm
from i18n import msg, msgln
DOM = _os.environ.get("DOMINIO") or _nombre_vm()
URI = "qemu:///system"
ANCHO, ALTO = 1280, 800          # resolución del invitado
RANGO = 32767                    # máxima coordenada del puntero absoluto


def qmp(payload):
    cmd = ["virsh", "-c", URI, "qemu-monitor-command", DOM, json.dumps(payload)]
    r = subprocess.run(cmd, capture_output=True, text=True)
    return r.stdout.strip()


def enviar(eventos):
    r = qmp({"execute": "input-send-event", "arguments": {"events": eventos}})
    if "error" in r.lower():
        print(msg("AVISO_QEMU", r[:200]))


def mover(x, y):
    enviar([
        {"type": "abs", "data": {"axis": "x", "value": int(round(x * RANGO / ANCHO))}},
        {"type": "abs", "data": {"axis": "y", "value": int(round(y * RANGO / ALTO))}},
    ])
    time.sleep(0.15)


def pulsar(boton="left", mantener=0.15):
    enviar([{"type": "btn", "data": {"down": True, "button": boton}}])
    time.sleep(mantener)                      # <- clave: mantener pulsado
    enviar([{"type": "btn", "data": {"down": False, "button": boton}}])
    time.sleep(0.2)


def clic(x, y, boton="left", veces=1):
    mover(x, y)
    for n in range(veces):
        pulsar(boton)
        msgln("CLIC_DOBLE", boton, x, y) if veces == 2 else msgln("CLIC", boton, x, y)
        if n + 1 < veces:
            time.sleep(0.1)


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(msg("USO_CLIC"))
        sys.exit(2)
    x, y = int(sys.argv[1]), int(sys.argv[2])
    boton = "right" if "--derecho" in sys.argv else "left"
    veces = 2 if "--doble" in sys.argv else 1
    clic(x, y, boton, veces)
