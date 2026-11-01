#!/usr/bin/env bash
# =============================================================================
#  10-build-install-iso.sh — construye el medio de instalación desatendida
#
#  Genera install/kemper-install.iso con:
#     /autounattend.xml   (lo que Windows busca al arrancar del DVD)
#     /payload/           (MSI de Rig Manager, virtio-win-gt, qemu-ga,
#                          instalar.cmd, instalar.ps1)
#
#  Etiqueta del volumen: KEMPERINSTALL
#  No necesita root. Necesita xorriso (lo instala 00-setup-root.sh).
# =============================================================================
set -euo pipefail

PROYECTO="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
source "$PROYECTO/lib/config.sh"
cfg_cargar
source "$PROYECTO/lib/i18n.sh"
i18n_cargar
INSTALL="$PROYECTO/install"
ISO="$INSTALL/kemper-install.iso"

command -v xorriso >/dev/null 2>&1 || { msgln BUILD_ERR_XORRISO >&2; exit 1; }
[[ -f "$INSTALL/autounattend.xml.in" ]] || { msgln BUILD_ERR_AU >&2; exit 1; }
[[ -d "$INSTALL/payload" ]]          || { msgln BUILD_ERR_PAYLOAD >&2; exit 1; }
cfg_exigir_medios || exit 1

msgln BUILD_P1
# La plantilla del repositorio no lleva dentro ni contraseña ni clave: se
# rellena aquí, en tu máquina, y el resultado (install/autounattend.xml) está
# en .gitignore para que no se publique nunca.
AU="$INSTALL/autounattend.xml"
MSG_CLAVE_ETIQUETA="$(msg BUILD_CLAVE_ETIQUETA)"
MSG_CLAVE_INCLUIDA="$(msg BUILD_CLAVE_INCLUIDA)"
MSG_CLAVE_SIN="$(msg BUILD_CLAVE_SIN)"
export MSG_CLAVE_ETIQUETA MSG_CLAVE_INCLUIDA MSG_CLAVE_SIN
python3 - "$INSTALL/autounattend.xml.in" "$AU" <<'PYFIN'
import sys
plantilla, destino = sys.argv[1], sys.argv[2]
t = open(plantilla, encoding='utf-8').read()
ed = __import__('os').environ
t = t.replace('@EDICION_WINDOWS@', ed['EDICION_WINDOWS'])
t = t.replace('@CUENTA_USUARIO@', ed['CUENTA_USUARIO'])
t = t.replace('@CUENTA_CLAVE@',   ed['CUENTA_CLAVE'])
t = t.replace('@NOMBRE_EQUIPO@',  'KEMPER-VM')
t = t.replace('@VM_NOMBRE@',      ed['VM_NOMBRE'])
clave = ed.get('CLAVE_PRODUCTO', '').strip()
if clave:
    bloque = ('<ProductKey>\n        <Key>%s</Key>\n        <WillShowUI>Never</WillShowUI>\n      </ProductKey>' % clave)
else:
    # SIN clave (opción elegida): se mantiene el bloque con WillShowUI=Never y
    # sin <Key>, que es lo que impide que el asistente se pare pidiéndola.
    # Windows queda sin activar; funciona igual (con marca de agua).
    bloque = ('<ProductKey>\n        <WillShowUI>Never</WillShowUI>\n      </ProductKey>')
t = t.replace('@BLOQUE_CLAVE@', bloque)
open(destino, 'w', encoding='utf-8').write(t)
print(ed['MSG_CLAVE_ETIQUETA'], ed['MSG_CLAVE_INCLUIDA'] if clave else ed['MSG_CLAVE_SIN'])
PYFIN
grep -c 'WillShowUI' "$AU" >/dev/null && msgln BUILD_AU_OK "$AU"

echo
msgln BUILD_P2
# El MSI de Rig Manager: se copia con su nombre original; el instalador lo
# busca por patrón, así que cualquier versión vale.
[[ -d "$INSTALL/payload" ]] || mkdir -p "$INSTALL/payload"
cp -f "$INSTALADOR_RIGMANAGER" "$INSTALL/payload/" && \
  msgln BUILD_RM "$(basename "$INSTALADOR_RIGMANAGER")"
# Los dos MSI de virtio/qemu-ga salen del ISO de virtio-win (se descarga o lo
# aportas tú): nunca se guardan en el repositorio.
# El ISO de virtio puede venir de dos sitios: la ruta de la configuración
# (VIRTIO_ISO) O la fase 2, que lo descarga a install/virtio-win.iso cuando el
# usuario pulsa Enter. Sin esto, descargar 880 MB no servía para nada: la fase 3
# no lo encontraba y decía que faltaban los drivers. Fallo real, contado por un
# usuario que siguió justo ese camino.
if [[ -z "${VIRTIO_ISO:-}" || ! -f "${VIRTIO_ISO:-}" ]]; then
  if [[ -f "$INSTALL/virtio-win.iso" ]]; then
    VIRTIO_ISO="$INSTALL/virtio-win.iso"
    msgln BUILD_VIRTIO_DESCARGADO "$VIRTIO_ISO"
  fi
