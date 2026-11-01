#!/usr/bin/env bash
# =============================================================================
#  50-expulsar-isos.sh — tras instalar Windows: expulsa los DVD para que la
#  máquina arranque del disco duro en lugar del medio de instalación.
#
#  Uso:  scripts/50-expulsar-isos.sh
# =============================================================================
set -uo pipefail
export LC_ALL=C

PROYECTO="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
source "$PROYECTO/lib/config.sh"
cfg_cargar

source "$PROYECTO/lib/i18n.sh"
i18n_cargar

virsh -c "$URI" dominfo "$DOM" >/dev/null 2>&1 || { msgln ERROR_DOMINIO_NO_DEFINIDO "$DOM" >&2; exit 1; }

msgln EXPULSANDO_MEDIOS
for dev in sdb sdc; do
  msg EXPULSAR_DEV "$dev"
  if virsh -c "$URI" change-media "$DOM" "$dev" --eject --config --live >/dev/null 2>&1; then
    msgln EXPULSADO
  else
    msgln AVISO_NO_EXPULSADO
  fi
done

echo
msgln ESTADO_DISCOS_XML
virsh -c "$URI" domblklist "$DOM" | sed 's/^/   /'
echo
msgln SIGUIENTE_LANZADOR
msgln EXPULSAR_REINSERTAR
echo "   virsh -c $URI change-media $DOM sdb \\"
echo "     \"$PROYECTO/install/kemper-install.iso\" --insert --config)"
