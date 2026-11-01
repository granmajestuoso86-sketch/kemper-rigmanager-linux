#!/usr/bin/env bash
# =============================================================================
#  00-setup-root.sh  —  Rig Manager VM / Kemper en Ubuntu
# -----------------------------------------------------------------------------
#  ÚNICA acción con privilegios de TODO el proyecto. Idempotente: se puede
#  volver a ejecutar tantas veces como haga falta sin romper nada.
#
#  Ejecutar ASÍ (te pedirá tu contraseña; no me la pases a mí):
#
#    sudo bash scripts/00-setup-root.sh
#
#  Qué hace:
#    1. Instala la plataforma de virtualización (QEMU/KVM, libvirt, virt-manager,
#       OVMF UEFI, swtpm para TPM 2.0, xorriso para construir el ISO de instalación).
#    2. Añade tu usuario a los grupos libvirt y kvm.
#    3. Activa el demonio libvirt y la red NAT "default".
#    4. Crea el directorio de discos de la VM y da a QEMU (usuario libvirt-qemu)
#       permiso de LECTURA sobre los medios del proyecto (ISO de Windows, ISO
#       generado). Sin esto, libvirt (que corre como otro usuario) no puede
#       abrir el ISO porque tu carpeta personal no le deja entrar
#       no es atravesable por otros usuarios.
#    5. Imprime un resumen de verificación.
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

# El usuario de verdad: el que lanzó sudo. NADA de nombres incrustados (aquí
# antes había aquí un nombre de usuario fijo, heredado de la máquina donde se
# desarrolló: si
# alguien lo ejecutaba desde un shell de root, intentaba añadir al grupo a un
# usuario que no existe en su equipo).
USUARIO="${SUDO_USER:-$(logname 2>/dev/null || true)}"
if [[ -z "$USUARIO" || "$USUARIO" == "root" ]]; then
  msgln SETUP_ERR_SIN_USUARIO >&2
  msgln SETUP_ERR_SIN_USUARIO_SUDO >&2
  msgln SETUP_ERR_SIN_USUARIO_ORDEN >&2
  exit 1
fi
VM_DISKS="$VM_DIR"
QEMU_USER="libvirt-qemu"

if [[ ${EUID} -ne 0 ]]; then
  msgln SETUP_ERR_ROOT "$0" >&2
  exit 1
fi
if ! id "$USUARIO" >/dev/null 2>&1; then
  msgln SETUP_ERR_USUARIO "$USUARIO" >&2
  exit 1
fi

msgln SETUP_RAYA
msgln SETUP_TITULO
msgln SETUP_CAB_DATOS "$USUARIO" "$PROYECTO"
msgln SETUP_RAYA

# --- 1. Paquetes -------------------------------------------------------------
echo
msgln SETUP_P1
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq

CORE=(
  qemu-system-x86
  qemu-utils
  libvirt-daemon-system
  libvirt-clients
  virtinst
  ovmf
  swtpm
  swtpm-tools
  xorriso
  acl
  qemu-system-modules-spice
  qemu-system-modules-opengl
  curl              # descargar el ISO de virtio-win si no lo aportas tú
  python3           # lo usan la construcción del medio y las herramientas de verificación
  p7zip-full        # 7z: extrae los drivers y el agente del ISO de virtio,
                    # y comprueba el contenido del medio construido
)
OPT=(
  virt-manager
  virt-viewer
  spice-client-gtk
  gir1.2-spiceclientgtk-3.0
  gir1.2-libvirt-glib-1.0
  python3-libvirt
  dnsmasq-base
  qemu-system-gui
  cpu-checker
  zenity            # diálogos gráficos del lanzador (opcional; sin él, sale texto)
  imagemagick       # redimensionar el icono y medir el brillo de la pantalla del setup
  usbutils          # lsusb: diagnóstico del Kemper
  gtk-update-icon-cache   # refrescar la caché de iconos tras instalar el lanzador
  desktop-file-utils      # refrescar el menú de aplicaciones
)

msgln SETUP_NUCLEO "${CORE[*]}"
apt-get install -y "${CORE[@]}"

msgln SETUP_OPC
for p in "${OPT[@]}"; do
  if apt-get install -y "$p" >/dev/null 2>&1; then
    msgln SETUP_OK_PAQ "$p"
  else
    msgln SETUP_AVISO_PAQ "$p"
  fi
done