fi

for m in virtio-win-gt-x64.msi qemu-ga-x86_64.msi; do
  if [[ -f "$INSTALL/payload/$m" ]]; then msgln BUILD_YA_ESTABA "$m"; continue; fi
  if [[ -n "${VIRTIO_ISO:-}" && -f "${VIRTIO_ISO:-}" ]] && command -v 7z >/dev/null 2>&1; then
    # -ir! = búsqueda RECURSIVA dentro del ISO: el de qemu-ga no está en la
    # raíz sino en una subcarpeta (guest-agent/). Sin -ir! no lo encontraba y
    # el agente de invitado faltaba: se quedaba en "AVISO" y nadie se enteraba.
    7z e -y -ir!"$m" -o"$INSTALL/payload" "$VIRTIO_ISO" >/dev/null 2>&1 \
      && msgln BUILD_EXTRAIDO "$m" \
      || msgln BUILD_AVISO_EXTRAER "$m" "$VIRTIO_ISO"
  else
    msgln BUILD_AVISO_FALTA_M "$m"
  fi
done

# --- Nada de avisos silenciosos: el medio O TIENE TODO, O NO SE CONSTRUYE ----
# Si faltaba un .msi, el script avisaba y seguía: se construía un medio
# incompleto (sin drivers de virtio y sin agente de invitado), Windows arrancaba
# y la verificación posterior fallaba sin que se entendiera por qué. Fallo real,
# detectado en la primera prueba en un sistema limpio.
faltan=()
ls "$INSTALL/payload/"Rig_Manager*.msi >/dev/null 2>&1 || faltan+=("el instalador de Rig Manager")
[[ -f "$INSTALL/payload/virtio-win-gt-x64.msi" ]] || faltan+=("virtio-win-gt-x64.msi (drivers)")
[[ -f "$INSTALL/payload/qemu-ga-x86_64.msi" ]]     || faltan+=("qemu-ga-x86_64.msi (agente de invitado)")
if (( ${#faltan[@]} > 0 )); then
  echo >&2
  msgln BUILD_ERR_INCOMPLETO >&2
  for f in "${faltan[@]}"; do msgln BUILD_ERR_FALTA_ITEM "$f" >&2; done
  echo >&2
  msgln BUILD_ERR_MSI "$INSTALADOR_RIGMANAGER" >&2
  msgln BUILD_ERR_VIRTIO1 >&2
  msgln BUILD_ERR_VIRTIO2 >&2
  exit 1
fi
# Resolucion de pantalla pedida en la configuracion. Viaja como fichero de texto
# al lado del payload (payload/resolucion.txt) y el instalador de Windows lo lee:
# asi el mismo instalar.ps1 sirve con o sin resolucion fija. Con 'auto' no se
# escribe nada y Windows usa la suya.
rm -f "$INSTALL/payload/resolucion.txt"
if [[ "${RESOLUCION_VM:-auto}" =~ ^[0-9]+x[0-9]+$ ]]; then
  printf '%s\n' "$RESOLUCION_VM" > "$INSTALL/payload/resolucion.txt"
  msgln BUILD_RESOLUCION "$RESOLUCION_VM"
fi

msgln BUILD_PAYLOAD_OK
cd "$INSTALL"
rm -f "$ISO"

# -joliet-long: nombres largos (el MSI se llama "Rig_Manager_4_3_13_Windows 64-bit.msi")
# -graft-points: cada argumento es "ruta_dentro_del_ISO=origen".
# SIN esto, xorriso mete el CONTENIDO de payload/ en la RAÍZ del ISO en vez de
# en payload/. Costó un fallo silencioso: la orden del fichero de respuestas
# busca payload\instalar.cmd y no lo habría encontrado nunca.
xorriso -as mkisofs \
  -volid KEMPERINSTALL \
  -joliet -joliet-long -rational-rock \
  -input-charset utf-8 \
  -graft-points \
  -o "$ISO" \
  /autounattend.xml=autounattend.xml \
  /payload=payload \
  >/dev/null

msgln BUILD_ISO "$(ls -lh "$ISO" | awk '{print $5"  "$9}')"
echo
# La comprobación se hace con 7z, necesario para VERIFICAR pero no para
# construir. Sin este 'if', un sistema sin 7z abortaba aquí: fallo real en un
# sistema limpio, donde el ISO se construía bien y la fase se daba por fallida.
if command -v 7z >/dev/null 2>&1; then
  msgln BUILD_CONTENIDO
  7z l "$ISO" 2>/dev/null | grep -E 'autounattend[.]xml|payload/(instalar|Rig_Manager|virtio-win-gt|qemu-ga)' | sed 's/^/   /' || true
  echo
  msgln BUILD_ETIQUETA
  7z l "$ISO" 2>/dev/null | sed -n '3p' | sed 's/^/   /' || true
else
  msgln BUILD_AVISO_7Z1
  msgln BUILD_AVISO_7Z2
fi