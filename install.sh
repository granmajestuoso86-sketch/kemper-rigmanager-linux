#!/usr/bin/env bash
# =============================================================================
#  install.sh — INSTALADOR único de "Rig Manager de Kemper en una VM"
#
#  Para quien no es técnico: ejecuta esto y ve contestando. Nada más.
#
#      ./install.sh                 instalación guiada (te pregunta lo necesario)
#      ./install.sh --estado        dónde se quedó la instalación
#      ./install.sh --comprobar     ¿puede mi PC con esto? (no cambia nada)
#      ./install.sh --fase 5        ejecuta/repita una fase concreta
#      ./install.sh --continuar     sigue desde la fase que falte
#
#  Modo desatendido (para automatizar o para las pruebas del proyecto):
#      ./install.sh --config MI.conf --si-a-todo
#
#  Las fases son independientes y REANUDABLES: si algo falla, se arregla y se
#  sigue con las demás. Copia de seguridad de lo ya hecho: nada se borra.
# =============================================================================
set -uo pipefail
export LC_ALL=C

SCRIPT="$(readlink -f "${BASH_SOURCE[0]}")"
PROYECTO="$(cd "$(dirname "$SCRIPT")" && pwd)"
source "$PROYECTO/lib/config.sh"

# Textos en varios idiomas (español e inglés), como en el resto del proyecto.
# OJO: arriba se ha forzado LC_ALL=C (para que virsh no traduzca sus salidas) y
# eso taparía el idioma del sistema; se llama a i18n_cargar sin ese LC_ALL para
# que el idioma pueda decidirse por $LANG. KEMPER_LANG y config/kemper-vm.conf
# mandan igualmente por encima.
source "$PROYECTO/lib/i18n.sh"
LC_ALL= i18n_cargar

LOG="$PROYECTO/logs/install.log"
ESTADO="$PROYECTO/logs/estado-instalacion"
mkdir -p "$PROYECTO/logs"

CONF="$PROYECTO/config/kemper-vm.conf"
SI_A_TODO=no
FASE_PEDIDA=""
ACCION="guiada"

# ----------------------------------------------------------------------------
#  Presentación
# ----------------------------------------------------------------------------
titulo() { printf '\n\033[1m== %s\033[0m\n' "$*"; }
ok()     { printf '   \033[32m✔\033[0m %s\n' "$*"; }
aviso()  { printf '   \033[33m!\033[0m %s\n' "$*"; }
error()  { printf '   \033[31m✘\033[0m %s\n' "$*" >&2; }
morir()  { error "$*"; echo; msgln MORIR_CONTINUAR; exit 1; }
log()    { echo "[$(date '+%F %T')] $*" >> "$LOG"; }

# Comprueba que una herramienta existe ANTES de usarla, y si no, dice qué paquete
# instalarla — en vez de un "command not found" que no explica nada. (Fallo real:
# en un Debian recién puesto no hay curl, y el instalador decía "¿Tienes internet?")
exigir_comando() {
  local cmd="$1" paquete="$2" fase="$3"
  if command -v "$cmd" >/dev/null 2>&1; then return 0; fi
  error "$(msg FALTA_HERRAMIENTA "$cmd" "$paquete")"
  aviso "$(msg FALTA_HERRAMIENTA_COMO "$paquete" "$fase")"
  morir "$(msg FALTA_HERRAMIENTA_MORIR "$cmd")"
}

preguntar() {   # preguntar "texto" "valor_por_defecto"   -> devuelve el valor
  local texto="$1" por_defecto="${2:-}" respuesta
  if [[ "$SI_A_TODO" == "si" ]]; then echo "$por_defecto"; return; fi
  if [[ -n "$por_defecto" ]]; then read -r -p "   $texto [$por_defecto]: " respuesta || true
  else                            read -r -p "   $texto: " respuesta || true; fi
  echo "${respuesta:-$por_defecto}"
}

