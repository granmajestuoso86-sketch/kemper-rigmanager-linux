# Kemper Rig Manager on Linux — User Guide

> [Leer esto en español](GUIA-USUARIO.es.md)

> **Who this is for:** you, who own a Kemper Profiler and a computer running
> Linux, and want to use Kemper's official program (**Rig Manager**) without
> installing Windows on your disk.
>
> **What you'll get:** an icon in your Linux applications menu. You click it, a
> real Windows opens (in a window) with Rig Manager inside, your Kemper shows up
> connected, and when you close the window everything goes back to normal and
> your Linux sees the Kemper again as always.
>
> **How long it takes:** one afternoon the first time (most of it spent waiting
> for Windows to install itself). After that, seconds.
>
> **Notice:** this project was written by an AI under human supervision. It has
> been tested on real machines, but if you are about to run something with
> administrator permissions, have a look at it first. Always be wary of what you
> don't understand, whether it comes from an AI or anywhere else.
>
> **How much Linux you need to know:** none. You have to copy and paste a command
> once, and answer a few questions.

---

## 1. What this is (and what it isn't)

**It is** a virtual machine: a computer inside your computer. Inside it lives
Windows 11, and inside Windows lives Rig Manager, just like on a colleague's PC.
The Kemper connects to that window as if it were a Windows USB device.

**It is not** a Linux program that imitates Rig Manager. It's the real,
official Rig Manager, with everything it has: your library, **Rig Exchange** and
—this is the important part— the **Kemper operating system update**, which is
exactly what homemade alternatives don't do.

**Why this way:** Rig Manager doesn't exist for Linux. There are homemade
programs that work over MIDI, but they don't cover everything (updating the
Kemper, for example). This is the way to have it complete and without touching
your Linux.

---

## 2. Before you start

### Your computer needs to be able to

| | |
|---|---|
| Processor | Intel or AMD, with virtualization enabled (it comes enabled from the factory on almost all) |
| Linux | Debian- or Ubuntu-based (Ubuntu, Linux Mint, Pop!_OS, KDE neon…) |
| Memory | **8 GB or more** (Windows is given 6) |
| Disk | **30 GB free** as a minimum |
| Desktop | A normal graphical session (this opens windows) |

If you're not sure, there's a command that checks it **without changing anything**:

```bash
./install.sh --comprobar
```

### Two files you have to get yourself

They don't come with the project (they aren't the author's; they're Microsoft's
and Kemper's):

1. **The Windows 11 IoT Enterprise LTSC 2024 ISO, in English (`en-us`)**. It's the
   recommended one: no store, no promotional programs, no mandatory feature
   updates, and support until 2034. It's about 5 GB.
