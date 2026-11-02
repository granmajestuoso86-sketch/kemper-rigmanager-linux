# Rig Manager de Kemper en Linux — Guía de uso

> [Read this in English](USER-GUIDE.en.md)

> **Para quién es esto:** para ti, que tienes un Kemper Profiler y un ordenador con
> Linux, y quieres usar el programa oficial de Kemper (**Rig Manager**) sin instalar
> Windows en tu disco.
>
> **Qué vas a conseguir:** un icono en el menú de aplicaciones de tu Linux. Lo pulsas,
> se abre un Windows de verdad (en una ventana) con Rig Manager dentro, tu Kemper
> aparece conectado, y cuando cierras la ventana todo vuelve a la normalidad y tu
> Linux vuelve a ver el Kemper como siempre.
>
> **Cuánto tiempo lleva:** una tarde la primera vez (la mayor parte, esperando a que
> Windows se instale solo). Después, segundos.
>
> **Aviso:** este proyecto lo ha escrito una IA con la supervisión de una persona.
> Está probado en máquinas reales, pero si vas a ejecutar algo con permisos de
> administrador, échale un ojo antes. Desconfía siempre de lo que no entiendas,
> venga de una IA o de cualquier otra parte.
>
> **Cuánto hay que saber de Linux:** nada. Hay que copiar y pegar un comando una vez,
> y contestar unas preguntas.

---

## 1. Qué es esto (y qué no)

**Es** una máquina virtual: un ordenador dentro de tu ordenador. Dentro vive Windows
11, y dentro de Windows vive Rig Manager, igual que en el PC de un compañero. El
Kemper se conecta a esa ventana como si fuera un USB de Windows.

**No es** un programa de Linux que imite a Rig Manager. Es el Rig Manager de verdad,
el oficial, con todo lo que tiene: tu biblioteca, el **Rig Exchange** y —esto es lo
importante— la **actualización del sistema operativo del Kemper**, que es justo lo
que las alternativas caseras no hacen.

**Por qué así:** el Rig Manager no existe para Linux. Hay programas caseros que
funcionan por MIDI, pero no cubren todo (actualizar el Kemper, por ejemplo). Esta es
la forma de tenerlo completo y sin tocar tu Linux.

---

## 2. Antes de empezar

### Tu ordenador tiene que poder

| | |
|---|---|
| Procesador | Intel o AMD, con la virtualización activada (viene activada de fábrica en casi todos) |
| Linux | Basado en Debian o Ubuntu (Ubuntu, Linux Mint, Pop!_OS, KDE neon…) |
| Memoria | **8 GB o más** (a Windows se le dan 6) |
| Disco | **30 GB libres** como mínimo |
| Escritorio | Una sesión gráfica normal (esto abre ventanas) |

Si no estás seguro, hay un comando que lo comprueba **sin cambiar nada**:

```bash
./install.sh --comprobar
```

### Dos ficheros que tienes que conseguir tú

No vienen con el proyecto (no son de quien lo escribió, son de Microsoft y de Kemper):

1. **La ISO de Windows 11 IoT Enterprise LTSC 2024, en inglés (`en-us`)**. Es la
   recomendada: sin tienda, sin programas promocionales, sin actualizaciones de
   funciones obligatorias, y con soporte hasta 2034. Ocupa unos 5 GB.
2. **El instalador de Rig Manager para Windows** (el archivo `.msi` que se descarga
   de la web de Kemper). Unos 300 MB.

También sirve: Windows 11 normal (Pro o Home) o Windows 10, cambiando el nombre de la
edición (el instalador te explica cómo). Lo que **no** está probado es Windows 10 ni
las versiones en otros idiomas.

> **Opcional:** el ISO de los *drivers de virtio* (de Fedora). Si no lo tienes, el
> instalador se lo descarga solo y comprueba que no esté corrupto.

---

## 3. Instalación (una sola vez)

```bash
cd carpeta-donde-lo-hayas-copiado
./install.sh
```

Y contesta. Te va a preguntar:

| Pregunta | Qué contestar |
|---|---|
| Ruta de la ISO de Windows | La ruta completa del fichero 1 |
| Ruta del instalador de Rig Manager | La ruta completa del fichero 2 |
| Ruta del ISO de virtio-win | La tuya, o Enter para que se descargue |
| Nombre de la máquina virtual | Enter (vale el que propone) |
| Memoria para Windows, en MB | Enter si tienes 8 GB o más |
| Núcleos de CPU | Enter |
| **Tamaño del disco de Windows** | **80** (el mínimo son 64: Windows 11 no se instala con menos) |
| Usuario y contraseña de Windows | Los que quieras. Se guardan sólo en tu ordenador |
| Edición de Windows | Enter, salvo que tu ISO sea otra |

Después empieza y **hace siete fases solo**. Dos cosas importantes:

1. **La primera fase te pide tu contraseña de administrador** (es la única vez: instala
   los programas de virtualización). Es normal y esperado.