preguntar_fichero() {  # insiste hasta que el fichero existe
  local texto="$1" valor="" intento=0
  while :; do
    valor="$(preguntar "$texto")"
    if [[ -f "$valor" ]]; then echo "$valor"; return; fi
    if [[ "$SI_A_TODO" == "si" ]]; then echo "$valor"; return; fi
    if [[ -z "$valor" ]]; then error "$(msg ERROR_NADA_ESCRITO)"; fi
    if [[ -n "$valor" ]]; then error "$(msg ERROR_FICHERO_NO_ENCONTRADO "$valor")"; fi
    intento=$((intento+1)); [[ $intento -lt 5 ]] || morir "$(msg MORIR_DEMASIADOS_INTENTOS)"
  done
}

# ----------------------------------------------------------------------------
#  Fases ya hechas
# ----------------------------------------------------------------------------
fase_hecha()      { [[ -f "$ESTADO" ]] && grep -qx "$1" "$ESTADO"; }
marcar_hecha()    { grep -qx "$1" "$ESTADO" 2>/dev/null || echo "$1" >> "$ESTADO"; }
fase_pendiente()  { local f; for f in 1 2 3 4 5 6 7; do fase_hecha "$f" || { echo "$f"; return; }; done; echo ""; }

nombre_fase() {
  case "$1" in
    1) msg FASE_1_NOMBRE ;;
    2) msg FASE_2_NOMBRE ;;
    3) msg FASE_3_NOMBRE ;;
    4) msg FASE_4_NOMBRE ;;
    5) msg FASE_5_NOMBRE ;;
    6) msg FASE_6_NOMBRE ;;
    7) msg FASE_7_NOMBRE ;;
    *) msg FASE_DESCONOCIDA ;;
  esac
}

# ----------------------------------------------------------------------------
#  Comprobaciones previas: ¿puede este PC con esto?
# ----------------------------------------------------------------------------
comprobar_requisitos() {
  local problemas=0
  titulo "$(msg TITULO_PC)"

  # 1. Distribución
  if command -v apt-get >/dev/null 2>&1; then
    ok "$(msg OK_DISTRO)"
  else
    aviso "$(msg AVISO_SIN_APT)"
    aviso "$(msg AVISO_ADAPTAR)"
    problemas=$((problemas+1))
  fi

  # 2. Virtualización
  if [[ -e /dev/kvm ]]; then ok "$(msg OK_VIRT)"; else
    error "$(msg ERROR_SIN_KVM)"
    problemas=$((problemas+1)); fi
  if grep -qE 'vmx|svm' /proc/cpuinfo; then ok "$(msg OK_CPU)"; else
    error "$(msg ERROR_CPU)"; problemas=$((problemas+1)); fi

  # 3. Memoria
  local ram_total ram_libre necesita
  ram_total="$(awk '/MemTotal/{print int($2/1024)}' /proc/meminfo)"
  ram_libre="$(awk '/MemAvailable/{print int($2/1024)}' /proc/meminfo)"
  necesita=$((VM_RAM_MB + 1024))
  if [[ "$ram_libre" -ge "$necesita" ]]; then
    ok "$(msg OK_RAM "$ram_libre" "$VM_RAM_MB")"
  else
    aviso "$(msg AVISO_RAM_JUSTA "$ram_libre" "$VM_RAM_MB")"
    aviso "$(msg AVISO_RAM_CERRAR)"
    problemas=$((problemas+1))
  fi

  # 4. Disco
  local libre_gb
  libre_gb="$(df -BG --output=avail "$PROYECTO" 2>/dev/null | tail -1 | tr -dc '0-9')"
  if [[ "${libre_gb:-0}" -ge 30 ]]; then
    ok "$(msg OK_DISCO "$libre_gb")"
  else
    error "$(msg ERROR_DISCO "$libre_gb")"
    problemas=$((problemas+1))
  fi

  # 5. Herramientas que instala la fase 1
  ok "$(msg OK_FASE1_INSTALA)"

  echo
  if [[ $problemas -eq 0 ]]; then
    ok "$(msg OK_ADELANTE)"
  else
    aviso "$(msg AVISO_PROBLEMAS "$problemas")"
  fi
  return 0
}

