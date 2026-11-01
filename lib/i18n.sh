# shellcheck shell=bash
# =============================================================================
#  lib/i18n.sh — mensajes en varios idiomas (español e inglés)
# =============================================================================
#  CÓMO SE USA EN CUALQUIER SCRIPT
#      source "$PROYECTO/lib/i18n.sh"
#      i18n_cargar                 # decide el idioma y lee los textos
#      msg BIENVENIDA              # imprime el mensaje BIENVENIDA
#      msg FALTA_FICHERO "/ruta"   # con argumentos (el texto lleva %s)
#
#  QUÉ IDIOMA SE USA, por orden:
#      1. la variable KEMPER_LANG (es|en)   → p. ej.  KEMPER_LANG=en ./install.sh
#      2. la clave IDIOMA= del fichero config/kemper-vm.conf
#      3. el idioma del sistema ($LANG, $LC_ALL): es* → español; si no, inglés
#
#  LOS TEXTOS VIVEN EN lib/i18n/<idioma>.txt, uno por línea:
#      CLAVE=Texto del mensaje
#  · Si un texto lleva un %, escríbelo doble (%%): lo usa printf.
#  · Un texto puede ocupar varias líneas usando \n.
#  · Si falta una clave en un idioma, se usa el inglés y se avisa por stderr
#    (así una traducción incompleta nunca rompe nada).
#
#  POR QUÉ ASÍ: los scripts eran monolingües (español) y el texto estaba dentro
#  del código. Para poder compartirlos con medio mundo sin duplicar cada script,
#  los mensajes salen a ficheros de texto: añadir un idioma es copiar un fichero.
# =============================================================================

declare -A TEXTOS=()
IDIOMA="${KEMPER_LANG:-}"

# Si quien nos carga no ha definido PROYECTO, lo deducimos de nuestra ubicación
# (lib/ está dentro del proyecto). Así la librería funciona aunque se llame desde
# una prueba suelta, y no depende de que el script se acuerde.
if [[ -z "${PROYECTO:-}" ]]; then
  PROYECTO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

i18n_idioma_sistema() {
  local l="${LC_ALL:-${LANG:-en}}"
  case "$l" in
    es*|ES*) echo es ;;
    *)       echo en ;;
  esac
}

i18n_cargar() {
  # 1) qué idioma: entorno > configuración > sistema
  [[ -n "$IDIOMA" ]] || IDIOMA="$(i18n_idioma_sistema)"
  if [[ -z "${KEMPER_LANG:-}" && -n "${PROYECTO:-}" && -f "$PROYECTO/config/kemper-vm.conf" ]]; then
    # OJO (fallo real, detectado en la prueba de fuego): un 'grep' que no
    # encuentra nada devuelve 1, y con 'set -o pipefail' eso hace fallar toda la
    # tubería y, con 'set -e', mata el script que nos haya llamado — sin imprimir
    # nada. De ahí el '|| true'. Y la asignación va con 'if', no con '&&', porque
    # el valor de retorno de esa lista también se propaga al llamador.
    local delconf=""
    delconf="$(grep -E '^IDIOMA=' "$PROYECTO/config/kemper-vm.conf" 2>/dev/null | head -1 | cut -d= -f2- | tr -d ' \r' || true)"
    if [[ -n "$delconf" ]]; then IDIOMA="$delconf"; fi
  fi
  case "$IDIOMA" in es|en) ;; *) IDIOMA=en ;; esac

  # 2) leer los textos. Siempre el inglés primero (respaldo) y luego el idioma
  #    elegido, que pisa lo anterior. Se leen también los ficheros de la carpeta
  #    <idioma>.d/ : así varias personas pueden traducir trozos distintos sin
  #    pelearse por el mismo fichero (y se pueden quitar trozos sin romper nada).
  i18n_leer "$PROYECTO/lib/i18n/en.txt"
  i18n_leer_carpeta "$PROYECTO/lib/i18n/en.d"
  if [[ "$IDIOMA" != "en" ]]; then
    i18n_leer "$PROYECTO/lib/i18n/$IDIOMA.txt"
    i18n_leer_carpeta "$PROYECTO/lib/i18n/$IDIOMA.d"
  fi
}

i18n_leer() {
  local f="$1" linea clave valor
  if [[ ! -f "$f" ]]; then return 0; fi
  while IFS= read -r linea || [[ -n "$linea" ]]; do
    linea="${linea%$'\r'}"
    # Filtros con 'if' explícito: una lista 'X && continue' que falla deja el
    # valor de retorno en 1 y puede abortar al llamador (ver la nota de arriba).
    if [[ "$linea" =~ ^[[:space:]]*# ]]; then continue; fi
    if [[ "$linea" != *=* ]]; then continue; fi
    clave="${linea%%=*}"
    valor="${linea#*=}"
    clave="${clave//[[:space:]]/}"
    if [[ -z "$clave" ]]; then continue; fi
    TEXTOS["$clave"]="$valor"
  done < "$f"
}

# Lee todos los .txt de una carpeta (si existe), en orden alfabético.
i18n_leer_carpeta() {
  local d="$1" f
  [[ -d "$d" ]] || return 0
  for f in "$d"/*.txt; do
    if [[ -e "$f" ]]; then i18n_leer "$f"; fi
  done
}

# Igual que msg, pero añadiendo salto de línea (equivale al 'echo' de antes).
# Existe para que convertir un 'echo "texto"' en 'msgln CLAVE' sea mecánico.
msgln() { msg "$@"; printf '\n'; }

# Imprime un mensaje por su clave. Con argumentos, usa printf.
msg() {
  local clave="$1"; shift
  local texto="${TEXTOS[$clave]:-}"
  if [[ -z "$texto" ]]; then
    # Falta la traducción: se ve la CLAVE (así se detecta) y se avisa.
    printf '%s' "[[$clave]]"
    echo "i18n: falta el texto de la clave '$clave' en $IDIOMA.txt" >&2
    return 0
  fi
  # \n, \r y \t pasan a caracteres reales (como haría printf con su formato),
  # así un texto en varias líneas sale bien tanto con argumentos como sin ellos.
  # Se hace a mano para no tocar otras barras invertidas (rutas C:\..., \c...),
  # que 'printf %b' sí interpretaría.
  texto="${texto//\\n/$'\n'}"
  texto="${texto//\\r/$'\r'}"
  texto="${texto//\\t/$'\t'}"
  # El '--' NO es adorno: un texto que empiece por guión (por ejemplo una lista
  # de paquetes: "-- núcleo: ...") hacía que printf lo tomara por una opción
  # suya y abortara el script con "printf: --: invalid option". Fallo real,
  # encontrado al instalar en un Debian (no en mis pruebas: ahí no ejecuté
  # justo las fases que tienen mensajes que empiezan por guión).
  if (( $# > 0 )); then printf -- "$texto" "$@"; else printf -- '%s' "$texto"; fi
}
