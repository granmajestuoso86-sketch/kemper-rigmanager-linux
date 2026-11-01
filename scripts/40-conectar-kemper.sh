#!/usr/bin/env bash
# =============================================================================
#  40-conectar-kemper.sh — pasa el Kemper Profiler a la máquina virtual
#
#  Comprueba que el aparato está en el host, lo conecta en caliente y VERIFICA
#  las dos caras del traspaso:
#     - dentro del invitado ya no está en el anfitrión
#     - el XML del dominio ya lo declara
#  Uso:  scripts/40-conectar-kemper.sh [--desconectar]
# =============================================================================
set -uo pipefail
export LC_ALL=C

PROYECTO="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
# --- Configuración de ESTA máquina ------------------------------------------
# Nombre de la VM, RAM, disco y rutas de los medios viven en
# config/kemper-vm.conf; este script no lleva ninguna ruta dentro.
source "$PROYECTO/lib/config.sh"
cfg_cargar

source "$PROYECTO/lib/i18n.sh"
i18n_cargar

DOM="$VM_NOMBRE"
URI="qemu:///system"
HW="$PROYECTO/config/hostdev-kemper.xml"
VID="133e"; PID="0003"
ACCION="${1:-conectar}"

# ¿Quién tiene el Kemper? El aparato sigue en sysfs aunque lo tenga la VM, y
# ademas es COMPUESTO, asi que la unica pista fiable es que controlador tiene
# enlazado cada interfaz: uno real (snd-usb-audio) = esta en Linux; "usbfs" =
# lo tiene un programa de usuario (QEMU).
estado_usb_host() {
  local d i drv
  for d in /sys/bus/usb/devices/*; do
    [[ -r "$d/idVendor" ]] || continue
    if [[ "$(cat "$d/idVendor" 2>/dev/null)" == "$VID" && "$(cat "$d/idProduct" 2>/dev/null)" == "$PID" ]]; then
      for i in "$d":*; do
        [[ -e "$i/driver" ]] || continue
        drv="$(basename "$(readlink -f "$i/driver" 2>/dev/null)")"
        if [[ -n "$drv" && "$drv" != "usbfs" ]]; then echo "en-linux"; return; fi
      done
      echo "en-la-vm"
      return
    fi
  done
  echo "desconectado"
}
estado_en_vm()   { virsh -c "$URI" dumpxml "$DOM" 2>/dev/null | grep -q "0x${VID}" && echo "conectado" || echo "no"; }

case "$ACCION" in
  --desconectar)
    msgln DESCONECTANDO_KEMPER
    virsh -c "$URI" detach-device "$DOM" "$HW" --live | sed 's/^/   /'
    sleep 2
    msgln KEMPER_ESTADO_ANFITRION_VM "$(estado_usb_host)" "$(estado_en_vm)"
    msgln KEMPER_VUELTO_LINUX
    exit 0
    ;;
esac

msgln PASO_1_KEMPER_ENCHUFADO
if [[ "$(estado_usb_host)" == "desconectado" ]]; then
  msgln ERROR_NO_VEO_KEMPER "$VID" "$PID" >&2
  msgln ERROR_KEMPER_CABLE >&2
  msgln ERROR_KEMPER_LSUSB >&2
  exit 1
fi
lsusb -d "$VID:$PID" | sed 's/^/   /'

msgln PASO_2_ESTADO_VM
if ! virsh -c "$URI" domstate "$DOM" | grep -q running; then
  msgln ERROR_VM_NO_ARRANCADA "$DOM" >&2
  exit 1
fi
msgln VM_EN_MARCHA

msgln PASO_3_CONEXION_CALIENTE
if [[ "$(estado_en_vm)" == "conectado" ]]; then
  msgln KEMPER_YA_CONECTADO
else
  virsh -c "$URI" attach-device "$DOM" "$HW" --live | sed 's/^/   /'
fi

msgln PASO_4_VERIFICACION
sleep 3
msgln KEMPER_VISTO_ANFITRION "$(estado_usb_host)"
msgln KEMPER_XML_VM "$(estado_en_vm)"
if [[ "$(estado_usb_host)" == "en-la-vm" && "$(estado_en_vm)" == "conectado" ]]; then
  msgln TRASPASO_CORRECTO
else
  msgln TRASPASO_REVISAR
fi