# ----------------------------------------------------------------------------
#  La configuración: te pregunta lo que no puede saber
# ----------------------------------------------------------------------------
pedir_configuracion() {
  if [[ -f "$CONF" && "$SI_A_TODO" != "si" ]]; then
    titulo "$(msg TITULO_CONF)"
    cfg_cargar
    # La configuración puede venir de OTRA máquina: pasa siempre que alguien copia
    # la carpeta entera a otro PC (el .conf no viaja por git, pero sí en una copia
    # de carpeta). Entonces apunta a ficheros que aquí no existen y el instalador
    # fallaría más tarde con un "FALTA: el ISO...". Se detecta aquí y se rehace.
    local rota=no
    if [[ -n "${ISO_WINDOWS:-}" && ! -f "${ISO_WINDOWS:-}" ]]; then rota=si; fi
    if [[ -n "${INSTALADOR_RIGMANAGER:-}" && ! -f "${INSTALADOR_RIGMANAGER:-}" ]]; then rota=si; fi
    if [[ "$rota" == "si" ]]; then
      aviso "$(msg CONF_DE_OTRA_MAQUINA)"
      rm -f "$CONF"          # se rehace aquí abajo, con los datos de este equipo
    else
      ok "$(msg OK_CONF_EXISTE)"
      if ! [[ "$(preguntar "$(msg PREGUNTAR_REHACER)" 'N')" =~ ^[sS] ]]; then
        cfg_cargar; return 0
      fi
    fi
  fi

  if [[ -f "$CONF" && "$SI_A_TODO" == "si" ]]; then cfg_cargar; return 0; fi
  if [[ ! -f "$CONF" && "$SI_A_TODO" == "si" ]]; then
    morir "$(msg MORIR_SI_A_TODO_CONF)"
  fi

  msgln MEDIOS_EXPLICACION
  echo
  local iso msi virtio nombre
  msgln ISO_RECOMENDACION
  iso="$(preguntar_fichero "$(msg PREGUNTAR_ISO)")"
  # Comprobación barata y muy útil: ¿es de verdad una ISO de instalación de
  # Windows? (si es un disco de datos o una ISO de otra cosa, mejor saberlo AHORA
  # y no dentro de media hora, cuando el instalador lleve el disco a medias).
  if command -v 7z >/dev/null 2>&1 && [[ -f "$iso" ]]; then
    if 7z l "$iso" 2>/dev/null | grep -qiE 'sources/install\.(wim|esd)'; then
      ok "$(msg OK_ISO_INSTALL)"
    else
      aviso "$(msg AVISO_ISO_NO_WIM)"
      aviso "$(msg AVISO_ISO_SIGO)"
      aviso "$(msg AVISO_ISO_CAUSA)"
    fi
  fi
  msi="$(preguntar_fichero "$(msg PREGUNTAR_MSI)")"
  # virtio-win es OPCIONAL: pulsar Enter significa "descárgalo tú cuando toque".
  # Aquí estaba el fallo que notó un usuario: se usaba preguntar_fichero, que
  # exige que el fichero exista y trata el Enter vacío como error ("este fichero
  # es imprescindible"), así que había que insistir varias veces. Ahora Enter
  # vale, y si escribes una ruta que no existe se avisa y se descarga solo.
  virtio="$(preguntar "$(msg PREGUNTAR_VIRTIO)")"
  if [[ -n "$virtio" && ! -f "$virtio" ]]; then
    error "$(msg NO_EXISTE_FICHERO "$virtio")"
    aviso "$(msg VIRTIO_SE_DESCARGA)"
    virtio=""
  fi

  echo
  msgln EDICION_INFO
  nombre="$(preguntar "$(msg PREGUNTAR_NOMBRE_VM)" 'kemper-win11')"
  local ram vcpus disco usuario clave resolucion
  ram="$(preguntar "$(msg PREGUNTAR_RAM)" "$VM_RAM_MB")"
  vcpus="$(preguntar "$(msg PREGUNTAR_VCPUS)" "$VM_VCPUS")"

  # Pantalla de Windows. Se aplica DENTRO de Windows con un pequeño programa que
  # viaja en el medio (payload/resolucion.ps1): no depende de nada externo ni de
  # internet. 'auto' deja la que Windows elija, que se puede cambiar luego dentro
  # de Windows como en cualquier PC.
  resolucion="$(preguntar "$(msg PREGUNTAR_RESOLUCION)" "${RESOLUCION_VM:-auto}")"
  if [[ ! "$resolucion" =~ ^([0-9]+x[0-9]+|auto)$ ]]; then
    aviso "$(msg RESOLUCION_NO_VALIDA "$resolucion")"
    resolucion="auto"
  fi

  # El disco SÍ se pregunta, porque depende de lo que vayas a instalar dentro
  # de Windows (Rig Manager, tus librerías, actualizaciones). El mínimo no es
  # capricho: Windows 11 NO SE INSTALA con menos de 64 GB de disco.
  echo
  msgln DISCO_INFO
  while :; do
    disco="$(preguntar "$(msg PREGUNTAR_DISCO)" "$VM_DISCO_GB")"
    if [[ "$disco" =~ ^[0-9]+$ ]] && (( disco >= 64 )); then break; fi
    if [[ "$SI_A_TODO" == "si" ]]; then break; fi
    if ! [[ "$disco" =~ ^[0-9]+$ ]]; then
      error "$(msg ERROR_NUMERO_GB)"
    else
      error "$(msg ERROR_DISCO_MINIMO "$disco")"
      aviso "$(msg AVISO_EDITAR_CONF)"
    fi
  done
  usuario="$(preguntar "$(msg PREGUNTAR_USUARIO)" "$CUENTA_USUARIO")"
  echo
  msgln CLAVE_INFO
  clave="$(preguntar "$(msg PREGUNTAR_CLAVE)" 'kemper')"

  umask 077
  cat > "$CONF" <<EOT
# Generado por install.sh el $(date '+%F %T'). Puedes editarlo a mano.
VM_NOMBRE=$nombre
VM_RAM_MB=$ram
VM_VCPUS=$vcpus
VM_DISCO_GB=$disco
RESOLUCION_VM=$resolucion
ISO_WINDOWS=$iso
INSTALADOR_RIGMANAGER=$msi
VIRTIO_ISO=$virtio
EDICION_WINDOWS=Windows 11 IoT Enterprise LTSC 2024
CUENTA_USUARIO=$usuario
CUENTA_CLAVE=$clave
CLAVE_PRODUCTO=
EOT
  chmod 600 "$CONF"
  cfg_cargar
  ok "$(msg OK_CONF_GUARDADA)"
}

