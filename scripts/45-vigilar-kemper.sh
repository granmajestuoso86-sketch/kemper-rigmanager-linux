#!/usr/bin/env bash
# =============================================================================
#  45-vigilar-kemper.sh - conecta el Kemper a la VM EN CUANTO aparece.
#
#  Por que existe: el orden de encendido no deberia importar. Si arrancas Windows
#  antes de encender el Kemper, el aparato no esta y no se conecta; y si lo
#  enciendes despues, ya nadie lo mira. Este vigilante comprueba cada 3 s
#  mientras la maquina este en marcha y lo conecta en cuanto lo ve.
#
#  Lo lanza el lanzador en segundo plano. Tambien se puede ejecutar a mano.
# =============================================================================
set -uo pipefail
export LC_ALL=C

SCRIPT="$(readlink -f "${BASH_SOURCE[0]}")"
PROYECTO="$(cd "$(dirname "$SCRIPT")/.." && pwd)"
# --- Configuración de ESTA máquina ------------------------------------------
# Nombre de la VM, RAM, disco y rutas de los medios viven en
# config/kemper-vm.conf; este script no lleva ninguna ruta dentro.
source "$PROYECTO/lib/config.sh"
cfg_cargar

source "$PROYECTO/lib/i18n.sh"
i18n_cargar

DOM="${DOMINIO:-$VM_NOMBRE}"
URI="qemu:///system"
HW="$PROYECTO/config/hostdev-kemper.xml"
VID="133e"; PID="0003"
LOG="$PROYECTO/logs/lanzador.log"

log() { echo "[$(date '+%F %T')] [vigilante] $*" >> "$LOG"; }

# Presente en el anfitrion = existe en sysfs. Da igual que controlador tenga:
# lo que importa es que este enchufado. (Antes exigi un controlador enlazado y
# eso dejaba fuera el caso de un aparato recien conectado.)
presente() {
  local d
  for d in /sys/bus/usb/devices/*; do
    [[ -r "$d/idVendor" ]] || continue
    if [[ "$(cat "$d/idVendor" 2>/dev/null)" == "$VID" && "$(cat "$d/idProduct" 2>/dev/null)" == "$PID" ]]; then
      return 0
    fi
  done
  return 1
}

en_vm() { virsh -c "$URI" dumpxml "$DOM" 2>/dev/null | grep -q "0x${VID}"; }

log "$(msg VIGILANTE_EN_MARCHA "$DOM")"
while virsh -c "$URI" domstate "$DOM" 2>/dev/null | grep -q running; do
  if ! en_vm && presente; then
    if virsh -c "$URI" attach-device "$DOM" "$HW" --live >/dev/null 2>&1; then
      log "$(msg VIGILANTE_KEMPER_CONECTADO)"
      sleep 8
    else
      log "$(msg VIGILANTE_KEMPER_FALLO)"
    fi
  fi
  sleep 3
done
log "$(msg VIGILANTE_VM_PARADA)"
