"""lib/i18n.py — los mismos textos que lib/i18n.sh, para los scripts de Python.

Los scripts de Python (verificación dentro de Windows, escribir por teclado, clics)
también tienen que hablar español e inglés. Aquí se leen los MISMOS ficheros que
usa lib/i18n.sh (lib/i18n/<idioma>.txt y lib/i18n/<idioma>.d/*.txt), con el mismo
formato (CLAVE=Texto, % -> %%, salto de línea -> \\n) y el mismo orden de idioma:

    1. la variable de entorno KEMPER_LANG (es|en)
    2. la clave IDIOMA= del fichero config/kemper-vm.conf
    3. el idioma del sistema ($LC_ALL, $LANG): es* -> español; si no, inglés

Uso:
    from i18n import msg, msgln

    msgln("TITULO_1")             # devuelve el texto + "\\n"
    print(msg("PENDIENTE", res))  # con argumentos, formato tipo printf

· msg()   devuelve el texto SIN salto de línea final.
· msgln() devuelve el texto CON salto de línea final.
Los dos DEVUELVEN la cadena (no imprimen): así el que llama decide si va a
stdout o a stderr con print(..., file=sys.stderr).
Si falta una clave, se devuelve "[[CLAVE]]" y se avisa por stderr, igual que en
la versión de shell (una traducción incompleta nunca rompe nada).
"""

import os
import sys

# lib/ está dentro del proyecto: la raíz es la carpeta de arriba.
RAIZ = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))

_TEXTOS = None
_IDIOMA = None


def _idioma_sistema():
    l = os.environ.get("LC_ALL") or os.environ.get("LANG") or "en"
    return "es" if l[:2].lower() == "es" else "en"


def _leer(ruta, textos):
    """Lee CLAVE=Texto de un fichero (si existe) y los vuelca en el diccionario."""
    if not os.path.isfile(ruta):
        return
    try:
        with open(ruta, encoding="utf-8") as f:
            for linea in f:
                linea = linea.rstrip("\r\n")
                if linea.lstrip().startswith("#") or "=" not in linea:
                    continue
                clave, valor = linea.split("=", 1)
                clave = "".join(clave.split())      # clave sin espacios
                if clave:
                    textos[clave] = valor
    except OSError:
        pass


def _leer_carpeta(d, textos):
    """Lee todos los .txt de una carpeta (si existe), en orden alfabético."""
    if not os.path.isdir(d):
        return
    for nombre in sorted(os.listdir(d)):
        if nombre.endswith(".txt"):
            _leer(os.path.join(d, nombre), textos)


def _elegir_idioma():
    idioma = os.environ.get("KEMPER_LANG") or ""
    if not idioma:
        try:
            if os.path.join(RAIZ, "lib") not in sys.path:
                sys.path.insert(0, os.path.join(RAIZ, "lib"))
            from config import leer_conf
            idioma = leer_conf().get("IDIOMA", "")
        except Exception:
            idioma = ""
    if not idioma:
        idioma = _idioma_sistema()
    return idioma if idioma in ("es", "en") else "en"


def _cargar():
    global _TEXTOS, _IDIOMA
    if _TEXTOS is not None:
        return
    _IDIOMA = _elegir_idioma()
    textos = {}
    # Siempre el inglés primero (respaldo) y luego el idioma elegido, que pisa
    # lo anterior. Se leen también las carpetas <idioma>.d/.
    _leer(os.path.join(RAIZ, "lib", "i18n", "en.txt"), textos)
    _leer_carpeta(os.path.join(RAIZ, "lib", "i18n", "en.d"), textos)
    if _IDIOMA != "en":
        _leer(os.path.join(RAIZ, "lib", "i18n", _IDIOMA + ".txt"), textos)
        _leer_carpeta(os.path.join(RAIZ, "lib", "i18n", _IDIOMA + ".d"), textos)
    _TEXTOS = textos


def _unescapar(t):
    """Convierte \\n, \\t y \\r a los caracteres reales, como hace printf en el shell."""
    return t.replace("\\n", "\n").replace("\\t", "\t").replace("\\r", "\r")


def msg(clave, *args):
    """Devuelve el texto de la clave (con argumentos, formato tipo printf)."""
    _cargar()
    texto = _TEXTOS.get(clave, "")
    if not texto:
        sys.stderr.write(
            "i18n: falta el texto de la clave '%s' en %s.txt\n" % (clave, _IDIOMA)
        )
        return "[[%s]]" % clave
    texto = _unescapar(texto)
    if args:
        return texto % args
    return texto


def msgln(clave, *args):
    """Igual que msg, pero añadiendo salto de línea final."""
    return msg(clave, *args) + "\n"