# ----------------------------------------------------------------------------
#  Fase 1 — plataforma (es la única que necesita tu contraseña)
# ----------------------------------------------------------------------------
fase1_plataforma() {
  titulo "$(msg TITULO_FASE 1 "$(nombre_fase 1)")"
  msgln FASE1_INTRO
  echo
  if sudo bash "$PROYECTO/scripts/00-setup-root.sh"; then
    marcar_hecha 1
    ok "$(msg OK_PLATAFORMA_LISTA)"
  else
    morir "$(msg MORIR_FASE1)"
  fi

  # IMPORTANTE: aquí hay que PARAR. La fase 1 mete a tu usuario en el grupo
  # 'libvirt', pero eso no llega a la sesión ya abierta: hasta que no cierres
  # sesión y vuelvas a entrar, virsh no puede hablar con el demonio y las fases
  # 4 y siguientes fallarían con un "no puedo hablar con libvirt" que no se
  # entiende. Antes el instalador seguía de largo y se estrellaba aquí; ahora
  # lo dice claramente y se para.
  if ! id -nG | tr ' ' '\n' | grep -qx libvirt; then
    msgln LOGOUT_BANNER
    exit 0
  fi
}

# ----------------------------------------------------------------------------
#  Fase 2 — virtio-win (drivers + agente de invitado)
# ----------------------------------------------------------------------------
fase2_virtio() {
  titulo "$(msg TITULO_FASE 2 "$(nombre_fase 2)")"
  local destino="$PROYECTO/install/virtio-win.iso"
  mkdir -p "$PROYECTO/install"
  if [[ -f "$destino" ]]; then ok "$(msg OK_YA_ESTA "$destino")"; marcar_hecha 2; return; fi
  if [[ -n "${VIRTIO_ISO:-}" && -f "${VIRTIO_ISO:-}" ]]; then
    cp -f "$VIRTIO_ISO" "$destino"
    ok "$(msg OK_COPIADO_VIRTIO "$(basename "$VIRTIO_ISO")")"
    marcar_hecha 2; return
  fi
  local url="https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso"
  local sumas="https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win/CHECKSUM"
  msgln DESCARGANDO_VIRTIO
  if ! curl -fL --retry 3 -o "$destino.parcial" "$url"; then
    rm -f "$destino.parcial"; morir "$(msg MORIR_DESCARGA_VIRTIO)"
  fi
  mv -f "$destino.parcial" "$destino"
  # Verificación: si se puede bajar la lista de sumas, se comprueba; si no, se avisa.
  if curl -fsS -o /tmp/virtio-checksum.txt "$sumas" 2>/dev/null; then
    local esperado obtenido
    esperado="$(grep -i 'virtio-win.iso$' /tmp/virtio-checksum.txt | awk '{print $1}' | head -1)"
    obtenido="$(sha256sum "$destino" | awk '{print $1}')"
    if [[ -n "$esperado" && "$esperado" == "$obtenido" ]]; then
      ok "$(msg OK_VIRTIO_VERIFICADO)"
    else
      aviso "$(msg AVISO_SHA_NO_COINCIDE)"
      morir "$(msg MORIR_DESCARGA_NO_VERIFICADA)"
    fi
  else
    aviso "$(msg AVISO_SIN_SUMAS)"
  fi
  marcar_hecha 2
}

