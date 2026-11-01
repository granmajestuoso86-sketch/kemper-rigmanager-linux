# ============================================================================
#  resolucion.ps1 - fija la resolucion de pantalla de Windows.
#  Se llama:  powershell -ExecutionPolicy Bypass -File resolucion.ps1 1920 1200
#  y queda registrado para volver a aplicarse en el primer inicio de sesion,
#  que es cuando el driver de video ya esta cargado de verdad.
#  Si falla, se apunta en C:\log-resolucion.txt y Windows se queda como estaba:
#  es un ajuste de comodidad, nunca debe romper nada.
#  (Solo ASCII a proposito: se ejecuta en un Windows recien instalado.)
# ============================================================================
param([int]$Ancho, [int]$Alto)

$log = 'C:\log-resolucion.txt'
function Apunta($t) { "$((Get-Date).ToString('HH:mm:ss'))  $t" | Add-Content -Path $log -Encoding UTF8 }

Apunta "=== resolucion.ps1: peticion ${Ancho}x${Alto} ==="
if ($Ancho -lt 640 -or $Alto -lt 480) { Apunta "valores fuera de rango: no hago nada"; exit 1 }

# DEVMODEA ocupa 220 bytes. Solo se rellenan los campos que la llamada mira:
#   offset  36: dmSize (WORD)        = 220
#   offset  40: dmFields (DWORD)     = DM_BITSPERPEL | DM_PELSWIDTH | DM_PELSHEIGHT
#   offset 112: dmBitsPerPel (DWORD) = 32
#   offset 116: dmPelsWidth (DWORD)
#   offset 120: dmPelsHeight (DWORD)
# Se trabaja con un bloque de bytes en vez de declarar la estructura entera:
# asi no hay forma de equivocarse con el relleno (padding) de los campos.
$dm = New-Object byte[] 220
[BitConverter]::GetBytes([uint16]220).CopyTo($dm, 36)
[BitConverter]::GetBytes([uint32](0x00080000 -bor 0x00100000 -bor 0x00040000)).CopyTo($dm, 40)
[BitConverter]::GetBytes([uint32]32).CopyTo($dm, 112)
[BitConverter]::GetBytes([uint32]$Ancho).CopyTo($dm, 116)
[BitConverter]::GetBytes([uint32]$Alto).CopyTo($dm, 120)

try {
  Add-Type -Namespace Kemper -Name Nativa -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("user32.dll", CharSet=System.Runtime.InteropServices.CharSet.Ansi)]
public static extern int ChangeDisplaySettings(System.IntPtr lpDevMode, uint dwFlags);
'@ -ErrorAction Stop
  $ptr = [System.Runtime.InteropServices.Marshal]::AllocHGlobal(220)
  try {
    [System.Runtime.InteropServices.Marshal]::Copy($dm, 0, $ptr, 220)
    $r = [Kemper.Nativa]::ChangeDisplaySettings($ptr, 0)
  } finally { [System.Runtime.InteropServices.Marshal]::FreeHGlobal($ptr) }
  switch ($r) {
     0   { Apunta "aplicada: ${Ancho}x${Alto}" }
     1   { Apunta "aplicada: ${Ancho}x${Alto} (pide reiniciar)" }
    -1   { Apunta "NO se ha podido aplicar (el driver de video no la admite en este momento)" }
    -2   { Apunta "ese tamano no lo admite el adaptador; se queda el actual" }
    default { Apunta "resultado inesperado: $r" }
  }
} catch { Apunta "ERROR: $($_.Exception.Message)" }