2. **Cuando esa fase acabe, el instalador te dirá que cierres sesión y vuelvas a
   entrar.** Hazlo. Es un requisito de Linux (tu usuario entra en un grupo nuevo) y
   sin eso no puede seguir. Al volver a entrar:

```bash
./install.sh --continuar
```

Y ya está: a partir de ahí te deja solo. **La instalación de Windows tarda** (entre
veinte minutos y una hora, según el ordenador): puedes irte a hacer otra cosa. Si
algo se corta, se arregla y se sigue desde donde estaba, nunca hay que empezar de cero.

### ¿Y la pantalla de Windows?

Durante la instalación te pregunta una cosa más: **el tamaño de la pantalla de
Windows**. Puedes dejarlo en `auto` (Windows elige, y luego lo cambias dentro de
Windows como en cualquier PC) o pedir un tamaño concreto escribiéndolo tal cual:

```
Pantalla de Windows ('auto' o un tamaño, p. ej. 1920x1200): 1920x1200
```

Elige un tamaño que quepa en tu monitor (si pides más que tu pantalla, el ratón
se te puede ir fuera). Si tu equipo tiene pantalla grande y Rig Manager se ve
pequeño, esta es la opción. Se puede cambiar después editando `RESOLUCION_VM` en
`config/kemper-vm.conf` y repitiendo la fase 3 del instalador.

### Cómo saber por dónde va

```bash
./install.sh --estado      # qué fases están hechas y cuál toca
./install.sh --continuar   # seguir desde donde se quedó
./install.sh --fase 5      # repetir una fase concreta (por si algo falló)
```

---

## 4. Uso del día a día

**Menú de aplicaciones → «Rig Manager (Kemper)».**

1. Se abre la ventana y, la primera vez, tarda hasta un minuto (Windows está
   arrancando). No te alarmes si ves la pantalla negra un rato.
2. El Kemper se conecta **solo**. Da igual el orden: si lo enciendes más tarde, un
   vigilante lo conecta en unos segundos.
3. Rig Manager arranca solo, con tu aparato dentro.
4. **Cuando termines: cierra la ventana (la X) y ya está.** Windows se apaga solo, el
   Kemper vuelve a Linux, y tu programa de música lo vuelve a ver.

> ### Lo único que hay que entender de todo esto
>
> Mientras la ventana esté abierta, **el Kemper pertenece a Windows**. Tu programa de
> música de Linux **no lo verá** y parecerá que se ha roto. No se ha roto: un aparato
> USB sólo puede estar en un sitio a la vez. Cierra la ventana y vuelve.

### La primera vez que lo abres: deja que reinicie

La primera vez que abre Rig Manager, Windows puede decirte que hace falta
reiniciar. Es porque acaba de instalar los drivers y el agente que le mete este
instalador, y algunos no terminan de funcionar hasta reiniciar.

**Hazlo**: reinicia Windows (menú de Windows → Reiniciar), espera a que vuelva a
arrancar y abre Rig Manager otra vez. A partir de ahí abre siempre bien.

Si no te lo pide, adelante: no todos los equipos lo piden.

### Comandos útiles desde una terminal

```bash
kemper-rig-manager --estado             # qué está pasando ahora mismo
kemper-rig-manager --apagar             # apagar Windows y liberar el Kemper
kemper-rig-manager --dejar-abierto      # al cerrar la ventana, no apagar Windows
```

### Si necesitas dejar Windows encendido

Por ejemplo, para que termine una actualización larga del Kemper: **no cierres la
ventana, minimízala**. O ábrela con `kemper-rig-manager --dejar-abierto`.

---

## 5. Pasar archivos entre Linux y Windows

Rigs, presets, backups… con:

```bash
scripts/95-intercambio.py enviar   ~/Descargas/mi_rig.rig
scripts/95-intercambio.py recibir  C:\\Users\\kemper\\Desktop\\backup.rig
```

Aparecen en la carpeta `C:\INTERCAMBIO` dentro de Windows.

---

## 6. Cosas que conviene saber

- **No uses Rig Manager y tu editor de Linux a la vez**: sólo uno puede tener el Kemper.
- **La máquina virtual reserva 6 GB de memoria.** No la dejes abierta mientras trabajas
  con un proyecto enorme en tu programa de música.
- **No cierres la ventana a lo bruto** mientras Rig Manager esté escribiendo en el
  Kemper (un backup o una actualización del sistema operativo): dale unos segundos.
- **Windows aparecerá como «no activado»** (una marca de agua en el escritorio) si no
  le pones una licencia. **Funciona igual** para todo lo que necesitas.
- **El teclado sale en inglés** dentro de Windows (la ISO es en inglés). Se puede añadir
  el español en *Settings → Time & language*.

---

## 7. Errores típicos y cómo salir de ellos

> Esta es la sección que hay que leer cuando algo va mal. Busca tu síntoma.

### La primera vez, Rig Manager no acaba de arrancar y me pide reiniciar

Está previsto, no es un fallo: Windows acaba de instalar los drivers de virtio y
su agente, y algunos no funcionan hasta reiniciar. Reinicia Windows desde la
propia ventana, espera a que arranque y abre Rig Manager otra vez. No hay que
reinstalar nada.

