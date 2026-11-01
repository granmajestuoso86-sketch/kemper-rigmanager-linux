#!/usr/bin/env bash
# =============================================================================
#  70-instalar-lanzador.sh — pone el lanzador en el menú de Ubuntu
#
#  No necesita root (instala en ~/.local). Crea:
#     ~/.local/bin/kemper-rig-manager              (enlace al lanzador)
#     ~/.local/share/icons/hicolor/scalable/apps/kemper-rig-manager.svg
#     ~/.local/share/applications/kemper-rig-manager.desktop
#  y refresca la caché de iconos y la base de datos del menú.
#
#  Uso:  scripts/70-instalar-lanzador.sh
# =============================================================================
set -euo pipefail

PROYECTO="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
source "$PROYECTO/lib/config.sh"
cfg_cargar

source "$PROYECTO/lib/i18n.sh"
i18n_cargar

BIN="$HOME/.local/bin"
ICONOS="$HOME/.local/share/icons/hicolor/scalable/apps"
APPS="$HOME/.local/share/applications"

mkdir -p "$BIN" "$ICONOS" "$APPS"

chmod +x "$PROYECTO/scripts/kemper-rig-manager"
ln -sfn "$PROYECTO/scripts/kemper-rig-manager" "$BIN/kemper-rig-manager"
msgln ENLACE_CREADO "$BIN"

# ICONO: el oficial de Rig Manager (rombo KEMPER, 256x256 con transparencia).
# No es un fichero suelto del programa: vive dentro de
#   C:\WINDOWS\Installer\{...}\RigManagerIcon.exe
# y se extrajo con wrestool/icotool. Se guarda en icono/rig-manager/ para que un
# despliegue futuro no tenga que volver a sacarlo de la maquina virtual.
# Se instala en VARIOS tamaños porque el menú, la barra de tareas y el
# conmutador de ventanas piden tamaños distintos.
ORIGEN="$PROYECTO/icono/rig-manager/rig-manager-256.png"   # el oficial (no se redistribuye)
PROPIO="$PROYECTO/icono/kemper-rig-manager.svg"              # el nuestro (siempre está en el repositorio)
TAMANOS="256 128 96 64 48 32 24 16"

# El icono es DECORATIVO: que falle no puede tumbar la instalación del lanzador
# (fallo real: un fichero de icono ausente abortó la fase 7 entera con "no he
# podido instalar el lanzador", que no era lo que pasaba).
#
# Se instalan SIEMPRE los tamaños PNG (256, 128, ... 16) porque cada sitio pide
# uno distinto y no todos los escritorios manejan bien los iconos vectoriales.
# - Si está el PNG oficial, se escala él (mejor dibujo).
# - Si no, se escala NUESTRO SVG. Esto último faltaba: antes, sin el PNG oficial
#   sólo se copiaba el SVG suelto, sin generar tamaños, así que el respaldo era
#   más frágil que el camino bueno. Lo pidió el usuario tras verlo en su Debian.
if [[ -f "$ORIGEN" ]]; then
  for s in $TAMANOS; do
    d="$HOME/.local/share/icons/hicolor/${s}x${s}/apps"
    mkdir -p "$d"
    convert "$ORIGEN" -resize ${s}x${s} -strip "$d/kemper-rig-manager.png" 2>/dev/null \
      || cp -f "$ORIGEN" "$d/kemper-rig-manager.png"
  done
  msgln ICONO_OFICIAL
elif [[ -f "$PROPIO" ]]; then
  # El SVG se copia TAMBIÉN (es el que mejor se vea a tamaños raros)
  cp -f "$PROPIO" "$ICONOS/kemper-rig-manager.svg" 2>/dev/null || true
  hecho=no
  if command -v convert >/dev/null 2>&1; then
    for s in $TAMANOS; do
      d="$HOME/.local/share/icons/hicolor/${s}x${s}/apps"
      mkdir -p "$d"
      if convert -background none -resize ${s}x${s} "$PROPIO" "$d/kemper-rig-manager.png" 2>/dev/null; then
        hecho=si
      else
        rm -f "$d/kemper-rig-manager.png"      # no dejar un PNG a medias
      fi
    done
  fi
  if [[ "$hecho" == "si" ]]; then msgln ICONO_PROPIO_PNG; else msgln ICONO_PROPIO_SVG; fi
