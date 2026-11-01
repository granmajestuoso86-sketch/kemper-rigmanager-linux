<#
  instalar.ps1 — instalación dentro del invitado, en el primer inicio de sesión.

  Hace, en este orden:
    1. Copia los instaladores del medio a C:\INSTALADORES (para poder repetir
       la instalación sin el ISO).
    2. Drivers virtio (paquete "gt": incluye vioserial, que necesita el agente
       de invitado, y viogpu).
    3. Agente de invitado de QEMU (permite verificar desde el anfitrión).
    4. Rig Manager (MSI oficial de Kemper).
    5. Acceso directo en el escritorio y autoarranque al iniciar sesión.

  Todo queda registrado en C:\kemper-install.log y C:\log-*.log
#>
param(
  [Parameter(Mandatory = $true)][string]$Media
)

$ErrorActionPreference = 'Continue'
$log  = 'C:\kemper-install.log'
$dst  = 'C:\INSTALADORES\payload'
# El nombre del MSI llevaba la VERSION dentro (4_3_13): con otra version, un
# companero habria fallado. Ahora se busca por patron (vale cualquier version),
# pero OJO: la busqueda va en la seccion 4, cuando la carpeta ya tiene los
# ficheros copiados. Buscarla aqui arriba -antes de la copia- no encuentra nada
# porque $dst todavia no existe: se quedaba con un nombre inventado, avisaba de
# "falta el MSI de Rig Manager" y el programa no se instalaba. Fallo real,
# detectado en la prueba de fuego en un sistema limpio.