### No aparece «Rig Manager (Kemper)» en el menú

Tu sesión es anterior a la instalación. **Cierra sesión y entra de nuevo.** Si sigue
sin aparecer, ejecuta `scripts/70-instalar-lanzador.sh`.

### «No puedo hablar con libvirt»

Es lo mismo: tu sesión no tiene todavía el grupo `libvirt`. **Cierra sesión, entra de
nuevo** y repite. (Si acabas de hacer la fase 1, es exactamente lo que el instalador te
está pidiendo.)

### El instalador dice que el Kemper no está enchufado, y sí lo está

Mira si está **encendido**: un Kemper apagado no existe para el ordenador (ni aparece
en `lsusb`, ni como tarjeta de sonido). Enciéndelo: el vigilante lo conecta solo.

### Windows se ve a 1024x768 (o muy pequeño) y no puedo cambiar la resolución

Pasa en máquinas creadas antes de una corrección del proyecto: la pantalla de la
máquina virtual se quedó en el modelo básico, que **no admite cambios de
resolución**. Se arregla en un minuto, con la máquina apagada:

```bash
kemper-rig-manager --apagar          # apaga Windows y devuelve el Kemper a Linux
virt-xml kemper-win11 --edit --video model.type=qxl,ram=65536,heads=1
```

Al volver a abrir el lanzador, Windows detectará una pantalla nueva e instalará su
driver (ya viene dentro). A partir de ahí, el tamaño pedido en `RESOLUCION_VM` sí se
aplica.

### Rig Manager se queda en «Scanning for profilers…»

El Kemper está encendido pero **no ha llegado a Windows**. Comprueba y arréglalo así:

```bash
kemper-rig-manager --estado        # debe decir: Kemper en la VM: sí
scripts/40-conectar-kemper.sh      # si dice que no, conéctalo a mano
```

### Mi programa de música de Linux ya no ve el Kemper

Está dentro de la máquina virtual. Cierra la ventana (se apaga Windows solo) o:

```bash
kemper-rig-manager --apagar
```

### El Kemper no vuelve a Linux después de apagar

Algunos aparatos no se vuelven a presentar solos: **desenchufa el cable USB y
vuélvelo a enchufar**. Vuelve en unos segundos.

### Al cerrar la ventana me pregunta «Do you want to close the session?»

Eso **no es del lanzador**, es una pregunta propia del programa que muestra la ventana.
Dile **OK**: luego se apaga Windows solo. Si te molesta, quítala con:

```bash
sed -i 's/^ask-quit=.*/ask-quit=false/' ~/.config/virt-viewer/settings
```

### Windows arranca del DVD una y otra vez, o se queda repitiendo la instalación

Se quedaron los discos virtuales puestos. Se quitan con `scripts/50-expulsar-isos.sh`.

### «Permission denied» al arrancar la máquina virtual

Los permisos de los ficheros del proyecto se han estropeado (por ejemplo, al restaurar
una copia). Se reparan con:

```bash
sudo bash scripts/fix-perms.sh
```

### El instalador se paró en una fase y no sé qué hacer

No hay que empezar de cero: mira dónde está y sigue.

```bash
./install.sh --estado
./install.sh --continuar
```

Si una fase concreta falla siempre, repítela sola (`./install.sh --fase 4`) y lee el
mensaje: los errores explican qué falta y cómo conseguirlo. El registro completo está
en `logs/install.log`.

### Todo lo demás que falle

1. `logs/install.log` y `logs/lanzador.log` — ahí está todo lo que ha pasado.
2. `manual/MANUAL-RIG-MANAGER-VM.md` — el manual técnico: explica **por qué** está
   montado así y recoge las trampas encontradas, con su solución.
3. Si vas a preguntar en un foro o abrir un aviso en GitHub, **pega el mensaje exacto**
   y lo que devuelve `./install.sh --estado`. Con eso se resuelve casi todo a la primera.

---

## 8. Si algún día quieres desinstalarlo

Todo lo que instaló está en dos sitios: la máquina virtual y el lanzador del menú.

```bash
# 1) La máquina virtual (y con ella, Windows y todo lo de dentro)
virsh -c qemu:///system destroy kemper-win11    # apagarla si está encendida
virsh -c qemu:///system undefine kemper-win11 --nvram
virsh -c qemu:///system vol-delete --pool kemper kemper-win11.qcow2  # el disco

# 2) El lanzador y el icono (sólo tuyos, sin permisos de administrador)
rm -f ~/.local/bin/kemper-rig-manager
rm -f ~/.local/share/applications/kemper-rig-manager.desktop
rm -f ~/.local/share/icons/hicolor/*/apps/kemper-rig-manager.*

# 3) La carpeta del proyecto (opcional; contiene tus medios si los copiaste ahí)
rm -rf carpeta-donde-lo-copié
```

Nada de esto toca tu Linux, tu Kemper ni tu programa de música.
