# Rig Manager de Kemper en Ubuntu — Manual de despliegue y uso

> **Estado del documento:** F0–F5 **cerradas y verificadas** · F6 **probado por el usuario** (arranca Windows y Rig Manager) con un fallo de rutas ya corregido · F7 **verificada byte a byte** · F8 **prueba de fuego desde cero SUPERADA** (~6 min, sin intervención humana). Las secciones
> marcadas con `⏳ (F_n)` se completan al cerrar esa fase. Ninguna afirmación de este manual
> debe considerarse verificada si no lleva su evidencia o su fuente.
>
> **Última actualización:** 2026-10-31
> **Origen:** proyecto escrito con ayuda de IA y corregido y verificado a mano. Cada
> afirmación de este manual lleva su evidencia o su fuente.
> **Proyecto:** la carpeta donde tengas este repositorio clonado.
> **Convención de este manual:** en los ejemplos, `${PROYECTO}` es esa carpeta.
> Los comandos `cd "$PROYECTO"` funcionan tal cual si la has exportado:
> `export PROYECTO=/ruta/donde/lo/clonaste`
> **Destinatario de la guía de uso:** usuario sin conocimientos de Linux.

---

## Índice

1. [Qué es esto y por qué se hace así](#1-qué-es-esto-y-por-qué-se-hace-así)
2. [Cómo se usa (resumen para impacientes)](#2-cómo-se-usa-resumen-para-impacientes)
3. [Arquitectura y decisiones técnicas](#3-arquitectura-y-decisiones-técnicas)
4. [Estado verificado de la máquina](#4-estado-verificado-de-la-máquina)
5. [Inventario de medios (con hashes verificados)](#5-inventario-de-medios-con-hashes-verificados)
6. [Despliegue desde cero, paso a paso](#6-despliegue-desde-cero-paso-a-paso)
7. [Guía de uso diaria (usuario amateur)](#7-guía-de-uso-diaria-usuario-amateur)
8. [Registro de ejecución y arbitraje adversarial](#8-registro-de-ejecución-y-arbitraje-adversarial)
9. [Riesgos abiertos y planes B](#9-riesgos-abiertos-y-planes-b)
10. [Solución de problemas y trampas comprobadas](#10-solución-de-problemas-y-trampas-comprobadas)
11. [Desinstalación total](#11-desinstalación-total)
12. [Glosario para no iniciados](#12-glosario-para-no-iniciados)
13. [Inventario de scripts y ficheros](#13-inventario-de-scripts-y-ficheros)
14. [Versiones verificadas y evidencias](#14-versiones-verificadas-y-evidencias)

---

## 0. Si vienes del repositorio, empieza por aquí

Este manual es el **detalle** de cómo está montado todo y de las trampas que se
encontraron por el camino. Si lo único que quieres es tenerlo funcionando, no lo
leas entero: ve al repositorio, ejecuta

```bash
./install.sh          # te pregunta lo necesario y hace las fases una a una
```

y usa este manual para entender o para arreglar algo (§10 es la sección que más
te va a servir). El despliegue paso a paso de §6 es exactamente lo que `install.sh`
automatiza: está aquí para poder hacerlo a mano cuando algo falle, no para
copiarlo y pegarlo sin más.

---

## 1. Qué es esto y por qué se hace así

El **Kemper Profiler** (Powerhead) tiene un programa oficial de gestión, **Rig Manager**, que
solo existe para Windows y macOS. Sirve para lo que el aparato no puede hacer solo:

- **MyProfiler**: control y organización del contenido que hay dentro del aparato (rigs,
  presets, performances, IRs).
- **Library / Rig Exchange / Rig Packs**: biblioteca grande, intercambio y packs de rigs.
- **Actualizaciones del sistema operativo** del Kemper (por USB, no por lápiz).
- **Backups y montaje de backups**.

El Kemper habla por USB con ese programa. En Linux ese USB es accesible
(es un dispositivo compuesto: audio + MIDI + una interfaz específica del fabricante) y **por
eso existe un editor nativo** que se puede usar por MIDI. Pero ese editor **no cubre** la
biblioteca, el Rig Exchange ni la actualización del SO: esas funciones van por el canal
propietario y **solo** las implementa Rig Manager.

**La solución de este proyecto:** una **máquina virtual con Windows 11 IoT Enterprise LTSC**
ejecutándose sobre KVM (aceleración por hardware del propio procesador), con el **USB del
Kemper pasado directamente dentro del Windows invitado**. Windows ve el aparato como si
estuviera enchufado a él, Rig Manager funciona al 100 %, y desde Ubuntu todo se abre con un
**lanzador en el menú** que también se encarga de devolver el Kemper a Linux al terminar.

> **Regla de oro de este montaje:** el aparato USB sólo puede estar en un sitio a la vez.
> Mientras la VM tiene el Kemper, el editor nativo de Linux **no lo ve**. Es físico, no un
> fallo: un dispositivo USB pertenece a un único "dueño".

### Qué NO es esto

- No es Wine. Rig Manager **no funciona** con Wine y no es cuestión de configurarlo: los
  intentos documentados (Wine 9.0, 9.12, Bottles) fallan porque falta soporte para su capa de
  acceso al USB. No se pierde más tiempo por ahí.
- No es una emulación lenta: con KVM el invitado corre a velocidad nativa (instrucciones
  ejecutadas por el procesador, no traducidas).

---

## 2. Cómo se usa (resumen para impacientes)

**Abrir (el uso normal):**

1. Enchufa el Kemper por USB y enciéndelo (modo Browser).
2. En el menú de aplicaciones de Ubuntu busca **Rig Manager (Kemper)** y púlsalo.
3. Espera: se abre una ventana que **es un Windows entero**. La primera vez tarda
   un poco; después, en menos de un minuto tienes dentro Rig Manager ya abierto y
   conectado al aparato. **Windows entra solo**: nunca verás su pantalla de inicio
   de sesión (la cuenta local tiene contraseña y arranque de sesión automático).
4. Cuando termines: **cierra la ventana** (la X). Windows se apaga solo, sin
   preguntarte nada, y **devuelve el Kemper a Linux**.

**Dos comandos de emergencia**, desde una terminal:

```bash
kemper-rig-manager --estado          # qué está pasando ahora mismo
kemper-rig-manager --apagar          # apaga Windows y libera el Kemper
kemper-rig-manager --dejar-abierto   # al cerrar, deja Windows encendido
```

> **Aviso que vale oro:** mientras esa ventana esté abierta, **el Kemper pertenece
> a Windows**. Tu editor nativo de Linux no lo verá. No es un fallo: un dispositivo
> USB tiene un único dueño a la vez.

⏳ **Pendiente de tu prueba:** el paso 2 (que la ventana se abra desde el menú)
sólo se puede comprobar desde tu sesión gráfica. Lo que sí está verificado por
mí, por dentro, es todo lo demás: la VM arranca, el Kemper se conecta, Rig Manager
lee el aparato y el apagado devuelve el aparato a Linux.

## 3. Arquitectura y decisiones técnicas

| Pieza | Elección | Por qué (y qué se descartó) |
|---|---|---|
| Hipervisor | **QEMU/KVM** con libvirt (`qemu:///system`) | AMD-V presente y `/dev/kvm` accesible ⇒ velocidad nativa. Se descartó **VirtualBox** (módulo de kernel fuera de árbol, más fricción con cada actualización) y **gnome-boxes** (oculta el control fino de USB y del XML que aquí es imprescindible). |
| Firmware del invitado | **UEFI (OVMF)** | Es lo que Windows 11 exige. |
| TPM | **swtpm 2.0 emulado** | Windows 11 LTSC requiere TPM 2.0; se emula de verdad en vez de parchear el instalador. |
| Drivers del invitado | **virtio-win** (Fedora) | Disco, red, globo de memoria y vídeo con **1920×1080 real** (con los drivers "de serie" de Windows la resolución se queda corta y Rig Manager no cabe bien). Trae también el **agente de invitado**, que es la herramienta de verificación. |
| Red | NAT de libvirt (`default`) | Rig Manager necesita internet para el Rig Exchange y para descargar actualizaciones del OS del Kemper. |
| **USB del Kemper** | **`hostdev` dinámico**, nunca fijo en el XML | Si el aparato no está enchufado, un dominio con `hostdev` fijo **no arranca**. El lanzador lo detecta, arranca la VM y lo conecta en caliente (`virsh attach-device --live`); al apagar, libvirt lo devuelve solo a Linux. Además permite usar la VM **sin** el Kemper (biblioteca en local). |
| Instalación de Windows | **Desatendida** (`autounattend.xml` + ISO propio con el XML y el MSI) | Sin clics: idioma, teclado, cuenta, drivers, VC++ y **Rig Manager instalado** en el primer arranque. Reproducible: es lo que permite que este manual sirva para futuros despliegues. |
| Estado de la VM (discos) | `/var/lib/libvirt/images/kemper-win11/` | Un directorio propiedad de root y con los permisos estándar de libvirt evita toda la clase de fallos de permisos (DAC/AppArmor) al arrancar. Se enlazará dentro del proyecto como `vm/` (el enlace se crea en F3) para tenerlo a la vista. |
| Código, configuración y documentos | **En la carpeta del proyecto** | Es lo que se versiona, se revisa y se reutiliza. |

---

## 4. Estado verificado de la máquina

Evidencia en bruto: `evidencia/F0-recon.txt` (generada automáticamente el 2026-10-31).

| Comprobación | Resultado | Implicación |
|---|---|---|
| CPU / virtualización | AMD Ryzen 7 8745HS, 16 hilos, `AMD-V`, `kvm_amd` cargado | Se puede usar KVM (no emulación lenta) |
| `/dev/kvm` | existe y con ACL para el usuario | El usuario puede usar KVM sin ser root |
| RAM | 14 GiB totales (≈9,4 disponibles; varía) | VM a 6 GB: cabe, pero **REAPER grande + VM a la vez va justo** |
| Disco libre | ≈233 GB en `/` | Suficiente (ISO + disco de la VM + intercambio) |
| Virtualización instalada | **ninguna** (`qemu`, `libvirt`, `virt-manager`, `ovmf`, `swtpm` ausentes) | Es lo que instala F1 |
| `sudo` | **pide contraseña** | El único paso que debe ejecutar el humano (F1) |
| Kemper en el host | `133e:0003 Kemper Digital GmbH Profiler`, serie `APEaRiLBATF`, clase 239 (dispositivo compuesto), Full Speed | Presente y detectado; el emparejamiento USB de la VM se hará por `vendor:product` |
| Rig Manager | `Rig_Manager_4_3_13_Windows 64-bit.msi` — **sin ningún driver `.sys`/`.inf` dentro**; sí incluye `VCRedist` y 35 Rig Packs | Su acceso al USB es en espacio de usuario ⇒ el paso a la VM es viable y no hace falta instalar VC++ aparte |

### 4.1 Comprobaciones independientes (árbitro de F0)

Auditoría adversarial de F0: veredicto **«F0 SOSTIENE el escrutinio»**, 0 bloqueantes, 0
importantes, 3 menores (ya corregidos). Evidencia: `evidencia/F0-veredicto-arbitro.md` y el
transcript íntegro. De aquella auditoría salen tres datos que usa este montaje:

- **AppArmor no hay que tocarlo**: el perfil `abstractions/libvirt-qemu` ya permite
  `/dev/bus/usb/` (para el paso del Kemper) y la lectura de imágenes de disco; los
  dispositivos de `hostdev` se autorizan dinámicamente.
- **QEMU corre como `libvirt-qemu` (grupo `kvm`)** y esos usuarios los crea el propio paquete
  de libvirt: por eso el paso del USB funciona con `qemu:///system` sin reglas udev.
- **`ovmf` es un metapaquete** (`ovmf-generic`, `ovmf-amdsev`, `ovmf-inteltdx`, `ubuntu-virt`);
  el firmware UEFI que usaremos está en `/usr/share/OVMF/OVMF_CODE_4M.fd`.

---

## 5. Inventario de medios (con hashes verificados)

| Fichero | Tamaño | SHA-256 | Verificación |
|---|---|---|---|
| `en-us_windows_11_iot_enterprise_ltsc_2024_x64_dvd_f6b14814.iso` | 4,79 GiB | `4f59662a96fc1da48c1b415d6c369d08af55ddd64e8f1c84e0166d9e50405d7a` | **Coincide con el hash oficial de Microsoft**, reproducido por tres fuentes independientes (runbook de hardening de LTSC en GitHub, informe de imágenes de Ventoy, archivo de archive.org) |
| `26100.1742…_CLIENT_IOT_LTSC_EVAL_x64FRE_en-us.iso` | 4,71 GiB | (no usado) | Edición **EVAL**: caduca a los 90 días con apagones horarios. Se conserva sólo como respaldo |
| `Rig_Manager_4_3_13_Windows 64-bit.msi` | 291 MiB | ver `evidencia/F0-recon.txt` | Contenido inspeccionado (63 ficheros) |

**ISO elegida: la LTSC 2024 general (no la EVAL).** Motivo: mismo build (`26100.1742`), misma
edición, mismos requisitos, pero **sin caducidad**. Sin clave de licencia queda en estado "no
activado" (marca de agua en el escritorio y personalización limitada), **sin** apagones
horarios y sin perder funcionalidad para lo que aquí se necesita.

---

## 6. Despliegue desde cero, paso a paso

> **Atajo:** `./install.sh` hace esta sección entera, por fases y reanudable.
> Lo de aquí abajo sirve para hacerlo a mano, entender cada paso o recuperarse
> de un fallo. Las rutas de los medios ya no están dentro de los scripts: viven
> en `config/kemper-vm.conf` (lo escribe `install.sh`, o se copia del ejemplo).

> Todo está en `scripts/`, dentro de la carpeta del proyecto, y es **idempotente**:
> repetir un paso no rompe nada. El orden importa.
> **Regla de oro**: los scripts del invitado (`.cmd`) se escriben **sólo en ASCII**
> y sin comillas en los comentarios; los del anfitrión fuerzan `LC_ALL=C`. Las dos
> reglas salen de fallos reales, no de la teoría.

### 6.1 Antes de empezar

- Virtualización por hardware activada en la UEFI (aquí: AMD-V) y `/dev/kvm`.
- ~230 GB libres, 14 GiB de RAM (a la VM se le asignan 6).
- La ISO oficial de Windows 11 IoT Enterprise LTSC 2024 y el MSI de Rig Manager.
- Internet (paquetes del sistema y drivers `virtio-win`).

### 6.2 Plataforma — el único paso con contraseña

```bash
sudo bash "${PROYECTO}/scripts/00-setup-root.sh"
```

Instala QEMU/KVM, libvirt, virt-manager, OVMF (UEFI), swtpm (TPM 2.0) y xorriso;
añade tu usuario a `libvirt` y `kvm`; activa el demonio y la red NAT; crea el
directorio de discos y concede las **ACL** que QEMU necesita para leer los medios
que están dentro de tu carpeta personal.

**Después: cierra sesión y entra de nuevo.** Los grupos sólo se aplican a sesiones
nuevas. Si no puedes cerrar sesión en ese momento, existe un atajo temporal:
`sudo setfacl -m u:$USER:rw /run/libvirt/libvirt-sock /run/libvirt/libvirt-sock-ro`
(se pierde al reiniciar; no sustituye al cierre de sesión).

### 6.3 Drivers del invitado (virtio-win)

```bash
cd "${PROYECTO}/install"
curl -fL -o virtio-win.iso https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso
```

De ahí sólo se usan dos ficheros, ya extraídos en `install/payload/`:
`virtio-win-gt-x64.msi` y `guest-agent/qemu-ga-x86_64.msi`.

### 6.4 Medio de instalación desatendida

```bash
scripts/10-build-install-iso.sh
```

Genera `install/kemper-install.iso` con `autounattend.xml` **en la raíz** y
`payload/` con los instaladores. La raíz y el subdirectorio importan: la orden del
fichero de respuestas busca `payload\instalar.cmd`.

### 6.5 Crear la máquina virtual

```bash
scripts/20-crear-vm.sh
```

Define el grupo de almacenamiento `kemper`, pide **al demonio** que cree el disco
de 80 GB (no se puede escribir a mano en `/var/lib/libvirt/images`), define el
dominio y deja el enlace `vm/`. **No la arranca.**

> **VERIFICADO DE PRINCIPIO A FIN (F8)**: este procedimiento completo se ejecutó
> sobre una máquina nueva el 31-oct-2026 y terminó solo en **~6 minutos**, con los
> tres instaladores en `exit=0` y sin intervención humana. Registro en
> `evidencia/F8-prueba-desde-cero.md`.

### 6.6 Instalar Windows (desatendido) y vigilar

```bash
scripts/30-instalar-windows.sh 90        # arranca, resuelve el aviso del DVD y vigila
scripts/30-instalar-windows.sh --solo-vigilar 90   # sólo vigilar (no arranca ni teclea)
```

Qué hace: envía pulsaciones **midiendo la pantalla** (mientras está oscura, que es
el firmware y el aviso del DVD; para en cuanto aparece la pantalla azul del setup),
vigila con capturas en `evidencia/instalacion/` y termina cuando **el agente de
invitado responde**, que es la prueba objetiva de que Windows está operativo.

Al acabar:

```bash
scripts/50-expulsar-isos.sh
```

### 6.7 Conectar el Kemper

```bash
scripts/40-conectar-kemper.sh
```

Conecta el aparato en caliente y comprueba las dos caras del traspaso. **Ojo con el
criterio**: `lsusb` no sirve (el aparato sigue en `sysfs` aunque lo tenga la VM).
Lo que se mira es qué controlador tiene enlazado cada interfaz: `usbfs` significa
«lo tiene un programa de usuario (QEMU)»; `snd-usb-audio` significa «está en Linux».

### 6.8 Lanzador en el menú de Ubuntu

```bash
scripts/70-instalar-lanzador.sh
```

Instala el lanzador en `~/.local/bin`, **el icono oficial de Rig Manager** en
ocho tamaños (16 a 256 px) y la entrada de menú. **Cierra sesión y entra de nuevo**
para que aparezca en el menú.

El icono oficial no es un fichero del programa: Kemper lo guarda en un ejecutable
diminuto, `C:\WINDOWS\Installer\{...}\RigManagerIcon.exe`, que existe sólo para
eso. Se extrae **sin instalar nada** en Ubuntu:

```bash
# 1) sacar el exe de la VM (por el agente de invitado)
scripts/95-intercambio.py recibir "C:\\WINDOWS\\Installer\\{5E7307AE-B167-4E2B-AA73-601F08A7C478}\\RigManagerIcon.exe" /tmp/RigManagerIcon.exe

# 2) leer sus iconos (wrestool/icotool de icoutils, sin root)
apt-get download icoutils && dpkg-deb -x icoutils_*.deb /tmp/icoutils
mkdir -p /tmp/iex && /tmp/icoutils/usr/bin/wrestool -x -t 14 -o /tmp/iex/ /tmp/RigManagerIcon.exe
/tmp/icoutils/usr/bin/icotool -x -o /tmp/ipng/ /tmp/iex/*.ico
```

Da un PNG de **256×256 con transparencia** (el original es un icono PNG dentro de un
`.ico`). Se archiva en `icono/rig-manager/` para no depender de la máquina virtual.

### 6.9 Intercambiar ficheros con la VM

```bash
scripts/95-intercambio.py enviar  mi.backup.rmbackup      # Ubuntu -> VM
scripts/95-intercambio.py lista                            # ver C:\INTERCAMBIO
scripts/95-intercambio.py recibir "C:\INTERCAMBIO\x.krig" ./x.krig   # VM -> Ubuntu
```

Va por el agente de invitado (canal virtio-serial): sin disco compartido, sin
drivers, sin root y con la VM encendida. Verificado byte a byte con hashes.

## 7. Guía de uso diaria (usuario amateur)

### Abrir Rig Manager
Menú → **Rig Manager (Kemper)**. Se abre el Windows de la VM con Rig Manager ya
arrancado y el Kemper conectado.

- **Si tienes el Kemper apagado** (o encendido después de abrir), da igual: el
  lanzador deja un vigilante y lo conecta **solo** en cuanto lo enciendas. Mientras
  tanto puedes usar Rig Manager con tu biblioteca local.
- **Un Kemper apagado no aparece en el ordenador** — ni en `lsusb`, ni como tarjeta
  de sonido. Es lo normal, no un fallo: apagado, el aparato no existe para el PC.
- Si la VM ya venía encendida de antes (con el Kemper dentro), el lanzador no
  reinicia Windows: sólo te abre la ventana. Lo verás anotado en `logs/lanzador.log`.

### Qué se puede hacer ahí dentro
Todo lo del Rig Manager de escritorio: **MyProfiler** (el contenido del aparato),
biblioteca local, performances, backups, **Rig Exchange** y **actualizar el
sistema operativo del Kemper**. En la primera sesión, Rig Manager avisó de que el
aparato tiene **OS 14.1.2** y que esa versión de Rig Manager espera **14.2**: la
actualización se lanza desde el propio programa (menú **PROFILER**).

### Pasar ficheros entre Ubuntu y Windows
`scripts/95-intercambio.py` (ver §6.9). Los ficheros quedan en `C:\INTERCAMBIO`
dentro de la VM.

### Cerrar
**Cierra la ventana (la X) y ya está.** No hay que contestar ninguna pregunta:
Windows se apaga solo y el Kemper vuelve a Linux en unos segundos, con lo que tu
editor nativo lo ve otra vez. Si no vuelve, desenchufa y vuelve a enchufar el USB.
Al final te saldrá un aviso *«Windows apagado»*, que es sólo eso, un aviso: púlsale
OK o ciérralo.

**¿Y si quiero dejar Windows encendido** (por ejemplo para que termine una
actualización larga del sistema operativo del Kemper)? Entonces no cierres la
ventana: minimízala. Si ya la has cerrado o quieres abrirla de nuevo sin que se
apague al salir, usa:

```bash
kemper-rig-manager --dejar-abierto
```

**Si al cerrar la ventana te sale «Do you want to close the session?»** (en inglés,
con casilla *Do not ask me again*), eso **no es del lanzador** (el lanzador ya no
pregunta nada): es una confirmación propia de `virt-viewer`. Pulsa **OK** y la
ventana se cerrará y Windows se apagará solo. El lanzador y el instalador **la
dejan desactivada**, pero `virt-viewer` puede volver a activarla sola; para
quitarla a mano:

```bash
sed -i 's/^ask-quit=.*/ask-quit=false/' ~/.config/virt-viewer/settings
```

### Qué NO hacer
- **No uses Rig Manager y tu editor nativo a la vez**: sólo uno puede tener el aparato.
- **No arranques REAPER con un proyecto grande a la vez** que la VM si vas justo de
  memoria: la VM reserva 6 de los 14 GiB.
- **No cierres la ventana a lo bruto** mientras Rig Manager esté escribiendo en el
  Kemper (backup o actualización del sistema operativo).

## 8. Registro de ejecución y arbitraje adversarial

Metodología: cada fase la cierra un **verificador independiente** que no ha participado en el
trabajo y cuyo cometido es **intentar falsear** el criterio de aceptación. Si lo consigue, la
fase no cierra. Los veredictos se archivan en `evidencia/`.

| Fase | Estado | Evidencia | Veredicto del árbitro |
|---|---|---|---|
| F0 — Andamiaje y reconocimiento | **cerrada** | `evidencia/F0-recon.txt`, `evidencia/F0-veredicto-arbitro.md`, `evidencia/F0-arbitro-transcript.log` | **SOSTIENE el escrutinio** — 0 bloqueantes, 0 importantes, 3 menores corregidos |
| F1 — Plataforma de virtualización | ⏳ espera la acción humana (`sudo`) | — | — |
| F2 — Medio de instalación desatendida | **cerrada** | `install/autounattend.xml` (corregido tras el primer intento), `install/kemper-install.iso` (308 MB, `autounattend.xml` en la raíz) | Validada contra el esquema de libvirt en lo que toca; **el medio se probó de verdad**: el primer intento reveló el fallo de la página de clave |
| F3 — Dominio + Windows instalado | **cerrada** | `evidencia/instalacion/`, `evidencia/F5-*` | Windows build 26100, TPM 2.0 real, red 192.168.122.10 |
| F4 — Passthrough USB del Profiler | **cerrada** | agente: 4 dispositivos Kemper con Status OK | Las 4 interfaces en `usbfs` (las tiene QEMU) |
| F5 — Rig Manager ↔ Profiler | **cerrada** | `evidencia/F5-rigmanager-conectado.md` + captura | MyProfiler 591 rigs, cadena de señal y valores reales leídos del aparato |
| F6 — Lanzador Ubuntu + reversibilidad | **cerrada** | lanzador/icono oficial/menú instalados; `logs/lanzador.log` con un ciclo completo (arranque → Kemper conectado → ventana → cierre); prueba del usuario desde el menú; `evidencia/F-audio-scarlett-enrutado-antes.txt` | `--estado` correcto en ambos estados (apagada/encendida); el `attach` del Kemper que falló al principio ahora funciona en el ciclo real |
| F7 — Intercambio de ficheros | **cerrada** | hashes idénticos ida y vuelta (31488 bytes) | Sin disco compartido: por el agente de invitado |
| F8 — Manual y prueba de fuego | **cerrada** | `evidencia/F8-prueba-desde-cero.md` (registro del invitado con los tres `exit=0`) | Máquina nueva instalada sola en ~6 min; los 3 MSI con `exit=0` |

---

## 9. Riesgos abiertos y planes B

| # | Riesgo | Estado | Plan B |
|---|---|---|---|
| 1 | **Contraseña de la cuenta de Windows** documentada (`kemper`) | Aceptado y documentado | Cambiarla dentro de Windows; si se cambia, actualizar también el auto-arranque (`Winlogon`) o perderás el acceso automático |
| 2 | **RAM del host**: 14 GiB; la VM reserva 6 | Aceptado | Bajarla a 4 GiB y reiniciar |
| 3 | **Un solo dueño del USB**: mientras la VM lo tiene, el editor nativo de Linux no lo ve | Inherente al USB | El lanzador avisa y devuelve el aparato al apagar |
| 4 | **Windows en inglés** (la ISO es `en-us`) | Aceptado | Añadir el teclado español en Ajustes; cambiar el idioma de la interfaz exige el paquete de idioma |
| 5 | **Windows sin activar** (marca de agua) | Aceptado | Poner una licencia; la LTSC no caduca, no hay apagones |
| 6 | **El Kemper tiene OS 14.1.2 y Rig Manager espera 14.2** | Detectado, sin resolver | Actualizar el sistema operativo desde el propio Rig Manager (menú PROFILER) — es una de las cosas que el usuario quería poder hacer |
| 7 | Permisos (DAC/AppArmor) sobre los medios del proyecto | Mitigado con ACL | `sudo bash scripts/fix-perms.sh` |
| 8 | ~~Despliegue desde cero sin probar~~ | **CERRADO**: probado en una máquina nueva, ~6 min, sin intervención humana | Evidencia: `evidencia/F8-prueba-desde-cero.md` |

## 10. Solución de problemas y trampas comprobadas

### Lo que ve el usuario (por síntoma)

| Síntoma | Qué pasa | Qué hacer |
|---|---|---|
| El lanzador no aparece en el menú | La sesión es anterior a la instalación del lanzador o al cambio de grupos | Cierra sesión y entra de nuevo |
| «No puedo hablar con libvirt» | Tu sesión no tiene el grupo `libvirt` (se aplica a sesiones nuevas) | Cierra sesión y entra de nuevo |
| **Rig Manager se queda en «Scanning for profilers…»** | El aparato está encendido pero **no está conectado a la VM**: Rig Manager mira el USB de Windows y ahí no hay nada | 1) `kemper-rig-manager --estado` (debe decir `Kemper en la VM: sí`). 2) Si dice `no`: `scripts/40-conectar-kemper.sh`. 3) Si no estaba encendido al abrir, enciéndelo y el vigilante lo conecta solo en unos segundos |
| Rig Manager dice que no hay Kemper | El aparato está enchufado pero no conectado a la VM, o está apagado | `kemper-rig-manager --estado` y luego `scripts/40-conectar-kemper.sh` |
| Tu editor nativo no ve el Kemper | La VM lo tiene secuestrado | Cierra la ventana (Windows se apaga solo) o `kemper-rig-manager --apagar` |
| El Kemper no vuelve a Linux tras apagar | Algunos aparatos no re-enumeran solos | Desenchufa y vuelve a enchufar el USB |
| Al cerrar la ventana pregunta **«Do you want to close the session?»** | Es la confirmación propia de `virt-viewer` (clave `ask-quit`), no del lanzador | Pulsa OK: la ventana se cierra y Windows se apaga solo. Si reaparece, desactívala (ver §10, trampas, o `sed -i 's/^ask-quit=.*/ask-quit=false/' ~/.config/virt-viewer/settings`) |
| Cierro la ventana y **Windows sigue encendido** | Con la versión del lanzador anterior al 31-oct aparecía un diálogo *«¿Apago Windows?»* cuyo botón de cerrar (la X) valía como «no apagar» | Actualiza el lanzador: `bash scripts/70-instalar-lanzador.sh`. Desde esa versión, cerrar la ventana apaga Windows **sin preguntar** |
| **Deja de oírse el audio del ordenador** (YouTube, REAPER) por la Scarlett, aunque todo parezca correcto | Casi nunca es PipeWire: el audio **llega** al aparato, pero las **salidas 1 y 2 de la Scarlett** quedan enrutadas a un mezclador interno (*Mix B*) que no lleva la reproducción del ordenador. El baile de dispositivos USB de este proyecto puede desencadenarlo | Diagnóstico y arreglo en §10 (trampas): capturar el destino y apuntar `Analogue Output 01/02` a `PCM 1/2` |
| Windows muestra «Activate Windows» | No hay licencia: es normal | Se le puede poner clave; mientras, todo funciona |
| El teclado sale en inglés | La ISO LTSC es sólo en inglés | Añadir el teclado español en *Settings → Time & language → Language & region*; si no aparece, requiere el paquete de idioma |
| «Rig Manager no arranca» dentro de la VM | Puede faltar una dependencia en el invitado | Mira `C:\kemper-install.log` y `C:\log-rigmanager.log` dentro de la VM |
| La VM arranca del DVD otra vez | No se expulsaron los ISO | `scripts/50-expulsar-isos.sh` |
| «Permission denied» al arrancar la VM | Las ACL de los medios no están (restauración de copias, carpeta recreada) | `sudo bash scripts/fix-perms.sh` |
| «Permission denied» al abrir `/var/run/libvirt/libvirt-sock` | Tu sesión abierta no tiene el grupo `libvirt` | Cierra sesión y entra de nuevo. **Atajo temporal, sin cerrar sesión:** `sudo setfacl -m u:olmost:rw /run/libvirt/libvirt-sock /run/libvirt/libvirt-sock-ro` (se pierde al reiniciar; no sustituye al cierre de sesión) |

### Trampas de herramientas (para quien mantenga esto)

- **`virt-viewer` tiene su propia confirmación al cerrar y tapa la nuestra.**
  Su diálogo *«Do you want to close the session?»* llega **antes** que el del
  lanzador, y el usuario concluye (con razón) que «no me pregunta si apagar
  Windows». No hay opción de línea de comandos: vive en `~/.config/virt-viewer/settings`
  como `ask-quit=true|false`, y **virt-viewer puede reescribir el fichero**, así que
  el lanzador lo reasegura en cada arranque (función `asegurar_virt_viewer_sin_pregunta`).
- **Nunca uses `pkill -f <patrón>` desde una línea de órdenes que contenga las
  palabras del patrón.** El proceso mata *su propio shell*: `pkill -f` compara
  contra la línea de órdenes completa, y la tuya incluye el patrón. Comprobado tres
  veces en este proyecto (una vez matando la sesión del asistente a media faena, con
  «virt-viewer» y «kemper-win11» en el mismo comando). Dos salidas limpias:
  1. si el patrón va dentro de un **script**, su línea de órdenes es sólo
     `bash /ruta/script.sh` y no coincide: es seguro;
  2. para identificar procesos de verdad, **filtra por el ejecutable**, no por el
     texto (`/proc/PID/exe`), que no puede dar falsos positivos:
     ```bash
     for p in $(pgrep -f virt-viewer); do
       [[ "$(readlink -f /proc/$p/exe)" == *virt-viewer* ]] || continue
       kill "$p"
     done
     ```
  Y para *contarlos* sin contarte a ti mismo, mete el patrón entre corchetes
  (`grep '[v]irt-viewer'`): un `grep` normal sobre `ps` también se encuentra a sí
  mismo y da cifras infladas (aquí reportó «2 ventanas zombis» que no existían).
**Resolución de la pantalla de Windows (`RESOLUCION_VM`).** Acepta `auto` (por
defecto: Windows elige) o un tamaño `ANCHOxALTO`. Con un tamaño concreto, la fase 3
escribe `payload/resolucion.txt` dentro del medio y `payload/resolucion.ps1` lo
aplica **dentro de Windows** (`ChangeDisplaySettings`, por P/Invoke sobre un bloque
de bytes con el DEVMODEA; sin dependencias externas ni internet). Se aplica dos
veces a propósito: en la instalación y otra vez en el primer inicio de sesión vía
`RunOnce`, porque hasta que el driver de vídeo no está cargado el cambio no cuaja.
Si falla, lo apunta en `C:\log-resolucion.txt` y Windows se queda como estaba: es
un ajuste de comodidad y nunca debe romper nada. (Lo de "seguir a la ventana" es
otra cosa: lo hace el agente de pantalla de SPICE, que este proyecto **no** instala
—no está verificado que el paquete `virtio-win-guest-tools.exe` lo incluya—.)

- **Al comprobar los textos, recorrer las claves USADAS, no las DEFINIDAS.** Una
  vuelta de comprobación imprimía todas las claves que existían en las tablas: dio
  "cero fallos" y no valía nada, porque el fallo estaba en tres claves que los
  scripts **usaban sin texto** (`MENU_OK`, `MENU_AVISO`, `MENU_SIN_PLANTILLA`) y
  que, al no estar definidas, nunca entraban en la lista. La comprobación buena
  pregunta a la propia librería por cada clave que aparece en el código y busca el
  `[[CLAVE]]` que imprime cuando falta. Fallo real, visto al ejecutar la fase 7 en
  un entorno limpio.
- **Al primer arranque de Windows, Rig Manager no funciona bien hasta reiniciar.**
  Windows acaba de instalar los drivers de virtio y el agente de invitado, y parte
  de ellos sólo entran en servicio tras un reinicio: el primer lanzamiento puede
  quedarse a medias o pedir el reinicio expresamente. Es comportamiento normal, no
  un fallo de la instalación — y conviene decirlo, porque a un usuario nuevo le
  parece que ha fallado (así lo reportó uno en su prueba). Está avisado en el
  mensaje final del instalador y en las dos guías de usuario.
- **Dos fases que no hablan entre sí.** La fase 2 descarga el ISO de virtio-win a
  `install/virtio-win.iso` cuando el usuario pulsa Enter; la fase 3 buscaba el ISO
  en la clave `VIRTIO_ISO` de la configuración. Resultado: descargar 880 MB no
  servía de nada y la siguiente fase decía que faltaban los drivers. Fallo real,
  detectado por un usuario que siguió ese camino (el que yo nunca recorrí: en mis
  pruebas el ISO siempre estaba en disco). Ahora la fase 3 mira en los dos sitios.
  **Al añadir un paso que produce un fichero, comprobar quién lo consume y con qué
  ruta** — y recorrer el camino «lo genera el propio instalador», no sólo el de
  «el usuario ya lo tiene».
- **El lector de configuración se queda con la ÚLTIMA aparición de cada clave**
  (comprobado: `cfg_leer_conf` recorre el fichero asignando, así que la última
  línea gana). Sirve para saber que añadir `CLAVE=valor` al final del `.conf`
  sustituye lo anterior — y para no sacar conclusiones de pruebas mal montadas:
  una comprobación que apunte a un fichero distinto del que lee el instalador
  demuestra exactamente nada. (Me pasó, y publiqué la conclusión contraria.)
- **`printf` se come los textos que empiezan por guión.** La capa de idiomas imprime
  los mensajes con `printf` (porque los textos llevan huecos `%s`). Un mensaje que
  empieza por `--` —por ejemplo las líneas de la lista de paquetes, `-- núcleo: ...`—
  hace que `printf` lo tome por una opción suya y **aborte el script entero**:
  `printf: --: invalid option`. La solución es `printf -- "$texto"`. Fallo real,
  detectado al instalar en un Debian y no en las pruebas anteriores: al verificar la
  conversión a dos idiomas ejecuté las fases 3 y 7, pero no la 1 ni la 5, que son
  justo las que tienen mensajes que empiezan por guión. **Moraleja: al cambiar el
  sistema de mensajes hay que ejecutar TODAS las fases, no las que resulten cómodas.**
  Y al buscar fallos, recorrer **todos** los mensajes uno a uno (aquí se probaron los
  692 de los dos idiomas, que es lo que confirmó que no quedaba ninguno más).
- **Nunca dejes un nombre de usuario fijo como valor por defecto.** Aquí había dos
  `USUARIO="${SUDO_USER:-<nombre del autor>}"` en `00-setup-root.sh` y `fix-perms.sh`.
  En la máquina del autor nunca se nota (SUDO_USER siempre está definido); en la de
  otro, si se ejecuta desde un shell de root, el script intenta meter en el grupo
  `libvirt` a un usuario que no existe. Usa `${SUDO_USER:-$(logname 2>/dev/null)}` y
  **aborta con un mensaje claro si no hay ninguno**. Lección general al compartir:
  audita también los *nombres* sueltos, no sólo las rutas (`/home/<usuario>`);
  buscar sólo rutas se deja esto fuera.
- **Un cambio de grupo obliga a parar el flujo, no a seguir de largo.** La fase 1 mete
  al usuario en el grupo `libvirt`, pero eso no llega a la sesión ya abierta. El
  instalador encadenaba las fases y seguía: la fase 4 fallaba con un «no puedo hablar
  con libvirt» que no se entiende. Ahora, si la sesión todavía no tiene el grupo, el
  instalador **se para, lo dice y pide cerrar sesión** (`./install.sh --continuar`
  después). Regla: cuando un paso deja el sistema en un estado que requiere reentrar,
  el programa tiene que pararse ahí; el texto del README no basta.
- **No pidas confirmación con un diálogo Sí/No en un flujo que el usuario dispara
  cerrando una ventana.** La X del diálogo y la tecla Escape valen como *Cancelar*,
  indistinguibles de un «No» deliberado: el usuario cerró la ventana, cerró el
  diálogo creyendo que confirmaba, y Windows siguió encendido dos veces seguidas sin
  que se enterara (quedó en `logs/lanzador.log` como `usuario eligió NO apagar`).
  Regla: **la acción por defecto se hace sin preguntar**, y la excepción (aquí
  `--dejar-abierto`) se pide explícitamente. Se intentó antes distinguir «X» de
  «Cancelar» y no se puede: `zenity --question` devuelve el mismo código en ambos.
- **Cuando no se oye el ordenador por una interfaz USB, primero mide si el audio
  LLEGA al aparato.** Capturar el propio destino distingue «PipeWire no entrega
  audio» de «entrega audio y el aparato no lo saca», que son problemas distintos:
  ```bash
  timeout 10 pw-record --target=<id_sink> --rate=48000 --channels=2 \
      -P '{ stream.capture.sink = true }' /tmp/c.wav
  ffmpeg -hide_banner -i /tmp/c.wav -af volumedetect -f null - 2>&1 | grep mean_volume
  ```
  Aquí dio `mean_volume: -18.6 dB` con la Scarlett muda: el audio sí llegaba. La
  culpa estaba en el **enrutado dentro de la interfaz**: los controles "Analogue
  Output 01/02" apuntaban a `Mix B` (un mezclador interno sin reproducción del
  ordenador) en lugar de a `PCM 1/2`. Arreglo, leyendo antes el valor viejo para
  poder volver atrás (en este caso se guarda en `evidencia/F-audio-scarlett-enrutado-antes.txt`):
  ```bash
  amixer -c 1 sget 'Analogue Output 01'        # ver el valor actual ('Mix B')
  amixer -c 1 sset 'Analogue Output 01' 'PCM 1' # outputs 1/2 <- ordenador
  amixer -c 1 sset 'Analogue Output 02' 'PCM 2'
  ```
  Ojo: esto vive en el **hardware** de la interfaz y con `Standalone` desactivado
  puede perderse al cortarle la corriente; si vuelve a pasar, hay que reaplicarlo
  (o montar un servicio de usuario que lo haga al iniciar sesión).
- **Un comentario XML no puede contener `--`.** `<!-- virsh attach-device ... --live -->`
  es XML inválido y el fichero deja de parsear. Costó un fallo silencioso en
  `config/hostdev-kemper.xml`. Si añades notas con opciones de línea de órdenes,
  descríbelas o sácalas del comentario.
- **No valides un SVG con ImageMagick.** Su intérprete interno se comió la curva
  Bézier del icono y lo habría dado por bueno sin verlo. Un navegador (o `librsvg`)
  es la referencia. Está comprobado: el mismo fichero se ve bien en el navegador y
  mal con `convert`.
- **`apt-cache` habla tu idioma.** Con el locale en español, la búsqueda de
  «Candidate:» no encuentra nada y se concluye falsamente que un paquete no existe.
  Usa `LC_ALL=C` o busca «Candidato:».
- **Los nombres de edición de Windows no están en `install.wim` en texto plano.**
  El XML del WIM va en **UTF-16 al final del fichero**: `strings` y `grep` no ven
  nada. Se leen los últimos cientos de KB y se decodifica como UTF-16LE.
- **`7-Zip` sí lista un WIM** (`Images = 3`), pero para el nombre de cada edición
  hay que ir al XML.
- **El medio de Windows pregunta siempre** *«Press any key to boot from CD»*: en
  una instalación desatendida hay que enviar una tecla (o el arranque cae al disco
  vacío). Después, no pulsar nada es justo lo correcto.
- **`virsh send-key` / `virsh screenshot` son la mano y el ojo** en una instalación
  sin ratón. Con ellos la instalación se controla y se demuestra.
- **La ruta del proyecto tiene espacios** (`Rig Manager VM`). Todo va entre comillas
  dobles en los scripts; tenlo en cuenta al añadir comandos nuevos.
- **Una cuenta local creada SIN contraseña queda INUTILIZABLE.** Windows la marca
  con *«The user's password must be changed before signing in»* y no deja entrar:
  la instalación se queda **para siempre** en la pantalla de inicio de sesión, con
  el botón «Sign in» y sin campo de contraseña. Es un callejón sin salida, y el
  inicio de sesión automático tampoco funciona con ella. Solución: contraseña
  explícita en `<LocalAccount>` **y** en `<AutoLogon>`. En este proyecto la cuenta
  es `kemper` con contraseña `kemper` (documentada, cambiable; ver §9).
- **No pulses teclas «un rato» para pasar el aviso del DVD: se pueden comer un
  botón.** El aviso *«Press any key to boot from CD or DVD»* invita a enviar
  pulsaciones durante unos segundos. En un arranque rápido, esas pulsaciones siguen
  llegando cuando ya está la pantalla azul del setup, que tiene un botón **Cancel**:
  apareció el diálogo *«Are you sure you want to quit?»* y la instalación se quedó
  parada detrás de él (5 % de progreso, sin escribir en disco). **Recuperación:** el
  botón enfocado es **«No»**, así que una sola tecla `ENTER` continúa la instalación.
  **Método correcto (el que usa `30-instalar-windows.sh`):** no pulsar por tiempo,
  sino **midiendo la pantalla**. Se captura con `virsh screenshot`, se reduce a 1×1
  píxel con ImageMagick y se mira el brillo medio: el firmware y el aviso del DVD
  son **negros (< 0,12)** y la pantalla del setup es **azul (~0,30)**. Se pulsa
  mientras esté oscuro y se para al iluminarse. Verificado con las capturas reales
  de este proyecto: todas las pantallas con botones dieron ≥ 0,14.
- **`xorriso -as mkisofs` NO conserva el nombre del directorio que le pasas**: con
  `xorriso ... -o x.iso autounattend.xml payload`, el **contenido** de `payload/`
  acaba en la **raíz** del ISO en vez de dentro de `payload/`. Consecuencia real
  aquí: la orden del fichero de respuestas busca `payload\instalar.cmd`, no lo
  encuentra **y no pasa nada visible** — la instalación termina y el programa
  simplemente nunca se instala. Hay que usar `-graft-points` y escribir las rutas
  explícitas (`/payload=payload`). Se puede arreglar **en caliente** sobre una
  máquina ya instalando: `virsh change-media <dom> sdb --update <iso-corregido> --live`
  (el fichero de respuestas ya está cacheado en el disco y su orden busca el medio
  en cualquier unidad).
- **No filtres con `head` la salida de un proceso que escribe un fichero.**
  `xorriso ... | head -3` cierra la tubería, el proceso recibe SIGPIPE y **el ISO
  queda a medias sin que el comando falle de forma evidente**. Misma familia de
  trampas que el `setfacl -R` mal hecho y el `virsh` traducido: el error no se
  anuncia solo.
- **Un `.cmd` se escribe SÓLO en ASCII y sin comillas en los comentarios.**
  `cmd.exe` lee el fichero con la página de códigos del sistema, no en UTF-8: unos
  acentos en un comentario bastaron para que el intérprete abortara con *«The syntax
  of the command is incorrect»*. Y nada de cirugía de cadenas para adivinar rutas:
  mejor comprobar que existe el fichero esperado.
- **En Windows, una barra invertida antes de la comilla de cierre se interpreta como
  comilla escapada.** Pasar `-Media "D:\"` a PowerShell le entrega `D:\"` (con una
  comilla dentro) y la ruta queda rota: el programa intentaba abrir `D:\" + payload`.
  Lo correcto: pasar la unidad **sin** barra final y normalizarla dentro del script
  (`$Media = $Media.TrimEnd('\') + '\'`).
- **Escribir en la RAÍZ de `C:\` necesita elevación.** Desde una consola no elevada,
  `echo hola > c:\prueba.txt` responde *«Access is denied»*. Y hay un efecto en
  cascada: **si una redirección falla, `cmd` NO ejecuta la orden**. Eso hizo que un
  guion «se ejecutara» sin hacer nada (dos «Access is denied» eran sus dos
  redirecciones al registro). En el flujo real no pasa, porque `FirstLogonCommands`
  corre elevado; al lanzarlo a mano hay que abrir la consola **como administrador**.
- **`change-media --update` NO hace que Windows relea el disco.** El invitado sigue
  viendo el contenido anterior y las rutas «no existen». Hay que **expulsar e
  insertar** (`--eject` y luego `--insert`) para que llegue el evento de bandeja.
- **Un diálogo modal bloquea los clics a la ventana de debajo.** Si algo no responde
  a un clic, lo primero es mirar si hay un diálogo encima (el del cortafuegos de
  Windows, sin ir más lejos).
- **Un botón del ratón hay que MANTENERLO pulsado.** Si se envían «mover + apretar +
  soltar» en el mismo lote de eventos, el invitado ve el movimiento pero no la
  pulsación (el sondeo del HID no llega a verla). Hay que separarlo en tres órdenes,
  con ~150 ms apretado. Es lo que hace `scripts/90-clic.py`.
- **El agente de invitado devuelve cosas con formas distintas:** `guest-file-open`
  devuelve **un número** (el descriptor), no un objeto; y ese descriptor hay que
  cerrarlo **siempre**, incluso si falla a mitad, o el fichero queda bloqueado dentro
  de Windows (*«being used by another process»*).
- **Un fichero abierto por dos vías pelea consigo mismo:** con `>> C:\log.txt` en el
  `.cmd` y `Add-Content` del script de PowerShell al mismo fichero, las escrituras del
  segundo fallan. Cada uno con su registro.
- **`lsusb` no dice quién tiene un dispositivo USB.** Un aparato pasado a la máquina
  virtual **sigue apareciendo** en `sysfs`. Y siendo **compuesto**, además puede
  conservar alguna interfaz enlazada. El criterio fiable es **qué controlador tiene
  cada interfaz**: `usbfs` = lo tiene un programa de usuario (QEMU);
  `snd-usb-audio` = está en Linux. Costó dos versiones equivocadas de esta
  comprobación (el lanzador llegó a decir «Kemper en Linux: sí» mientras Windows lo
  estaba usando).
- **Un script llamado a través de un ENLACE calcula mal su propia carpeta.**
  `${BASH_SOURCE[0]}` devuelve la ruta **con la que se llama**, no la real: si el
  menú ejecuta `~/.local/bin/kemper-rig-manager` (un enlace), `dirname .../..` daba
  `~/.local` en vez de la carpeta del proyecto. Consecuencia real y muy confusa: el
  lanzador **arrancaba Windows perfectamente** pero buscaba
  `config/hostdev-kemper.xml` en `~/.local/config`, no lo encontraba, y **no
  conectaba el Kemper** — Rig Manager se quedaba en *«Scanning for profilers…»*
  para siempre. Se arregla resolviendo el enlace antes de nada:
  `SCRIPT="$(readlink -f "${BASH_SOURCE[0]}")"`. Regla: **cualquier script que
  pueda invocarse por enlace debe resolver su ruta real**.
- **El orden de encendido no debe importar.** Aunque el lanzador conecte el Kemper
  al abrir, si el aparato estaba apagado en ese momento no hay nada que conectar.
  Por eso existe `scripts/45-vigilar-kemper.sh`: el lanzador lo deja en segundo
  plano y, mientras la VM esté en marcha, conecta el Kemper **en cuanto aparece**.
- **`virsh` traduce sus mensajes al idioma del sistema.** En un Ubuntu en español
  `virsh domstate` devuelve **`ejecutando`**, no `running`. Un script que compare su
  salida contra `running` se cree que la máquina está apagada y aborta **sin que nada
  esté roto**: ya pasó aquí y el vigilante de la instalación se detuvo solo. Todos los
  scripts de este proyecto empiezan con `export LC_ALL=C`. Regla general: **nunca
  compares la salida de una herramienta del sistema sin forzar el idioma**.
- **Un fichero de respuestas aplicado no basta: hay que cerrar las puertas que abre.**
  Si en `<UserData>` no hay `<ProductKey>` con `<WillShowUI>Never</WillShowUI>`, el
  asistente **se para en la página «Product key»** aunque el `autounattend.xml` se haya
  leído y aplicado correctamente (síntoma inequívoco: no aparece el diálogo de idioma,
  pero sí la petición de clave). Se resuelve con la **GVLK pública** que Microsoft
  publica para esa edición —Windows IoT Enterprise LTSC 2024 → ``<CLAVE-GVLK>``,
  en la lista oficial de claves KMS de cliente—. Ojo: la clave **selecciona la imagen**,
  así que tiene que ser la de la edición que se quiere instalar (una clave de Pro haría
  fallar la instalación por no encontrar imagen). Esa clave **no activa nada** por sí
  sola: sin licencia ni servidor KMS, Windows queda sin activar.
- **Reejecutar el instalador puede cancelar la instalación.** El script manda
  pulsaciones de tecla al principio para pasar el aviso *«Press any key to boot from CD»*.
  Si la máquina **ya está instalando**, esas pulsaciones llegan a una pantalla que tiene
  botón **Cancel** y la cancelan. Por eso el script sólo teclea si es él quien arranca
  la máquina, y existe el modo `--solo-vigilar` (no arranca nada ni pulsa nada).
- **`sg` y `newgrp` no siempre existen** (en esta máquina no están), así que «cambiar de
  grupo sin cerrar sesión» no es una opción fiable: hay que entrar de nuevo, o conceder
  el socket con `setfacl` (ver la tabla de síntomas).
- **El icono de un programa de Windows no suele ser un fichero.** Aquí vive dentro de
  un `RigManagerIcon.exe` en `C:\WINDOWS\Installer\`. Y para leerlo desde Linux hay
  que pasar por `wrestool`/`icotool` (paquete `icoutils`, que se puede usar **sin
  instalarlo**, extrayendo el `.deb`), porque `icotool` no acepta el `.exe` entero:
  primero se saca el recurso de tipo 14 (grupo de iconos) y luego se convierte.
- **No sobrescribas nunca `~/.local/share/icons/hicolor/index.theme`.** Ese fichero
  (55 KB en este sistema) describe todos los directorios del tema; reemplazarlo por
  uno propio escrito a mano deja de dar contexto al resto de iconos. Si te lo
  encuentras roto, se restaura desde `/usr/share/icons/hicolor/index.theme`, que en
  este sistema es idéntico.
- **`gtk-update-icon-cache` puede avisar «The generated cache was invalid»**: es un
  aviso inofensivo, pero ante la duda **borra la caché** (`.icon-theme.cache`): GTK
  escanea los directorios igual y un fichero de caché roto sí que puede dar guerra.
- **Los paquetes de Ubuntu cambian de nombres**: en Ubuntu 26.04 `ovmf` es un
  metapaquete (`ovmf-generic`, `ovmf-amdsev`, `ovmf-inteltdx`).
- **Cuidado con `setfacl -R -m u:usuario:r`.** A los **directorios** les quita el
  permiso de paso (`x`) y el usuario deja de poder abrir cualquier fichero que
  haya dentro, aunque los ficheros sigan marcados como legibles. Costó un fallo
  real en este proyecto. Para directorios y ficheros, dos pasadas distintas
  (`-type d` con `rx`, `-type f` con `r`).
- **`sg` y `newgrp` pueden no existir.** En esta máquina no están instalados, así
  que «cambiar de grupo sin cerrar sesión» no es una opción: hay que entrar de
  nuevo (o conceder el socket con `setfacl`, ver §10).
- **Valida el XML del dominio ANTES de definir la VM**: `virt-xml-validate
  config/kemper-win11.xml domain` lo comprueba contra el esquema oficial de
  libvirt y es instantáneo.

**La clave**, cuando haga falta, se copia de la lista oficial de Microsoft
(claves genéricas de instalación, GVLK) para tu edición concreta:
https://learn.microsoft.com/es-es/windows-server/get-started/kms-client-activation-keys
Este repositorio no incluye ninguna clave de producto.


## 11. Desinstalación total

Para dejar la máquina como estaba. En orden, y sólo si de verdad quieres eliminarlo:

```bash
# 1. Apagar y borrar la máquina virtual (y con ella, Windows)
virsh -c qemu:///system destroy  kemper-win11
virsh -c qemu:///system undefine kemper-win11 --nvram --remove-all-storage

# 2. El lanzador y su icono (sólo tuyos, sin root)
rm -f ~/.local/bin/kemper-rig-manager
rm -f ~/.local/share/applications/kemper-rig-manager.desktop
rm -f ~/.local/share/icons/hicolor/scalable/apps/kemper-rig-manager.svg
update-desktop-database -q ~/.local/share/applications || true

# 3. Las ACL concedidas a QEMU sobre tu carpeta personal
sudo setfacl -x u:libvirt-qemu "$HOME" "$HOME/Documentos" \
     "${PROYECTO}"
sudo setfacl -R -x u:libvirt-qemu "${PROYECTO}" 2>/dev/null || true

# 4. Los paquetes (opcional; libvirt lo puede usar otro software)
sudo apt purge qemu-system-x86 qemu-utils libvirt-daemon-system libvirt-clients \
     virtinst virt-manager virt-viewer ovmf swtpm swtpm-tools xorriso
sudo apt autoremove
```

**Lo que NO se borra con esto:** tus ficheros del proyecto (`MANUAL-...md`, scripts,
ISO, `config/`). Borra la carpeta a mano cuando estés seguro — recuerda que dentro
están la ISO de Windows y el MSI de Rig Manager.

**Aviso:** si has usado la VM para descargar tus backups o el Rig Exchange, **saca
antes esos ficheros** de la VM: al hacer `undefine` con `--remove-all-storage` se
va el disco entero.

## 12. Glosario para no iniciados

| Término | Qué es, en una frase |
|---|---|
| **KVM** | La parte de Linux que usa las instrucciones de virtualización del procesador para que una máquina virtual corra casi a velocidad nativa. |
| **QEMU** | El programa que *construye* la máquina virtual (discos, red, USB, vídeo). Con KVM detrás, va rápido. |
| **libvirt / `virsh`** | El "mando a distancia" de QEMU: una capa que gestiona las máquinas virtuales de forma ordenada. `virsh` es su línea de órdenes. |
| **`qemu:///system`** | La forma de virtualización "del sistema" (la VM la arranca un servicio con privilegios). Es la que permite pasar el USB sin pelearse con permisos. |
| **Dominio** | En libvirt, una máquina virtual. La de este proyecto se llama `kemper-win11`. |
| **Invitado / huésped** | El Windows que corre dentro de la máquina virtual. |
| **Anfitrión / host** | Tu Ubuntu, que es quien ejecuta la máquina virtual. |
| **Passthrough / `hostdev`** | "Pasar" un dispositivo físico (el Kemper por USB) dentro de la máquina virtual como si estuviera enchufado a ella. |
| **virtualización acelerada / emulada** | Acelerada = usa el procesador (rápido). Emulada = simula instrucciones (lento). Aquí siempre acelerada. |
| **UEFI / OVMF** | El sistema de arranque moderno. OVMF es su versión libre, la que necesita Windows 11. |
| **TPM** | Un chip de seguridad que Windows 11 exige. Aquí se emula por software (`swtpm`). |
| **ISO** | La "imagen de disco" de un CD/DVD: un fichero único que contiene el instalador. |
| **`install.wim`** | El fichero dentro del ISO de Windows que contiene Windows ya instalado, listo para copiarse al disco. |
| **MSI** | El formato de instalador de Windows (el de Rig Manager lo es). |
| **Autounattend / desatendido** | Un fichero de respuestas que hace que Windows se instale solo, sin preguntar nada. |
| **Rig / Performance / IR** | Un "sonido" completo del Kemper / una lista de sonidos para un directo / una respuesta de altavoz capturada. |
| **Virtio** | Los drivers "de verdad" para máquinas virtuales: hacen que el disco, la red y el vídeo vayan rápido en lugar de "como un PC de 1999". |

---

## 13. Inventario de scripts y ficheros

**Lo que NO está en el repositorio** (y no puede estarlo): la ISO de Windows, el
instalador de Rig Manager, los `.msi` de virtio/qemu-ga, el icono oficial de
Rig Manager (es de Kemper) y tu `config/kemper-vm.conf` (lleva tus rutas y tu
contraseña). Todo eso lo aporta cada usuario o lo genera el instalador en su
equipo; el `.gitignore` lo impide.

| Fichero | Para qué sirve |
|---|---|
| `scripts/00-setup-root.sh` | **Único paso con contraseña**: instala la plataforma, grupos, red y permisos |
| `scripts/10-build-install-iso.sh` | Construye el medio de instalación desatendida |
| `scripts/20-crear-vm.sh` | Crea el disco (vía el demonio) y define el dominio |
| `scripts/30-instalar-windows.sh` | Arranca, pasa el aviso del DVD midiendo la pantalla, y vigila |
| `scripts/40-conectar-kemper.sh` | Pasa el Kemper a la VM y verifica quién lo tiene |
| `scripts/45-vigilar-kemper.sh` | Conecta el Kemper **en cuanto aparece** (lo lanza el lanzador) |
| `scripts/50-expulsar-isos.sh` | Expulsa los DVD tras la instalación |
| `scripts/70-instalar-lanzador.sh` | Instala el lanzador, el icono y el menú |
| `scripts/90-verificar-windows.py` | Verificación completa **dentro** de Windows por el agente |
| `scripts/90-escribir.py` | Teclea en el invitado (tecla a tecla; `virsh` manda acordes) |
| `scripts/90-clic.py` | Ratón por coordenadas en el invitado (mantiene el botón apretado) |
| `scripts/95-intercambio.py` | Pasa ficheros Ubuntu ↔ Windows (verificado con hashes) |
| `scripts/kemper-rig-manager` | **El lanzador**: arranca, conecta el Kemper, abre la ventana y apaga |
| `scripts/fix-perms.sh` | Repara permisos si la VM no arranca por DAC/AppArmor |
| `install.sh` | **El instalador**: fases reanudables, comprobación de requisitos y asistente de configuración |
| `config/kemper-vm.conf.example` | Plantilla de configuración: nombre de la VM, RAM, núcleos, disco y **tus** rutas de medios |
| `config/vm-domain.xml.in` | Plantilla del dominio. La definición real (`config/<tu-vm>.xml`) se **genera** de aquí |
| `config/hostdev-kemper.xml` | El aparato USB (se conecta en caliente, nunca fijo en el dominio) |
| `lib/config.sh` `lib/config.py` | Lectura de la configuración (y por qué no se usa `source`: ver §10) |
| `install/autounattend.xml.in` | Plantilla del fichero de respuestas. El real se **genera** con tus datos |
| `install/payload/` | Los guiones que corren **dentro** de Windows. Los `.msi` los pone cada usuario |

## 14. Versiones verificadas y evidencias

> Las **evidencias** que se citan abajo (capturas incluidas) son de la máquina
> donde se desarrolló y verificó todo esto. **No se publican** en el repositorio
> porque llevan imágenes del equipo de su autor; el `.gitignore` las excluye.
> Lo que sí se publica es lo que demuestran: los datos de la tabla siguiente.

Comprobado en la máquina de desarrollo el 31-oct-2026:

| Pieza | Versión |
|---|---|
| Ubuntu | 26.04.1 LTS («resolute») |
| QEMU / KVM | 10.2.1 (`kvm-ok`: aceleración utilizable) |
| libvirt / `virsh` | 12.0.0 |
| OVMF (UEFI) | 2025.11 |
| swtpm (TPM 2.0 emulado) | 0.10.1 — **dentro de Windows: `TpmPresent=True`, `SpecVersion 2.0`** |
| virtio-win | 0.1.302 |
| Windows IoT Enterprise LTSC 2024 | build **26100** |
| Rig Manager | **4.3.13.1** |
| Kemper Profiler | OS **14.1.2.66277**, serie `APEaRiLBATF`, **591 rigs** en el aparato |
| Usuario de la VM | `kemper`, con inicio de sesión automático (la contraseña la eliges tú) |

Evidencias archivadas en `evidencia/`:

| Fichero | Qué demuestra |
|---|---|
| `F0-recon.txt` | Estado inicial de la máquina (USB, disco, virtualización) |
| `F0-veredicto-arbitro.md` + transcript | Auditoría adversarial de la fase 0 y sus 15 hallazgos |
| `F1-plataforma.txt` | Paquetes, versiones, KVM, OVMF, red NAT, ACL |
| `F5-rigmanager-conectado.md` / `.png` | **Rig Manager conectado al Kemper**, con captura |
| `F6-icono-render.png` | El icono del lanzador, renderizado de verdad |
| `instalacion/*.png` | Capturas de todo el proceso (arranque, setup, escritorio, Rig Manager) |
| `F6-reversibilidad.txt` | Al apagar la VM, el Kemper pasa de `usbfs` a `snd-usb-audio`: vuelve a Linux |
| `F8-prueba-desde-cero.md` | **Prueba de fuego**: despliegue completo desde cero, sin intervención humana |
| `instalacion/usuario-*.png` | Rig Manager del usuario ya conectado al Kemper (591 rigs, cadena de señal, valores reales) |

## Fuentes y verificaciones externas

- Hash oficial de la ISO LTSC 2024 (`f6b14814`), reproducido de forma independiente en:
  <https://github.com/davidscarth/windows-ltsc-hardening-guide/blob/main/RUNBOOK.md>,
  <https://github.com/ventoy/Ventoy/issues/3150>,
  <https://archive.org/details/windows-11-iot-enterprise-ltsc-2024>
- Drivers virtio-win (Fedora, estable): <https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/>
- Kemper: FAQ de plataformas y funciones, y página de Rig Manager:
  <https://www.kemper-amps.com/faqs> · <https://www.kemper-amps.com/rig-manager>
- Por qué Wine no sirve para esto (veredictos del foro del fabricante):
  <https://forum.kemper-amps.com/forum/thread/63838-rig-manager-on-linux/>