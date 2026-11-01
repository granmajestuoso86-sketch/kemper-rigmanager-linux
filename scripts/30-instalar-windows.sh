#!/usr/bin/env bash
# =============================================================================
#  30-instalar-windows.sh — arranca la VM y vigila la instalación desatendida
#
#  Uso:
#     scripts/30-instalar-windows.sh [minutos_maximo]        (por defecto 90)
#     scripts/30-instalar-windows.sh --solo-vigilar [minutos]
#
#  Qué hace (modo normal):
#    1. Arranca el dominio SI no lo estaba (y sólo en ese caso: ver abajo).
#    2. Resuelve el único punto que necesita mano humana: el aviso del DVD
#       "Press any key to boot from CD or DVD..." del medio de Windows, enviando
#       pulsaciones durante 25 s. Después la instalación es desatendida: en los
#       reinicios NO hay que pulsar nada (al no pulsar, el DVD cede el turno y
#       arranca del disco, que es justo lo que se quiere).
#       IMPORTANTE: las pulsaciones SÓLO se envían si el script ha arrancado la
#       máquina. Si ya estaba en marcha, NO se envía nada: durante la instalación
#       hay botones en pantalla ("Cancel") y una tecla a destiempo la cancelaría.
#    3. Vigila con capturas en evidencia/instalacion/ y termina cuando el AGENTE
#       DE INVITADO responde (señal objetiva de que Windows está arriba y de que
#       la instalación del programa ha terminado).
#
#  LECCIÓN APRENDIDA: todo el script exporta LC_ALL=C. `virsh` traduce sus
#  mensajes al idioma del sistema (aquí devolvía "ejecutando" en vez de "running")
#  y una comparación de texto contra la salida de virsh puede fallar sin que nada
#  esté roto de verdad. Ya pasó una vez: el vigilante se paró solo.
# =============================================================================
set -uo pipefail
export LC_ALL=C

PROYECTO="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
source "$PROYECTO/lib/config.sh"
cfg_cargar
source "$PROYECTO/lib/i18n.sh"
i18n_cargar

# Permite trabajar sobre otro dominio (p. ej. la VM de prueba de la fase F8):
#   DOMINIO=kemper-prueba scripts/30-instalar-windows.sh 90
DOM="${DOMINIO:-$VM_NOMBRE}"
URI="qemu:///system"
EVID="$PROYECTO/evidencia/instalacion"

SOLO_VIGILAR=no
if [[ "${1:-}" == "--solo-vigilar" ]]; then SOLO_VIGILAR=si; shift; fi
MAX_MIN="${1:-90}"
INTERVALO=30

v() { virsh -c "$URI" "$@"; }
en_marcha() { [[ "$(v domstate "$DOM" 2>/dev/null)" == "running" ]]; }
agente() { v qemu-agent-command "$DOM" '{"execute":"guest-ping"}' >/dev/null 2>&1; }

mkdir -p "$EVID"
v dominfo "$DOM" >/dev/null 2>&1 || { msgln WIN_ERR_DOMINIO "$DOM" >&2; exit 1; }

if [[ "$SOLO_VIGILAR" == "no" ]]; then
  msgln WIN_P1
  if en_marcha; then
    msgln WIN_YA_MARCHA
    recien_arrancada=no
  else
    v start "$DOM" | sed 's/^/   /'
    recien_arrancada=si
  fi

  msgln WIN_P2
  if [[ "$recien_arrancada" != "si" ]]; then
    msgln WIN_NO_PULSA1
    msgln WIN_NO_PULSA2
  elif ! command -v convert >/dev/null 2>&1; then
    # Sin ImageMagick no podemos medir la pantalla: ventana corta y acotada.
    msgln WIN_SIN_IM
    for _ in $(seq 1 14); do v send-key "$DOM" KEY_SPACE >/dev/null 2>&1 || true; sleep 1; done
  else
    # MÉTODO ADAPTATIVO (lección aprendida): NO se pulsa un tiempo fijo.
    # Se mira la pantalla: el aviso del DVD y las pantallas de carga del
    # firmware son NEGRAS (brillo medio ~0,02); la pantalla azul del setup
    # ("Installing Windows") tiene brillo ~0,3. Se pulsa mientras esté oscura y
    # se PARA en cuanto se ilumina. Así ninguna tecla llega al botón Cancel
    # (pasó una vez: un diálogo "Are you sure you want to quit?" bloqueó la
    # instalación, y se recupera pulsando ENTER sobre el botón "No").
    msgln WIN_PULSANDO
    for i in $(seq 1 30); do
      v screenshot "$DOM" /tmp/_arranque.png >/dev/null 2>&1 || true
      brillo=$(convert /tmp/_arranque.png -colorspace Gray -resize 1x1 -format '%[fx:mean]' info: 2>/dev/null || echo 1)
      if awk "BEGIN{exit !($brillo < 0.12)}"; then
        v send-key "$DOM" KEY_SPACE >/dev/null 2>&1 || true
        sleep 1
      else
        msgln WIN_SETUP_EN_PANTALLA "$brillo" "$i"
        break
      fi
    done
  fi
else
  msgln WIN_SOLO_VIGILAR
fi

msgln WIN_P3 "$MAX_MIN" "$INTERVALO"
fin=$(( $(date +%s) + MAX_MIN*60 ))
n=0
while :; do
  n=$((n+1))
  t=$(date +%H:%M:%S)
  estado="$(v domstate "$DOM" 2>/dev/null || msg WIN_DESCONOCIDO)"
  f="$EVID/instalacion-$(printf '%03d' "$n").png"
  v screenshot "$DOM" "$f" >/dev/null 2>&1 || true

  if agente; then
    msgln WIN_AGENTE "$t"
    v qemu-agent-command "$DOM" '{"execute":"guest-ping"}' > "$EVID/agente-ok.json" 2>/dev/null || true
    break
  fi

  msgln WIN_ESTADO "$t" "$estado" "$(basename "$f")"
  if [[ "$estado" != "running" ]]; then msgln WIN_NO_MARCHA; break; fi
  if [[ "$(date +%s)" -ge "$fin" ]]; then msgln WIN_MAX_TIEMPO; break; fi
  sleep "$INTERVALO"
done

echo
msgln WIN_CAPTURAS "$EVID"
msgln WIN_PANTALLA "$URI" "$DOM"
msgln WIN_CONSOLA "$URI" "$DOM"