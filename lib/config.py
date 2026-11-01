"""Lee config/kemper-vm.conf — el mismo fichero que usa lib/config.sh.

Los scripts de Python (verificación dentro de Windows, intercambio de ficheros,
clics) necesitan saber cómo se llama la máquina virtual. Ese nombre lo elige el
usuario en su configuración, así que aquí se lee de ahí en vez de llevarlo
incrustado (antes estaba fijo en "kemper-win11" y eso ataba el proyecto a una
instalación concreta).
"""
import os
import re

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def leer_conf(ruta=None):
    ruta = ruta or os.path.join(RAIZ, "config", "kemper-vm.conf")
    datos = {}
    try:
        with open(ruta, encoding="utf-8") as f:
            for linea in f:
                linea = linea.rstrip("\r\n")
                if not linea.strip() or linea.lstrip().startswith("#") or "=" not in linea:
                    continue
                clave, valor = linea.split("=", 1)
                valor = valor.split(" #", 1)[0].strip()
                valor = valor.strip().strip('"').strip("'")
                datos[clave.strip()] = valor
    except OSError:
        pass
    return datos


def nombre_vm():
    """Nombre de la VM: variable de entorno DOMINIO > configuración > por defecto."""
    return (os.environ.get("DOMINIO")
            or leer_conf().get("VM_NOMBRE")
            or "kemper-win11")
