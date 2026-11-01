#!/usr/bin/env bash
# =============================================================================
#  fix-perms.sh — repara los permisos que QEMU necesita sobre los medios del
#  proyecto. Se ejecuta si algún día la VM no arranca con un error de tipo
#  "Permission denied" / "Could not open ... ISO" / AppArmor / qemu: could not
#  open disk image.
#
#  Es idempotente y NO cambia los permisos de tu home (usa ACL).
#
#    sudo bash scripts/fix-perms.sh
# =============================================================================
set -euo pipefail

PROYECTO="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
# --- Configuración de ESTA máquina ------------------------------------------
# Nombre de la VM, RAM, disco y rutas de los medios viven en
# config/kemper-vm.conf; este script no lleva ninguna ruta dentro.
source "$PROYECTO/lib/config.sh"
cfg_cargar

source "$PROYECTO/lib/i18n.sh"
i18n_cargar

# Sin nombres incrustados: el usuario real es quien lanzó sudo (ver el mismo
# arreglo, y por qué, en 00-setup-root.sh).
USUARIO="${SUDO_USER:-$(logname 2>/dev/null || true)}"
[[ -n "$USUARIO" && "$USUARIO" != "root" ]] || {
  msgln ERROR_SUDO >&2
  exit 1; }
QEMU_USER="libvirt-qemu"
VM_DISKS="$VM_DIR"

[[ ${EUID} -eq 0 ]] || { msgln ERROR_ROOT "$0" >&2; exit 1; }
id "$QEMU_USER" >/dev/null 2>&1 || { msgln ERROR_NO_QEMU_USER "$QEMU_USER" >&2; exit 1; }

install -d -m 0711 -o root -g root "$VM_DISKS"

setfacl -m "u:${QEMU_USER}:x"  /home/"$USUARIO" /home/"$USUARIO"/Documentos "$PROYECTO"
# OJO: 'x' (paso) en los DIRECTORIOS, 'r' sólo en los ficheros. Con
# 'setfacl -R -m u:X:r' los directorios se quedan sin permiso de paso y QEMU no
# puede abrir los ficheros que contienen.
for d in "$PROYECTO/install" "$PROYECTO/config" "$PROYECTO/ISO WIN y rigManager"; do
  [[ -d "$d" ]] || continue
  setfacl -m "u:${QEMU_USER}:rx" "$d" || true
  find "$d" -mindepth 1 -type d -exec setfacl -m "u:${QEMU_USER}:rx" {} + 2>/dev/null || true
  find "$d" -mindepth 1 -type f -exec setfacl -m "u:${QEMU_USER}:r"  {} + 2>/dev/null || true
done

msgln PERMISOS_REPARADOS
getfacl -p "$PROYECTO" 2>/dev/null | grep -vE '^#'
echo
msgln ESTADO_DISCOS_VM "$VM_DISKS"
ls -l "$VM_DISKS" 2>/dev/null || msgln DISCOS_VACIOS