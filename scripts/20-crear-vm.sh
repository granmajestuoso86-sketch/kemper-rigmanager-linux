#!/usr/bin/env bash
# =============================================================================
#  20-crear-vm.sh — prepara el disco y define el dominio de la VM
#
#  No necesita root, pero SÍ pertenecer al grupo 'libvirt' (lo hace
#  00-setup-root.sh; hay que cerrar sesión y volver a entrar).
#
#  Hace:
#    1. Define un grupo de almacenamiento de libvirt ("kemper") y le pide AL
#       DEMONIO que cree el disco de 80 GB. No se usa qemu-img a mano porque
#       /var/lib/libvirt/images sólo lo puede escribir root: la API de libvirt
#       crea el fichero como root y libvirt le da el propietario correcto
#       (libvirt-qemu) al arrancar la máquina.
#    2. GENERA config/<nombre-de-tu-vm>.xml desde config/vm-domain.xml.in
#       (plantilla) y define el dominio con él. Es IDEMPOTENTE: si el
#       dominio ya existe, reutiliza su UUID (si no, libvirt generaría uno nuevo
#       y protestaría por el conflicto).
#    3. Deja un enlace al disco dentro del proyecto (vm/).
#  NO arranca la máquina.
# =============================================================================
set -euo pipefail

PROYECTO="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
# Toda la configuración (nombre de la VM, RAM, núcleos, disco, rutas de los ISO)
# vive en config/kemper-vm.conf: este script no sabe nada de tu máquina.
source "$PROYECTO/lib/config.sh"
cfg_cargar
source "$PROYECTO/lib/i18n.sh"
i18n_cargar

# Ruta completa del disco de esta VM (el cargador define VM_DIR y VOL)
DISCO="$VM_DIR/$VOL"

# --- Definición de la VM: se GENERA desde la plantilla -----------------------
# Las rutas de OVMF, del disco y de los dos ISO cambian de una máquina a otra;
# la plantilla lleva marcadores @...@ y aquí se sustituyen.
generar_xml() {
  local s plantilla="$PROYECTO/config/vm-domain.xml.in"
  [[ -f "$plantilla" ]] || { msgln CREAR_ERR_PLANTILLA "$plantilla" >&2; return 1; }
  s="$(cat "$plantilla")"
  s="${s//@VM_NOMBRE@/$VM_NOMBRE}"
  s="${s//@RAM_MB@/$VM_RAM_MB}"
  s="${s//@VCPUS@/$VM_VCPUS}"
  s="${s//@VM_DIR@/$VM_DIR}"
  s="${s//@VOL@/$VOL}"
  s="${s//@PROYECTO@/$PROYECTO}"
  s="${s//@ISO_WINDOWS@/$ISO_WINDOWS}"
  printf '%s\n' "$s" > "$XML"
  # OJO: con 'set -euo pipefail' (arriba), un grep que NO encuentra nada
  # devuelve 1 y aborta el script. Este grep es el caso normal (no quedan
  # marcadores), así que va protegido con '|| true'. Pasó de verdad: el script
  # moría en silencio justo aquí.
  local resto; resto="$(grep -o '@[A-Z_]\+@' "$XML" 2>/dev/null | sort -u | tr '\n' ' ' || true)"
  [[ -z "$resto" ]] || msgln CREAR_AVISO_MARCADORES "$resto" >&2
}

if [[ "${1:-}" == "--generar-xml" ]]; then
  # Modo seguro: genera y valida la definición SIN crear nada.
  cfg_cargar
  msgln CREAR_GEN
  generar_xml
  msgln CREAR_FICHERO "$XML"
  if command -v virt-xml-validate >/dev/null 2>&1; then
    if virt-xml-validate "$XML" domain >/dev/null 2>&1; then
      msgln CREAR_VALIDADA
    else
      msgln CREAR_NO_VALIDA >&2
      virt-xml-validate "$XML" domain 2>&1 | sed 's/^/   /' >&2
      exit 1
    fi
  fi
  echo
  msgln CREAR_NOMBRE "$VM_NOMBRE"
  msgln CREAR_RAM "$VM_RAM_MB" "$VM_VCPUS"
  msgln CREAR_DISCO "$VM_DISCO_GB" "$VM_DIR"
  msgln CREAR_ISO "$ISO_WINDOWS"
  exit 0
fi