# Normaliza la unidad recibida: vale "D:" o "D:\" y siempre acaba en UNA barra.
# El llamador la pasa a proposito sin barra: una barra final antes de la comilla
# de cierre se interpreta como comilla escapada en la linea de ordenes de Windows
# y aqui llegaria una ruta rota (fallo real: "D:\" + comilla + "payload").
$Media = $Media.TrimEnd('\') + '\'

function Log([string]$m) {
  $line = "{0}  {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $m
  Write-Host $line
  Add-Content -Path $log -Value $line
}

Log "=== instalar.ps1 inicio. Media=$Media ==="

# --- 1. copia de instaladores -------------------------------------------------
New-Item -ItemType Directory -Force -Path $dst | Out-Null
try {
  Copy-Item -Path (Join-Path $Media 'payload\*') -Destination $dst -Recurse -Force -ErrorAction Stop
  Log "Instaladores copiados a $dst"
} catch {
  Log "AVISO: no se pudo copiar todo desde el medio: $($_.Exception.Message)"
}

# --- 2. drivers virtio -------------------------------------------------------
$v = Join-Path $dst 'virtio-win-gt-x64.msi'
if (Test-Path $v) {
  $p = Start-Process msiexec.exe -ArgumentList "/i `"$v`" /qn /norestart /l*v C:\log-virtio.log" -Wait -PassThru
  Log "virtio-win-gt-x64.msi -> exit=$($p.ExitCode)"
} else { Log "AVISO: falta virtio-win-gt-x64.msi" }

# --- 3. agente de invitado ----------------------------------------------------
$q = Join-Path $dst 'qemu-ga-x86_64.msi'
if (Test-Path $q) {
  $p = Start-Process msiexec.exe -ArgumentList "/i `"$q`" /qn /norestart /l*v C:\log-qemu-ga.log" -Wait -PassThru
  Log "qemu-ga-x86_64.msi -> exit=$($p.ExitCode)"
  Start-Service -Name 'qemu-guest-agent' -ErrorAction SilentlyContinue
  Log "servicio qemu-guest-agent: $((Get-Service qemu-guest-agent -ErrorAction SilentlyContinue).Status)"
} else { Log "AVISO: falta qemu-ga-x86_64.msi" }

# --- 4. Rig Manager ----------------------------------------------------------
# La busqueda por patron va AQUI (ver la nota de la cabecera): a estas alturas la
# seccion 1 ya ha copiado los instaladores a $dst.
$msiF = Get-ChildItem -Path $dst -Filter 'Rig_Manager*.msi' -ErrorAction SilentlyContinue | Select-Object -First 1
$r = if ($msiF) { $msiF.FullName } else { Join-Path $dst 'Rig_Manager-no-encontrado.msi' }
if (Test-Path $r) {
  $p = Start-Process msiexec.exe -ArgumentList "/i `"$r`" /qn /norestart ALLUSERS=1 /l*v C:\log-rigmanager.log" -Wait -PassThru
  Log "Rig Manager -> exit=$($p.ExitCode)"
} else { Log "AVISO: falta el MSI de Rig Manager en $dst" }

# --- 5. acceso directo + autoarranque ---------------------------------------
$exe = Get-ChildItem -Path 'C:\Program Files', 'C:\Program Files (x86)' -Recurse -Filter 'Rig*.exe' -ErrorAction SilentlyContinue |
       Where-Object { $_.Name -notmatch 'setup|unins|vcredist|helper' } |
       Sort-Object Length -Descending | Select-Object -First 1

if ($exe) {
  Log "Ejecutable localizado: $($exe.FullName)"
  $ws  = New-Object -ComObject WScript.Shell
  $lnk = $ws.CreateShortcut('C:\Users\Public\Desktop\Rig Manager.lnk')
  $lnk.TargetPath       = $exe.FullName
  $lnk.WorkingDirectory = $exe.DirectoryName
  $lnk.Description      = 'Rig Manager (Kemper)'
  $lnk.Save()
  New-ItemProperty -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run' `
                   -Name 'RigManager' -Value "`"$($exe.FullName)`"" -PropertyType String -Force | Out-Null
  Log "Acceso directo creado y autoarranque configurado"

  # Inicio de sesión automático PERMANENTE (el del fichero de respuestas sólo
  # actúa en los primeros arranques). Así el usuario nunca ve la pantalla de
  # inicio de sesión de Windows: abre el lanzador y ya está dentro.
  $wl = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
  Set-ItemProperty -Path $wl -Name 'AutoAdminLogon'    -Value '1'                -Force
  Set-ItemProperty -Path $wl -Name 'DefaultUserName'   -Value 'kemper'           -Force
  Set-ItemProperty -Path $wl -Name 'DefaultDomainName' -Value $env:COMPUTERNAME  -Force
  Set-ItemProperty -Path $wl -Name 'DefaultPassword'   -Value 'kemper'           -Force
  Log "Auto-arranque de sesión permanente configurado (cuenta kemper)"
} else {
  Log "ERROR: no encuentro el ejecutable de Rig Manager. Revisa C:\log-rigmanager.log"
}

# --- resolucion de pantalla ---------------------------------------------------
# Si el instalador dejo la resolucion pedida en payload\resolucion.txt, se aplica
# ahora y se deja registrada para el PRIMER INICIO DE SESION: en este momento
# puede que el driver de video bueno aun no este cargado, y es despues del
# reinicio cuando el cambio se queda de verdad. Si no hay fichero, Windows se
# queda con la resolucion que elija (nada que hacer).
$resTxt    = Join-Path $PSScriptRoot 'resolucion.txt'
$resScript = Join-Path $PSScriptRoot 'resolucion.ps1'
if ((Test-Path $resTxt) -and (Test-Path $resScript)) {
  $valor = (Get-Content $resTxt -Raw).Trim()
  if ($valor -match '^([0-9]+)x([0-9]+)$') {
    $rw = $Matches[1]; $rh = $Matches[2]
    New-Item -ItemType Directory -Force -Path 'C:\kemper' | Out-Null
    Copy-Item $resScript 'C:\kemper\resolucion.ps1' -Force
    Start-Process -FilePath 'powershell.exe' -Wait -WindowStyle Hidden -ArgumentList `
      '-NoProfile','-ExecutionPolicy','Bypass','-File','C:\kemper\resolucion.ps1',$rw,$rh | Out-Null
    $orden = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\kemper\resolucion.ps1 $rw $rh"
    Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce' `
                     -Name 'KemperResolucion' -Value $orden -Force
    Log "resolucion de pantalla: ${rw}x${rh} aplicada ahora y registrada para el primer inicio de sesion"
  } else {
    Log "resolucion de pantalla: valor no valido en resolucion.txt ('$valor'); se ignora"
  }
} else {
  Log "resolucion de pantalla: automatica (no se ha pedido ninguna)"
}

# --- resumen -----------------------------------------------------------------
Log "--- producto registrado en el sistema:"
$found = Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
                       'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall' -ErrorAction SilentlyContinue |
         ForEach-Object { (Get-ItemProperty $_.PSPath).DisplayName } |
         Where-Object { $_ -match 'Rig|Kemper|Virtio|QEMU' } | Sort-Object -Unique
$found | ForEach-Object { Log "    $_" }

Log "=== instalar.ps1 fin ==="
