# Kemper Rig Manager on Linux (inside a virtual machine)

> [Leer esto en español](README.es.md)

> ### ⚠️ Notice: this project was written with the help of artificial intelligence
>
> It **has been tested on real machines** (a full install on a clean Ubuntu and
> another one by hand on a Debian with GNOME Boxes), but an AI also gets things
> wrong: **read it before running it**, especially phase 1, the only one that asks
> for administrator permissions. No warranty (MIT licence). Details are in "How
> this was made", below.

**What this is:** a set of scripts that build, on your own Linux, a virtual
machine with Windows 11 IoT Enterprise LTSC and Kemper's **Rig Manager** running
at full capacity: Profiler control, library management, Rig Exchange and the
**Kemper operating system update**.

**Why a virtual machine:** the official Rig Manager only exists for Windows and
macOS. On Linux there are homemade MIDI USB alternatives, but they don't cover
everything (updating the device's operating system, for example). Here the
official program is used, as-is, with **the Kemper passed through over USB to the
virtual machine**.

**How it's used:** a launcher in the applications menu. When you open it, it
starts Windows, connects the Kemper and opens the window with Rig Manager. When
you close it, Windows shuts down and **the Kemper goes back to Linux on its
own**, where your DAW sees it again as always.

---

## Important notice (read it, it's 20 seconds)

This repository **does not include or distribute**:

- The Windows 11 IoT Enterprise LTSC 2024 ISO → it's Microsoft's.
- The Rig Manager installer (`Rig_Manager_*.msi`) → it's Kemper's.

**You provide them yourself**, obtained through whatever channels apply to you.
What's here are only the scripts that automate the installation on **your**
machine with **your** media.

This project is **not affiliated** with either Kemper GmbH or Microsoft.
"Kemper", "Profiler" and "Rig Manager" are trademarks of Kemper GmbH; "Windows"
is a trademark of Microsoft Corporation.

**The project icon is our own** (see `icono/`); Kemper's official icon is not
distributed here.

---

## Can your PC handle this?

| | |
|---|---|
| Processor | x86_64 with virtualization (Intel VT-x or AMD-V) |
| System | Linux with **apt** (Debian, Ubuntu, Linux Mint, Pop!_OS…) |
| Memory | **8 GB or more** (Windows is given 6 GB by default) |
| Disk | **30 GB free** as a minimum |
| Privileges | Being able to use `sudo` once (only in the first step) |
| Desktop | Graphical session (the launcher opens a window) |

Check yours without changing anything:

```bash
./install.sh --comprobar
```

## What you need to download yourself

1. **Windows 11 IoT Enterprise LTSC 2024 ISO**, in English (`en-us`).
   It's the "IoT Enterprise LTSC" version, not the regular one. It's the
   recommended one: no store, no promotional programs, no mandatory feature
   updates, and support until 2034.
2. **Rig Manager for Windows** (the `.msi` from Kemper's website).
3. *(Optional)* The **virtio-win** ISO from Fedora. If you don't have it,
   `install.sh` downloads and verifies it for you.

**Which ISO to use:** the recommended and tested one is **Windows 11 IoT
Enterprise LTSC 2024** in English. Regular Windows 11 (Pro/Home) or Windows 10
also work, by changing the edition name (the installer explains how) — but they
aren't as well tested as the LTSC. The unattended installer's regional settings
are set for English.

## Installation (one time only)

```bash
git clone https://github.com/granmajestuoso86-sketch/kemper-rigmanager-linux.git
cd kemper-rigmanager-linux
./install.sh
```

`install.sh` asks you three things (the paths of the files above) and then does
the rest in phases. **It goes step by step and you can stop and resume where you
left off** — this matters: the Windows installation takes a while, and if
something gets stuck you don't have to start over.

```bash
./install.sh --estado      # how far along you are
./install.sh --continuar   # resume from where it left off
./install.sh --fase 5      # repeat/run a specific phase
```

**The installer speaks two languages.** The messages can be shown in Spanish or
English with `KEMPER_LANG=es ./install.sh` (or `KEMPER_LANG=en`), or by setting
`IDIOMA=es`/`IDIOMA=en` in `config/kemper-vm.conf`. By default it uses your
system's language.

**The first step** (phase 1) is the only one that asks for the administrator
password: it installs the virtualization packages. Afterwards, when it finishes,
**log out and log back in** (it's needed for your user to join the `libvirt`
group). Then continue with `./install.sh --continuar`.

**Windows disk size:** the minimum is **64 GB** (Windows 11 won't install with
less); **80 GB is recommended**, for headroom for updates and your rigs. It's a
disk that grows as it's used: 80 GB doesn't occupy 80 GB on your disk.

## Daily use

Applications menu → **Rig Manager (Kemper)**.

1. Windows opens and waits until it's ready (the first time, up to a minute).
2. **It connects the Kemper automatically**. The order doesn't matter: if you
   turn it on later, a watcher hooks it within a few seconds.
3. Rig Manager starts on its own, with your device inside.
4. **When done, close the window (the X) and that's it**: Windows shuts down by
   itself and the Kemper goes back to Linux.

> **The one thing to understand about all this:** while the window is open, **the
> Kemper belongs to Windows**. Your Linux DAW won't see it. It's not a fault: a
> USB device has a single owner at a time. When you close the window it goes back
> to being Linux's.

If you need to leave Windows on (for example, a long Kemper operating system
update), don't close the window: minimize it. Or use:

```bash
kemper-rig-manager --dejar-abierto
```

Other useful commands:

```bash
kemper-rig-manager --estado    # what's happening right now
kemper-rig-manager --apagar    # shut down Windows and release the Kemper
```

## Documentation

- **[manual/USER-GUIDE.en.md](manual/USER-GUIDE.en.md)** — the user guide, for
  someone who doesn't know Linux (English).
- **[manual/GUIA-USUARIO.es.md](manual/GUIA-USUARIO.es.md)** — the same user
  guide, in Spanish.
- **[manual/MANUAL-RIG-MANAGER-VM.md](manual/MANUAL-RIG-MANAGER-VM.md)** — the
  technical manual (52 KB). It explains **why** it's set up this way, the
  decisions made, the pitfalls found and the checks that were run. It's a design
  log, not decoration: it's the part that saves the most time. **It's only in
  Spanish**, because it was written as the working log while the project was
  being built and translating it would make it drift from the code and the actual
  experience.

## If something goes wrong

Everything is written up, with the symptom as you see it and its fix, in the
user guide and the manual:

```
manual/USER-GUIDE.en.md           →  §7 "Typical errors and how to get out of them"
manual/GUIA-USUARIO.es.md         →  §7 "Errores típicos y cómo salir de ellos"
manual/MANUAL-RIG-MANAGER-VM.md   →  §10 "Solución de problemas y trampas"
```

## Repository structure

```
install.sh                     The installer. Start here.
config/kemper-vm.conf.example  Configuration template (your paths, RAM, disk)
config/vm-domain.xml.in        Virtual machine template
lib/config.sh  lib/config.py   Configuration reading (bash and python)
scripts/                       The phases, numbered in execution order
  ├── 00-setup-root.sh         Packages and groups (the only one with sudo)
  ├── 10-build-install-iso.sh  Builds the unattended installation media
  ├── 20-crear-vm.sh           VM disk and definition
  ├── 30-instalar-windows.sh   Installs Windows without intervention
  ├── 40/45-*.sh               Connects the Kemper (and watches it)
  ├── 50-expulsar-isos.sh      Ejects the DVDs so it boots from disk
  ├── 70-instalar-lanzador.sh  Icon and menu entry
  ├── kemper-rig-manager       The launcher
  └── 90-*.py, 95-*.py         Tools (verify, write, clicks, files)
install/payload/               Scripts that run INSIDE Windows
manual/                        Full deployment and usage manual
```

## How this was made (and why you should read it before trusting it)

An **artificial intelligence** wrote this repository, steered and corrected by a
person. Plainly, so you can decide for yourself:

- **It has been run, not just written.** All seven phases, in full, on a clean
  Ubuntu 24.04, and then again by hand on a Debian inside GNOME Boxes: Windows
  installed and Rig Manager open. The failures that showed up are fixed and
  written down in the technical manual, with the reason.
- **An AI writes code that looks right and sometimes isn't.** Several bugs here
  only appeared when running it on a different machine from the one it was written
  on: a message starting with dashes, a missing program, a download nobody used.
  That's why there is a test on a second system, and why the installer can be
  re-run phase by phase without breaking anything.
- **Read it before running it.** That goes for any script you download, AI-written
  or not. Phase 1 is the only one that uses `sudo`, and it only installs packages
  from your distribution.
- **No warranty.** The MIT licence says so: it comes as is. If something breaks on
  your machine, that's on you. The manual has a list of common failures and how to
  get out of them.
- **If you find something that doesn't match this documentation, open an issue.**
  A correction from someone who tested it on their own machine is worth more than
  any promise written here.

## What it does NOT do (and it's honest to say so)

- **Doesn't** save you from needing a Windows license: without a key, Windows
  stays unactivated (with a watermark) and works just the same.
- **Doesn't** include the installation media (see the notice above).
- **Isn't** tested outside Debian/Ubuntu. On Fedora/Arch you'd have to adapt the
  phase 1 package names.
- The virtual machine reserves **6 GB of RAM**: don't leave it open while you use
  a huge project in your DAW.

## License

MIT (see `LICENSE`), with the trademark and media notice included there.