# ----------------------------------------------------------------------------
#  Fase 3 — medio de instalación desatendida
# ----------------------------------------------------------------------------
fase3_medio() {
  titulo "$(msg TITULO_FASE 3 "$(nombre_fase 3)")"
  cfg_exigir_medios || morir "$(msg MORIR_FALTAN_MEDIOS)"
  bash "$PROYECTO/scripts/10-build-install-iso.sh" || morir "$(msg MORIR_CONSTRUIR_MEDIO)"
  marcar_hecha 3
}

# ----------------------------------------------------------------------------
#  Fase 4 — crear la máquina virtual
# ----------------------------------------------------------------------------
fase4_vm() {
  titulo "$(msg TITULO_FASE 4 "$(nombre_fase 4)")"
  bash "$PROYECTO/scripts/20-crear-vm.sh" || morir "$(msg MORIR_CREAR_VM)"
  marcar_hecha 4
}

# ----------------------------------------------------------------------------
#  Fase 5 — instalar Windows (la larga)
# ----------------------------------------------------------------------------
fase5_windows() {
  titulo "$(msg TITULO_FASE 5 "$(nombre_fase 5)")"
  msgln FASE5_INTRO
  echo
  bash "$PROYECTO/scripts/30-instalar-windows.sh" || morir "$(msg MORIR_INSTALAR_WINDOWS)"
  marcar_hecha 5
}

# ----------------------------------------------------------------------------
#  Fase 6 — comprobar Windows por dentro
# ----------------------------------------------------------------------------
fase6_verificar() {
  titulo "$(msg TITULO_FASE 6 "$(nombre_fase 6)")"
  local v="$PROYECTO/scripts/90-verificar-windows.py"
  [[ -f "$v" ]] || { aviso "$(msg AVISO_SIN_VERIFICADOR)"; marcar_hecha 6; return; }
  DOM="$VM_NOMBRE" python3 "$v" || morir "$(msg MORIR_VERIFICAR_WINDOWS)"
  marcar_hecha 6
}

# ----------------------------------------------------------------------------
#  Fase 7 — lanzador y limpieza
# ----------------------------------------------------------------------------
fase7_lanzador() {
  titulo "$(msg TITULO_FASE 7 "$(nombre_fase 7)")"
  bash "$PROYECTO/scripts/50-expulsar-isos.sh" || aviso "$(msg AVISO_EXPULSAR_ISO)"
  bash "$PROYECTO/scripts/70-instalar-lanzador.sh" || morir "$(msg MORIR_LANZADOR)"
  marcar_hecha 7
}

