#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
90-verificar-windows.py — VERIFICACIÓN OBJETIVA DENTRO DEL INVITADO.

Pregunta al agente de invitado (qemu-ga) por el estado real de Windows, sin
ratón y sin capturas: versión del sistema, discos, red, si Rig Manager está
instalado y registrado, TPM, y el registro de la instalación automática.

Uso:
    scripts/90-verificar-windows.py            # todo
    scripts/90-verificar-windows.py --kemper   # incluye la búsqueda del Kemper

Sólo stdlib. Todo lo que no pueda comprobarse se informa como PENDIENTE:
este script no inventa resultados.
"""

import base64
import json
import subprocess
import sys
import time

# El dominio se puede cambiar por entorno, para poder verificar la maquina de
# prueba (DOMINIO=kemper-prueba) sin duplicar el script.
import os
import sys as _sys2, os as _os2
_sys2.path.insert(0, _os2.path.join(_os2.path.dirname(_os2.path.abspath(__file__)), "..", "lib"))
from config import nombre_vm as _nombre_vm
from i18n import msg, msgln
DOM = _os2.environ.get("DOMINIO") or _nombre_vm()
URI = "qemu:///system"


def qga(command, arguments=None):
    """Ejecuta un RPC del agente de invitado. Devuelve (ok, resultado)."""
    payload = {"execute": command}
    if arguments:
        payload["arguments"] = arguments
    cmd = ["virsh", "-c", URI, "qemu-agent-command", DOM, json.dumps(payload)]
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
    if r.returncode != 0:
        return False, (r.stdout + r.stderr).strip()
    try:
        return True, json.loads(r.stdout)
    except json.JSONDecodeError:
        return True, r.stdout.strip()


def exec_en_guest(comando, timeout=90):
    """Ejecuta un comando dentro de Windows y devuelve (código, salida)."""
    ok, res = qga("guest-exec", {
        "path": "powershell.exe",
        "arg": ["-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", comando],
        "capture-output": True,
    })
    if not ok:
        return None, msg("GEXEC_NO_DISPONIBLE", res)
    pid = res.get("return", {}).get("pid")
    if not pid:
        return None, msg("GEXEC_SIN_PID", res)
    limite = time.time() + timeout
    while time.time() < limite:
        ok2, st = qga("guest-exec-status", {"pid": pid})
        if not ok2:
            return None, st
        d = st.get("return", {})
        if d.get("exited"):
            out = base64.b64decode(d.get("out-data", "")).decode("utf-8", "replace").strip()
            err = base64.b64decode(d.get("err-data", "")).decode("utf-8", "replace").strip()
            return d.get("exitcode"), (out or err)
        time.sleep(2)
    return None, msg("GEXEC_TIMEOUT")


def titulo(t):
    print()
    print("=" * 66)
    print(f" {t}")
    print("=" * 66)


# Hallazgos que impiden dar la fase por buena. No es lo mismo que "esto está
# raro" (eso se marca REVISAR): si no está instalado el programa por el que
# hacemos todo esto, la fase NO puede pasar como buena. Fallo real de la prueba
# de fuego: el informe decía "ERROR: no encuentro el ejecutable de Rig Manager"
# y la instalación seguía adelante como si tal cosa.
FALLOS_CRITICOS = []


def main():
    incluir_kemper = "--kemper" in sys.argv

    titulo(msg("TITULO_0"))
    ok, res = qga("guest-ping")
    if not ok:
        print(msg("NO_RESPONDE", res))
        print(msg("NO_RESPONDE_NOTA"))
        return 2
    print(msg("RESPONDE_OK"))

    titulo(msg("TITULO_1"))
    ok, res = qga("guest-get-osinfo")
    if ok:
        d = res.get("return", {})
        for k in ("pretty-name", "name", "version", "kernel-release", "machine"):
            if k in d:
                print(f"  {k:>16}: {d[k]}")
    else:
        print(msg("PENDIENTE", res))

    titulo(msg("TITULO_2"))
    ok, res = qga("guest-get-fsinfo")
    if ok:
        for fs in res.get("return", []):
            nombre = fs.get("name", "?")
            fs_type = "?".join(str(x) for x in fs.get("type", [])) if isinstance(fs.get("type"), list) else fs.get("type", "?")
            total = fs.get("total-bytes", 0)
            usado = fs.get("used-bytes", 0)
            print(msg("FS_LINEA", nombre, fs_type, total/2**30, usado/2**30))
            for p in fs.get("disk", []):
                print(msg("PARTICION", p.get('index'), p.get('bus-type'), p.get('bus')))
    else:
        print(msg("PENDIENTE", res))

    titulo(msg("TITULO_3"))
    ok, res = qga("guest-network-get-interfaces")
    if ok:
        for it in res.get("return", []):
            if it.get("name") in ("lo", "Loopback Pseudo-Interface 1"):
                continue
            print(msg("INTERFAZ", it.get('name'), it.get('hardware-address')))
            for a in it.get("ip-addresses", []):
                print(f"      {a.get('ip-address')} / {a.get('prefix')}")
    else:
        print(msg("PENDIENTE", res))

    titulo(msg("TITULO_4"))
    cod, sal = exec_en_guest(
        "Get-ItemProperty HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\*,"
        "HKLM:\\SOFTWARE\\WOW6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\* "
        "-ErrorAction SilentlyContinue | Where-Object DisplayName -match 'Rig|Kemper' | "
        "Select-Object DisplayName,DisplayVersion,InstallLocation | Format-List"
    )
    if cod is None:
        print(msg("PENDIENTE", sal))
    elif not sal:
        print(msg("NO_PRODUCTO"))
        FALLOS_CRITICOS.append(msg("FALLO_RIG_MANAGER"))
    else:
        print("  " + sal.replace("\n", "\n  "))

    titulo(msg("TITULO_5"))
    cod, sal = exec_en_guest(
        "(Get-ChildItem 'C:\\Program Files','C:\\Program Files (x86)' -Recurse -Filter 'Rig*.exe' "
        "-ErrorAction SilentlyContinue | Select-Object -First 3 -ExpandProperty FullName); "
        "'--- acceso directo:'; Test-Path 'C:\\Users\\Public\\Desktop\\Rig Manager.lnk'; "
        "'--- autoarranque:'; (Get-ItemProperty 'HKLM:\\Software\\Microsoft\\Windows\\CurrentVersion\\Run' "
        "-ErrorAction SilentlyContinue).RigManager"
    )
    print("  " + (sal or msg("SIN_SALIDA")).replace("\n", "\n  ") if cod is not None else msg("PENDIENTE", sal))

    titulo(msg("TITULO_6"))
    cod, sal = exec_en_guest(
        "$t = Get-Tpm; 'TpmPresent : ' + $t.TpmPresent; 'TpmReady   : ' + $t.TpmReady; "
        "'SpecVersion: ' + (Get-CimInstance -Namespace root/cimv2/security/microsofttpm "
        "-ClassName Win32_Tpm | Select-Object -ExpandProperty SpecVersion)"
    )
    print("  " + (sal or msg("SIN_SALIDA")).replace("\n", "\n  ") if cod is not None else msg("PENDIENTE", sal))

    titulo(msg("TITULO_7"))
    cod, sal = exec_en_guest("Get-Content C:\\kemper-install.log -Tail 40 -ErrorAction SilentlyContinue")
    print("  " + (sal or msg("NO_EXISTE_REGISTRO")).replace("\n", "\n  "))

    titulo(msg("TITULO_8"))
    cod, sal = exec_en_guest(
        "Get-Process | Where-Object {$_.MainWindowTitle -ne ''} | "
        "Select-Object ProcessName,MainWindowTitle | Format-Table -AutoSize"
    )
    print("  " + (sal or msg("SIN_VENTANAS")).replace("\n", "\n  "))

    if incluir_kemper:
        titulo(msg("TITULO_9"))
        cod, sal = exec_en_guest(
            "Get-PnpDevice -ErrorAction SilentlyContinue | Where-Object InstanceId -match 'VID_133E' | "
            "Select-Object Status,Class,FriendlyName,InstanceId | Format-List"
        )
        print("  " + (sal or msg("NO_DISPOSITIVO_KEMPER")).replace("\n", "\n  "))

    titulo(msg("TITULO_FIN"))
    print(msg("FIN_NOTA"))
    print()
    if FALLOS_CRITICOS:
        print("  ==============================================================")
        print(msg("INSTALACION_NO_VALIDA"))
        for f in FALLOS_CRITICOS:
            print("    - " + f)
        print("  ==============================================================")
        print(msg("FALLO_KEMPER_NOTA"))
        return 1
    print(msg("SIN_FALLOS"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