# --- 2. Grupos ---------------------------------------------------------------
echo
msgln SETUP_P2
before="$(id -nG "$USUARIO")"
usermod -aG libvirt,kvm "$USUARIO"
after="$(id -nG "$USUARIO")"
msgln SETUP_GRUPOS_ANTES "$before"
msgln SETUP_GRUPOS_AHORA "$after"

# --- 3. Servicio y red -------------------------------------------------------
echo
msgln SETUP_P3
systemctl enable --now libvirtd 2>/dev/null || systemctl enable --now libvirtd.socket
systemctl is-active libvirtd.service >/dev/null 2>&1 && msgln SETUP_LIBVIRTD_ACTIVO \
  || msgln SETUP_LIBVIRTD_REVISAR

msgln SETUP_REDES
virsh net-list --all || msgln SETUP_AVISO_VIRSH

if virsh net-info default >/dev/null 2>&1; then
  virsh net-autostart default >/dev/null 2>&1 || true
  virsh net-start default >/dev/null 2>&1 || true
  msgln SETUP_RED_ESTADO
  virsh net-list --all | grep -E '^\s*default' || true
else
  msgln SETUP_AVISO_RED
fi

# --- 4. Almacenamiento y permisos -------------------------------------------
echo
msgln SETUP_P4
install -d -m 0711 -o root -g root "$VM_DISKS"
msgln SETUP_DISCOS "$VM_DISKS"

# QEMU (qemu:///system) corre como $QEMU_USER: necesita ATRAVESAR el home y
# LEER los medios. Se concede con ACL (no se cambian los permisos del home).
if id "$QEMU_USER" >/dev/null 2>&1; then
  # Atravesar el home (solo 'x', no 'r': no se puede listar nada)
  for d in "/home/$USUARIO" "/home/$USUARIO/Documentos" "$PROYECTO"; do
    if [[ -d "$d" ]]; then setfacl -m "u:${QEMU_USER}:x" "$d" || true; fi
  done
  # Leer los medios (ISO de Windows, ISO generada, payload).
  # OJO: los DIRECTORIOS necesitan 'x' (permiso de paso) además de 'r'. Un
  # 'setfacl -R -m u:X:r' deja a los directorios sin 'x' y QEMU no puede abrir
  # ningún fichero de dentro. Por eso se distinguen ficheros y directorios.
  for d in "$PROYECTO/install" "$PROYECTO/config" "$PROYECTO/ISO WIN y rigManager"; do
    if [[ -d "$d" ]]; then
      setfacl -m "u:${QEMU_USER}:rx" "$d" || true
      find "$d" -mindepth 1 -type d -exec setfacl -m "u:${QEMU_USER}:rx" {} + 2>/dev/null || true
      find "$d" -mindepth 1 -type f -exec setfacl -m "u:${QEMU_USER}:r"  {} + 2>/dev/null || true
    fi
  done
  msgln SETUP_ACL "$QEMU_USER"
else
  msgln SETUP_AVISO_QEMUUSER "$QEMU_USER"
fi

# --- 5. Verificación --------------------------------------------------------
echo
msgln SETUP_P5
msgln SETUP_KVM
if [[ -r /dev/kvm && -w /dev/kvm ]]; then msgln SETUP_KVM_OK; else msgln SETUP_KVM_NO; fi
if command -v kvm-ok >/dev/null 2>&1; then kvm-ok 2>&1 | sed 's/^/   /'; fi
msgln SETUP_VERSIONES
virsh --version                              | sed 's/^/   virsh          /'
qemu-system-x86_64 --version | head -1       | sed 's/^/   qemu           /'
swtpm --version 2>/dev/null | head -1        | sed 's/^/   swtpm          /'
msgln SETUP_UEFI
ls /usr/share/OVMF/OVMF_CODE*.fd 2>/dev/null    | sed 's/^/   /' || msgln SETUP_AVISO_OVMF
msgln SETUP_GUI
for b in virt-manager virt-viewer virsh virt-install qemu-img xorriso; do
  msg SETUP_HERRAMIENTA "$b" "$(command -v $b || msg SETUP_NO_HERRAMIENTA)"
done
msgln SETUP_RED_DEFAULT
virsh net-list --all 2>/dev/null | sed 's/^/   /' || true

echo
msgln SETUP_RAYA
msgln SETUP_FIN1
msgln SETUP_FIN2
msgln SETUP_FIN3
msgln SETUP_FIN4
msgln SETUP_FIN5
msgln SETUP_RAYA