2. **The Rig Manager for Windows installer** (the `.msi` file downloaded from
   Kemper's website). About 300 MB.

These also work: regular Windows 11 (Pro or Home) or Windows 10, changing the
edition name (the installer explains how). What's **not** been tested is Windows
10 or the versions in other languages.

> **Optional:** the ISO of the *virtio drivers* (from Fedora). If you don't have
> it, the installer downloads it for you and checks that it isn't corrupted.

---

## 3. Installation (one time only)

```bash
cd folder-where-you-copied-it
./install.sh
```

And answer. It will ask you:

| Question | What to answer |
|---|---|
| Path to the Windows ISO | The full path of file 1 |
| Path to the Rig Manager installer | The full path of file 2 |
| Path to the virtio-win ISO | Yours, or Enter so it downloads it |
| Name of the virtual machine | Enter (whatever it suggests works) |
| Memory for Windows, in MB | Enter if you have 8 GB or more |
| CPU cores | Enter |
| **Windows disk size** | **80** (the minimum is 64: Windows 11 won't install with less) |
| Windows user and password | Whatever you want. They're stored only on your computer |
| Windows edition | Enter, unless your ISO is a different one |

Then it starts and **does seven phases on its own**. Two important things:

1. **The first phase asks for your administrator password** (it's the only time:
   it installs the virtualization programs). It's normal and expected.
2. **When that phase finishes, the installer will tell you to log out and log
   back in.** Do it. It's a Linux requirement (your user joins a new group) and
   without that it can't go on. When you log back in:

```bash
./install.sh --continuar
```

And that's it: from there it leaves you alone. **The Windows installation takes
a while** (between twenty minutes and an hour, depending on the computer): you
can go do something else. If something gets interrupted, it's fixed and resumed
from where it was; you never have to start over from scratch.

### What about the Windows screen?

During the installation it asks you one more thing: **the size of the Windows
screen**. You can leave it at `auto` (Windows picks, and you can change it inside
Windows like on any PC) or ask for a specific size by typing it as is:

```
Windows screen ('auto' or a size, e.g. 1920x1200): 1920x1200
```

Pick a size that fits your monitor (if you ask for more than your screen, the
mouse pointer can wander off it). If you have a big screen and Rig Manager looks
tiny, this is the option. You can change it later by editing `RESOLUCION_VM` in
`config/kemper-vm.conf` and re-running phase 3 of the installer.

### How to know how far along it is

```bash
./install.sh --estado      # which phases are done and which is next
./install.sh --continuar   # resume from where it left off
./install.sh --fase 5      # repeat a specific phase (in case something failed)
```

---

## 4. Day-to-day use

**Applications menu → "Rig Manager (Kemper)".**

1. The window opens and, the first time, takes up to a minute (Windows is
   starting up). Don't be alarmed if you see a black screen for a while.
2. The Kemper connects **by itself**. The order doesn't matter: if you turn it on
   later, a watcher connects it within a few seconds.
3. Rig Manager starts on its own, with your device inside.
4. **When you're done: close the window (the X) and that's it.** Windows shuts
   down by itself, the Kemper goes back to Linux, and your music program sees it
   again.

> ### The one thing to understand about all this
>
> While the window is open, **the Kemper belongs to Windows**. Your Linux music
> program **won't see it** and it will look like it's broken. It isn't broken: a
> USB device can only be in one place at a time. Close the window and it's back.

### The first time you open it: let it reboot

The first time Rig Manager opens, Windows may tell you a restart is needed. That's
because it has just installed the drivers and the agent this installer puts in,
and some of them don't work properly until you restart.

**Do it**: restart Windows (Windows menu → Restart), wait for it to come back and
open Rig Manager again. From then on it opens fine every time.

If it doesn't ask you, carry on: not every machine asks.

### Useful commands from a terminal

```bash
kemper-rig-manager --estado             # what's happening right now
kemper-rig-manager --apagar             # shut down Windows and release the Kemper
kemper-rig-manager --dejar-abierto      # when closing the window, don't shut Windows down
```

### If you need to leave Windows on

For example, so that a long Kemper update can finish: **don't close the window,
minimize it**. Or open it with `kemper-rig-manager --dejar-abierto`.

---

## 5. Moving files between Linux and Windows

Rigs, presets, backups… with:

```bash
scripts/95-intercambio.py enviar   ~/Descargas/mi_rig.rig
scripts/95-intercambio.py recibir  C:\\Users\\kemper\\Desktop\\backup.rig
```

They appear in the `C:\INTERCAMBIO` folder inside Windows.

---

## 6. Things worth knowing

- **Don't use Rig Manager and your Linux editor at the same time**: only one can
  have the Kemper.
- **The virtual machine reserves 6 GB of memory.** Don't leave it open while
  you're working on a huge project in your music program.
- **Don't close the window forcibly** while Rig Manager is writing to the Kemper
  (a backup or an operating system update): give it a few seconds.
- **Windows will show as "not activated"** (a watermark on the desktop) if you
  don't give it a license. **It works just the same** for everything you need.
- **The keyboard comes up in English** inside Windows (the ISO is in English).
  You can add Spanish in *Settings → Time & language*.

---

## 7. Typical errors and how to get out of them

> This is the section to read when something goes wrong. Find your symptom.

### The first time, Rig Manager doesn't quite start and asks me to restart

That's expected, not a failure: Windows has just installed the virtio drivers and
its agent, and some of them don't work until you restart. Restart Windows from the
window itself, wait for it to boot and open Rig Manager again. Nothing needs
reinstalling.

### "Rig Manager (Kemper)" doesn't appear in the menu

Your session is from before the installation. **Log out and log back in.** If it
still doesn't appear, run `scripts/70-instalar-lanzador.sh`.

### "I can't talk to libvirt"

It's the same thing: your session doesn't have the `libvirt` group yet. **Log
out, log back in** and try again. (If you just did phase 1, this is exactly what
the installer is asking you to do.)

### The installer says the Kemper isn't plugged in, and it is

Check whether it's **turned on**: a Kemper that's off doesn't exist for the
computer (it doesn't show up in `lsusb`, nor as a sound card). Turn it on: the
watcher connects it by itself.

### Rig Manager stays on "Scanning for profilers…"

The Kemper is on but **hasn't reached Windows**. Check and fix it like this:

```bash
kemper-rig-manager --estado        # it should say: Kemper en la VM: sí
scripts/40-conectar-kemper.sh      # if it says no, connect it by hand
```

### My Linux music program no longer sees the Kemper

It's inside the virtual machine. Close the window (Windows shuts down by itself) or:

```bash
kemper-rig-manager --apagar
```

### The Kemper doesn't go back to Linux after shutting down

Some devices don't present themselves again on their own: **unplug the USB cable
and plug it back in**. It comes back within a few seconds.

### When closing the window it asks me "Do you want to close the session?"

That **isn't from the launcher**, it's a question from the program that shows the
window itself. Tell it **OK**: afterwards Windows shuts down on its own. If it
bothers you, remove it with:

```bash
sed -i 's/^ask-quit=.*/ask-quit=false/' ~/.config/virt-viewer/settings
```

### Windows boots from the DVD over and over, or keeps repeating the installation

The virtual discs were left in place. They're removed with
`scripts/50-expulsar-isos.sh`.

### "Permission denied" when starting the virtual machine

The permissions on the project's files have gotten messed up (for example, when
restoring a backup). They're repaired with:

```bash
sudo bash scripts/fix-perms.sh
```

### The installer stopped at a phase and I don't know what to do

You don't have to start over: see where it is and continue.

```bash
./install.sh --estado
./install.sh --continuar
```

If a specific phase always fails, repeat it on its own (`./install.sh --fase 4`)
and read the message: the errors explain what's missing and how to get it. The
full log is in `logs/install.log`.

### Everything else that fails

1. `logs/install.log` and `logs/lanzador.log` — everything that happened is in there.
2. `manual/MANUAL-RIG-MANAGER-VM.md` — the technical manual: it explains **why**
   it's set up this way and collects the pitfalls found, with their solution.
   *(Spanish only.)*
3. If you're going to ask on a forum or open a GitHub issue, **paste the exact
   message** and what `./install.sh --estado` returns. With that, almost
   everything is solved on the first try.

---

## 8. If someday you want to uninstall it

Everything it installed is in two places: the virtual machine and the launcher
in the menu.

```bash
# 1) The virtual machine (and with it, Windows and everything inside)
virsh -c qemu:///system destroy kemper-win11    # shut it down if it's running
virsh -c qemu:///system undefine kemper-win11 --nvram
virsh -c qemu:///system vol-delete --pool kemper kemper-win11.qcow2  # the disk

# 2) The launcher and the icon (yours only, no administrator permissions)
rm -f ~/.local/bin/kemper-rig-manager
rm -f ~/.local/share/applications/kemper-rig-manager.desktop
rm -f ~/.local/share/icons/hicolor/*/apps/kemper-rig-manager.*

# 3) The project folder (optional; it holds your media if you copied any there)
rm -rf folder-where-i-copied-it
```

None of this touches your Linux, your Kemper or your music program.