generar_xml
msgln CREAR_DEF_GEN "$XML"
if command -v virt-xml-validate >/dev/null 2>&1; then
  virt-xml-validate "$XML" domain >/dev/null 2>&1 \
    && msgln CREAR_VALIDADA \
    || msgln CREAR_AVISO_NOVALIDA >&2
fi
cfg_exigir_medios || exit 1

SIMULACRO=no
[[ "${1:-}" == "--simulacro" ]] && SIMULACRO=si

# Todas las órdenes que CAMBIAN algo pasan por aquí. En modo simulacro se
# imprimen en vez de ejecutarse: así se recorre la lógica entera (incluido el
# trozo que define el dominio) sin tocar el sistema. Hace falta: un fallo real
# -"DOMINIO: unbound variable" al definir el dominio- no se detectó porque la
# única prueba disponible salía antes de llegar ahí.
v() {
  if [[ "$SIMULACRO" == "si" ]]; then
    case "$1" in
      pool-define-as|pool-build|pool-start|pool-autostart|vol-create-as|define)
        msgln CREAR_SIMULACRO "$*"; return 0 ;;
    esac
  fi
  virsh -c "$URI" "$@"
}
# En simulacro, "no existe todavía" para que recorra el camino de creación
v_existe() {
  [[ "$SIMULACRO" == "si" ]] && return 1
  virsh -c "$URI" "$@" >/dev/null 2>&1
}

msgln CREAR_PREVIAS
command -v virsh >/dev/null || { msgln CREAR_ERR_VIRSH; exit 1; }
v list --all >/dev/null 2>&1 || {
  msgln CREAR_ERR_LIBVIRT "$URI" >&2
  msgln CREAR_ERR_LIBVIRT_H1 >&2
  msgln CREAR_ERR_LIBVIRT_H2 >&2
  exit 1
}
msgln CREAR_LIBVIRT_OK

echo
msgln CREAR_P1
if v_existe pool-info "$POOL"; then
  msgln CREAR_POOL_EXISTE "$POOL"
else
  v pool-define-as "$POOL" dir --target "$VM_DIR" | sed 's/^/   /'
  v pool-build     "$POOL" >/dev/null
  v pool-start     "$POOL" >/dev/null
  v pool-autostart "$POOL" >/dev/null 2>&1 || true
  msgln CREAR_POOL_CREADO "$POOL"
fi
v pool-list --all 2>/dev/null | sed 's/^/   /' || true

if v_existe vol-info --pool "$POOL" "$VOL"; then
  msgln CREAR_DISCO_EXISTE "$DISCO"
else
  v vol-create-as "$POOL" "$VOL" "${VM_DISCO_GB}G" --format qcow2 | sed 's/^/   /'
fi
v vol-info --pool "$POOL" "$VOL" 2>/dev/null | sed 's/^/   /' || true

echo
msgln CREAR_P2
tmp="$(mktemp)"
if v dominfo "$DOMINIO" >/dev/null 2>&1; then
  uuid="$(v dominfo "$DOMINIO" | awk '/^UUID:/{print $2}')"
  if grep -q '<uuid>' "$XML"; then
    sed "s|<uuid>[^<]*</uuid>|<uuid>$uuid</uuid>|" "$XML" > "$tmp"
  else
    awk -v u="$uuid" '{print} /<name>/{print "  <uuid>" u "</uuid>"}' "$XML" > "$tmp"
  fi
  msgln CREAR_DOM_EXISTE "$uuid"
  v define "$tmp" | sed 's/^/   /'
else
  cp "$XML" "$tmp"
  v define "$tmp" | sed 's/^/   /'
fi
rm -f "$tmp"
v list --all 2>/dev/null | sed 's/^/   /' || true

echo
msgln CREAR_P3
if [[ "$SIMULACRO" == "si" ]]; then
  msgln CREAR_SIM_ENLACE "$PROYECTO" "$VOL" "$DISCO"
else
  mkdir -p "$PROYECTO/vm"
  ln -sfn "$DISCO" "$PROYECTO/vm/$VOL"
fi
[[ "$SIMULACRO" == "si" ]] || msgln CREAR_ENLACE "$PROYECTO" "$VOL" "$DISCO"

echo
if [[ "$SIMULACRO" == "si" ]]; then
  echo
  msgln CREAR_SIM_NADA
fi
msgln CREAR_LISTO