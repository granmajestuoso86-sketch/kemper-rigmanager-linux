#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
90-escribir.py — escribe texto DENTRO de la máquina virtual por teclado inyectado.

Por qué existe: `virsh send-key` con varias teclas las envía como ACORDE (todas
a la vez, pensado para atajos tipo Ctrl+Alt+Supr), NO como texto. Para teclear de
verdad hay que enviar una tecla detrás de otra.

Uso:
    scripts/90-escribir.py "D:\\payload\\instalar.cmd{ENTER}"
    scripts/90-escribir.py "{WIN}r"          # atajo
    scripts/90-escribir.py "hola{ENTER}"     # texto simple + Enter

Tokens entre llaves: {ENTER} {TAB} {ESC} {SPACE} {BACKSPACE} {DEL} {WIN} {CTRL}
                     {ALT} {SHIFT} {F5} {UP} {DOWN} {LEFT} {RIGHT} {HOME} {END}
En los atajos, las teclas van juntas: "{WIN}r", "{CTRL}c", "{ALT}{TAB}".
"""

import subprocess
import sys
import time

import os as _os, sys as _sys
_sys.path.insert(0, _os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "..", "lib"))
from config import nombre_vm as _nombre_vm
from i18n import msg, msgln
DOM = _os.environ.get("DOMINIO") or _nombre_vm()
URI = "qemu:///system"
PAUSA = 0.04

# letra/dígito -> nombre de tecla de QEMU
BASE = {c: f"KEY_{c.upper()}" for c in "abcdefghijklmnopqrstuvwxyz0123456789"}
BASE.update({
    " ": "KEY_SPACE", ".": "KEY_DOT", ",": "KEY_COMMA", "-": "KEY_MINUS",
    "=": "KEY_EQUAL", "/": "KEY_SLASH", "\\": "KEY_BACKSLASH", ";": "KEY_SEMICOLON",
    "'": "KEY_APOSTROPHE", "[": "KEY_LEFTBRACE", "]": "KEY_RIGHTBRACE",
    "`": "KEY_GRAVE",
})
# caracteres que exigen MAYÚSCULAS (shift + otra tecla)
SHIFT = {
    ":": "KEY_SEMICOLON", "_": "KEY_MINUS", '"': "KEY_APOSTROPHE", "+": "KEY_EQUAL",
    "(": "KEY_9", ")": "KEY_0", "<": "KEY_COMMA", ">": "KEY_DOT", "?": "KEY_SLASH",
    "!": "KEY_1", "@": "KEY_2", "#": "KEY_3", "$": "KEY_4", "%": "KEY_5",
    "^": "KEY_6", "&": "KEY_7", "*": "KEY_8", "{": "KEY_LEFTBRACE",
    "}": "KEY_RIGHTBRACE", "|": "KEY_BACKSLASH", "~": "KEY_GRAVE",
}
TOKENS = {
    "ENTER": "KEY_ENTER", "TAB": "KEY_TAB", "ESC": "KEY_ESC", "SPACE": "KEY_SPACE",
    "BACKSPACE": "KEY_BACKSPACE", "DEL": "KEY_DELETE", "WIN": "KEY_LEFTMETA",
    "CTRL": "KEY_LEFTCTRL", "ALT": "KEY_LEFTALT", "SHIFT": "KEY_LEFTSHIFT",
    "F5": "KEY_F5", "F12": "KEY_F12", "UP": "KEY_UP", "DOWN": "KEY_DOWN",
    "LEFT": "KEY_LEFT", "RIGHT": "KEY_RIGHT", "HOME": "KEY_HOME", "END": "KEY_END",
}


def enviar(teclas):
    """Envía una lista de nombres de tecla COMO ACORDE (a la vez)."""
    cmd = ["virsh", "-c", URI, "send-key", DOM, "--holdtime", "40"] + list(teclas)
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        print(msg("AVISO_ESCRIBIR", r.stderr.strip()), file=sys.stderr)
    return r.returncode == 0


def teclear(texto):
    """Teclea el texto carácter a carácter. Devuelve cuántas pulsaciones hizo."""
    n = 0
    i = 0
    while i < len(texto):
        ch = texto[i]
        if ch == "{":
            fin = texto.find("}", i)
            if fin > 0:
                token = texto[i + 1:fin].upper()
                if token in TOKENS:
                    enviar([TOKENS[token]])
                    n += 1
                    i = fin + 1
                    time.sleep(PAUSA)
                    continue
        if ch in BASE:
            enviar([BASE[ch]])
        elif ch in SHIFT:
            enviar(["KEY_LEFTSHIFT", SHIFT[ch]])      # acorde = mayúscula/símbolo
        elif ch.isupper() and ch.lower() in BASE:
            enviar(["KEY_LEFTSHIFT", BASE[ch.lower()]])
        else:
            print(msg("AVISO_CARACTER", repr(ch)), file=sys.stderr)
            i += 1
            continue
        n += 1
        i += 1
        time.sleep(PAUSA)
    return n


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(msg("USO_ESCRIBIR"))
        sys.exit(2)
    texto = sys.argv[1]
    print(msg("TECLEANDO", len(texto)))
    pulsaciones = teclear(texto)
    print(msg("HECHO", pulsaciones))
