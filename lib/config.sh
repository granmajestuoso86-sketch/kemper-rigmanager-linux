# shellcheck shell=bash
# =============================================================================
#  Cargador ÚNICO de configuración. Lo usan todos los scripts:
#      source "$PROYECTO/lib/config.sh"
#      cfg_cargar                 # carga config/kemper-vm.conf (o los valores
#                                 # por defecto, si no existe todavía)
#      cfg_exigir_medios          # comprueba que están el ISO y el instalador
# =============================================================================
#  Motivo de existir: al principio cada script llevaba sus rutas dentro (el
#  proyecto vivía en una carpeta concreta de una máquina concreta, y con la
#  ISO de una versión concreta). Eso hacía imposible compartirlo. Aquí vive
#  TODO lo que cambia de un usuario a otro; los scripts no saben nada de rutas.
# =============================================================================

# Valores por defecto (nombres en español por claridad, se exportan como los
# que esperan los scripts).
: "${VM_NOMBRE:=kemper-win11}"
: "${VM_RAM_MB:=6144}"
: "${VM_VCPUS:=4}"
: "${VM_DISCO_GB:=80}"
: "${RESOLUCION_VM:=auto}"          # auto | 1920x1200 | ...
: "${EDICION_WINDOWS:=Windows 11 IoT Enterprise LTSC 2024}"
: "${CUENTA_USUARIO:=kemper}"
: "${CUENTA_CLAVE:=}"
: "${CLAVE_PRODUCTO:=}"
: "${POOL:=kemper}"
: "${VM_DISCO_DIR:=/var/lib/libvirt/images}"
: "${VID_KEMPER:=133e}"
: "${PID_KEMPER:=0003}"
: "${ISO_WINDOWS:=}"
: "${VIRTIO_ISO:=}"
: "${INSTALADOR_RIGMANAGER:=}"

conf_cargado="no"

# Los idiomas: si el script que nos carga no los ha cargado ya, los cargamos aquí.
# (cfg_exigir_medios y los avisos de configuración los ve el usuario, así que
# tienen que salir en su idioma.)
if ! declare -F msg >/dev/null 2>&1; then
  # shellcheck source=/dev/null
  [[ -f "$PROYECTO/lib/i18n.sh" ]] && source "$PROYECTO/lib/i18n.sh" && LC_ALL= i18n_cargar
fi

# Lee un fichero de configuración SIN ejecutarlo. Motivo (fallo real detectado
# al probar el cargador): con 'source', una línea como
#     EDICION_WINDOWS=Windows 11 IoT Enterprise LTSC 2024
# se parte por los espacios y el shell intenta ejecutar "11": error, y el valor
# queda mal. Además, 'source' ejecutaría cualquier orden que llevara el fichero,
# y ese fichero lo va a rellenar un usuario cualquiera. Aquí se analiza línea a
# línea: clave=valor, con comentarios y comillas opcionales.
cfg_leer_conf() {
  local f="$1" linea clave valor
  while IFS= read -r linea || [[ -n "$linea" ]]; do
    linea="${linea%$'\r'}"                              # ficheros guardados en Windows
    [[ "$linea" =~ ^[[:space:]]*# ]] && continue         # comentario entero
    [[ "$linea" =~ ^[[:space:]]*$ ]] && continue         # línea vacía
    [[ "$linea" == *=* ]] || continue
    clave="${linea%%=*}"
    valor="${linea#*=}"
    clave="${clave//[[:space:]]/}"                       # clave sin espacios
    valor="${valor%%[[:space:]]#*}"                      # fuera el comentario final
    valor="${valor#"${valor%%[![:space:]]*}"}"           # sin espacios delante
    valor="${valor%"${valor##*[![:space:]]}"}"           # sin espacios detrás
    valor="${valor%\"}"; valor="${valor#\"}"           # comillas dobles opcionales
    valor="${valor%\'}"; valor="${valor#\'}"           # comillas simples opcionales
    if [[ -n "$clave" ]]; then
      printf -v "$clave" '%s' "$valor" || continue
      export "$clave"
    fi
  done < "$f"
}

cfg_cargar() {
  local f="$PROYECTO/config/kemper-vm.conf"
  if [[ -f "$f" ]]; then
    cfg_leer_conf "$f"
    conf_cargado="si"
  fi
  # Derivados: se calculan SIEMPRE a partir de los valores de arriba, para que
  # un cambio de nombre en el .conf no deje a los scripts apuntando a otro sitio.
  DOM="$VM_NOMBRE"
  DOMINIO="$DOM"   # alias: algunos scripts antiguos y el propio entorno lo usan
  VM_DIR="$VM_DISCO_DIR/$VM_NOMBRE"     # carpeta del disco de esta VM
  VOL="$VM_NOMBRE.qcow2"                # fichero del disco
  XML="$PROYECTO/config/$VM_NOMBRE.xml" # definición de la VM
  URI="qemu:///system"
  SEGURIDAD_CLAVE_USUARIO="$CUENTA_CLAVE"  # el fichero de respuestas la necesita
  export DOM DOMINIO VM_DIR VOL XML URI
  export VM_NOMBRE VM_RAM_MB VM_VCPUS VM_DISCO_GB EDICION_WINDOWS RESOLUCION_VM
  export CUENTA_USUARIO CUENTA_CLAVE CLAVE_PRODUCTO POOL VM_DISCO_DIR
  export VID_KEMPER PID_KEMPER ISO_WINDOWS INSTALADOR_RIGMANAGER VIRTIO_ISO
}

# Se mantiene el texto largo en el idioma elegido usando la tabla de textos.
cfg_mensaje_sin_conf() {
  if declare -F msg >/dev/null 2>&1; then msgln CONF_SIN_FICHERO; return 0; fi
  cat <<'EOT'
No encuentro config/kemper-vm.conf.

Es el fichero donde van TUS rutas (el ISO de Windows y el instalador de Rig
Manager). Se crea solo con:

    ./install.sh

o a mano, copiando el ejemplo:

    cp config/kemper-vm.conf.example config/kemper-vm.conf
    # y luego edítalo con tus rutas
EOT
}

# ¿Están los medios que aporta el usuario? (solo lo exigen las fases que los usan)
cfg_exigir_medios() {
  local fallo=0
  if [[ -z "$ISO_WINDOWS" ]]; then
    msgln CONF_FALTA_ISO_DEF >&2; fallo=1
  elif [[ ! -f "$ISO_WINDOWS" ]]; then
    msgln CONF_FALTA_ISO_RUTA "$ISO_WINDOWS" >&2; fallo=1
  fi
  if [[ -z "$INSTALADOR_RIGMANAGER" ]]; then
    msgln CONF_FALTA_MSI_DEF >&2; fallo=1
  elif [[ ! -f "$INSTALADOR_RIGMANAGER" ]]; then
    msgln CONF_FALTA_MSI_RUTA "$INSTALADOR_RIGMANAGER" >&2; fallo=1
  fi
  [[ $fallo -eq 0 ]] || { echo; cfg_mensaje_sin_conf; return 1; }
  return 0
}