# ----------------------------------------------------------------------------
#  Estado y arranque
# ----------------------------------------------------------------------------
mostrar_estado() {
  cfg_cargar
  titulo "$(msg TITULO_ESTADO)"
  local f
  for f in 1 2 3 4 5 6 7; do
    if fase_hecha "$f"; then ok "$(msg ESTADO_HECHA "$(nombre_fase $f)")"
    else                     printf '   \033[33m·\033[0m '; msgln ESTADO_PENDIENTE "$(nombre_fase $f)"; fi
  done
  echo
  local p; p="$(fase_pendiente)"
  [[ -n "$p" ]] && msgln ESTADO_SIGUIENTE "$p" \
                || msgln ESTADO_COMPLETA
  [[ -f "$ESTADO" ]] || msgln ESTADO_SIN_FASES
}

ejecutar() {
  local f="$1"
  case "$f" in
    1) fase1_plataforma ;;
    2) fase2_virtio ;;
    3) fase3_medio ;;
    4) fase4_vm ;;
    5) fase5_windows ;;
    6) fase6_verificar ;;
    7) fase7_lanzador ;;
  esac
}

# Encadena TODAS las fases que falten, en orden. Es lo que hace la instalación
# guiada y lo que espera cualquiera que escriba --continuar: "sigue desde donde
# lo dejaste", no "haz una fase y vuelve a llamarme" (esto último obligaba a
# teclear el comando siete veces).
encadenar() {
  local f
  for f in 1 2 3 4 5 6 7; do
    fase_hecha "$f" && continue
    ejecutar "$f" || exit 1
    cfg_cargar          # la configuración puede haber cambiado (la escribe el asistente)
  done
}

final() {
  titulo "$(msg TITULO_FIN)"
  msgln FIN_ABRE
  msgln FIN_REINICIO
  msgln FIN_GUIA
  msgln FIN_RUTA_MANUAL
  echo
  msgln FIN_LOG "$LOG"
}

# --- opciones de línea de órdenes -------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)    CONF="$2"; shift 2 ;;
    --si-a-todo) SI_A_TODO=si; shift ;;
    --estado)    ACCION=estado; shift ;;
    --comprobar) ACCION=comprobar; shift ;;
    --continuar) ACCION=continuar; shift ;;
    --fase)      ACCION=fase; FASE_PEDIDA="$2"; shift 2 ;;
    --ayuda|-h|--help) awk 'NR>1 && /^#/ { sub(/^# ?/, ""); print; next } NR>1 { exit }' "$SCRIPT"; exit 0 ;;
    *) msgln OPCION_NO_RECONOCIDA "$1" >&2; exit 2 ;;
  esac
done

if [[ "$CONF" != "$PROYECTO/config/kemper-vm.conf" ]]; then
  export CONF_EXTERNA="$CONF"
fi

cfg_cargar
log "install.sh: acción=$ACCION"

case "$ACCION" in
  estado)    mostrar_estado ;;
  comprobar) comprobar_requisitos ;;
  fase)      cfg_cargar; ejecutar "$FASE_PEDIDA" ;;
  continuar)
    [[ -f "$CONF" ]] || pedir_configuracion    # sólo si es la primera vez
    cfg_cargar
    if [[ -z "$(fase_pendiente)" ]]; then mostrar_estado; exit 0; fi
    encadenar
    final ;;
  guiada)
    comprobar_requisitos
    pedir_configuracion
    local_p="$(fase_pendiente)"
    if [[ -z "$local_p" ]]; then mostrar_estado; exit 0; fi
    echo
    if [[ "$SI_A_TODO" == "si" ]] || [[ "$(preguntar "$(msg PREGUNTAR_EMPEZAR "$local_p")" 'S')" =~ ^[sSyY]?$ ]]; then
      encadenar
      final
    fi ;;
esac