else
  msgln AVISO_SIN_ICONO
fi
# Refrescar la caché del tema: sin esto, algunos escritorios no ven el icono
# nuevo hasta que cierras sesión. Es barato y evita un "no sale el icono".
command -v gtk-update-icon-cache >/dev/null 2>&1 && \
  gtk-update-icon-cache -q -t -f "$HOME/.local/share/icons/hicolor" 2>/dev/null || true

# La entrada del menú se genera desde la PLANTILLA (kemper-rig-manager.desktop.in),
# porque lleva la ruta real del lanzador de este usuario: los ficheros .desktop no
# expanden $HOME. Y como todo lo decorativo, si falta la plantilla se avisa pero no
# se tumba la instalación (el lanzador ya está puesto y funciona desde la terminal).
PLANTILLA="$PROYECTO/kemper-rig-manager.desktop.in"
if [[ -f "$PLANTILLA" ]]; then
  if sed "s|@LANZADOR@|$BIN/kemper-rig-manager|" "$PLANTILLA" > "$APPS/kemper-rig-manager.desktop"; then
    msgln MENU_OK "$APPS/kemper-rig-manager.desktop"
  else
    msgln MENU_AVISO
  fi
else
  msgln MENU_SIN_PLANTILLA "$PLANTILLA"
fi
msgln ENTRADA_MENU "$APPS"

# Refrescar cachés (sin root; si fallan, no es grave)
command -v gtk-update-icon-cache >/dev/null && gtk-update-icon-cache -q -t -f "$HOME/.local/share/icons/hicolor" 2>/dev/null || true
command -v update-desktop-database >/dev/null && update-desktop-database -q "$APPS" 2>/dev/null || true

# --- virt-viewer: quitar su confirmacion al cerrar la ventana ----------------
# Si no se quita, al cerrar la ventana sale su propio dialogo ("Do you want to
# close the session?") ANTES del nuestro ("Apago Windows?"), y parece que el
# lanzador no pregunta nada. No hay opcion de linea de comandos: solo su fichero
# de ajustes. Virt-viewer puede reescribirlo, por eso el lanzador lo reasegura.
FVV="$HOME/.config/virt-viewer/settings"
mkdir -p "$(dirname "$FVV")"
[[ -f "$FVV" ]] || printf '[virt-viewer]\nshare-clipboard=true\nask-quit=false\n' > "$FVV"
grep -q '^\[virt-viewer\]' "$FVV" || sed -i '1i [virt-viewer]' "$FVV"
if grep -q '^ask-quit=' "$FVV"; then sed -i 's/^ask-quit=.*/ask-quit=false/' "$FVV"
else sed -i '/^\[virt-viewer\]/a ask-quit=false' "$FVV"; fi
msgln VIRTVIEWER_CONFIRMACION

echo
msgln COMPROBACIONES
printf "   %-16s %s\n" "$(msg ETIQUETA_LANZADOR)" "$([[ -x "$BIN/kemper-rig-manager" ]] && msg TEXTO_EJECUTABLE || msg TEXTO_REVISAR)"
printf "   %-16s %s\n" "$(msg ETIQUETA_ICONO)" "$( { [ -f "$HOME/.local/share/icons/hicolor/scalable/apps/kemper-rig-manager.svg" ] || [ -f "$HOME/.local/share/icons/hicolor/256x256/apps/kemper-rig-manager.png" ]; } && msg TEXTO_PRESENTE || msg TEXTO_REVISAR)"
printf "   %-16s %s\n" "$(msg ETIQUETA_MENU)"     "$([[ -f "$APPS/kemper-rig-manager.desktop" ]] && msg TEXTO_PRESENTE || msg TEXTO_REVISAR)"
echo
msgln MENU_CERRAR_SESION
msgln PRUEBA_RAPIDA "$BIN"