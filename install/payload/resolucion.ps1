# =============================================================================
#  resolucion.ps1 - fija la resolucion de pantalla de Windows.
#
#  Uso:  powershell -NoProfile -ExecutionPolicy Bypass -File resolucion.ps1 1920 1200
#
#  La parte delicada -- la estructura DEVMODE y las llamadas a Windows -- esta
#  copiada del modulo "ChangeScreenResolution" de la PowerShell Gallery, que es
#  codigo usado por muchisima gente. La version anterior de este script calculaba
#  a mano en que byte iba cada campo, se equivocaba, y por eso no hacia nada: al
#  pedir 1600x900 le escribia el ancho y el alto en campos que no eran.
#  Leccion: no calcular a mano estructuras de Windows; usar una ya probada.
#
#  Ademas de pedir un tamano, mira QUE TAMANOS OFRECE de verdad la pantalla y
#  elige el mas parecido: dentro de una maquina virtual no estan todos. Lo cuenta
#  todo por pantalla y lo apunta en C:\log-resolucion.txt.
#
#  Solo ASCII a proposito: se ejecuta en un Windows recien instalado.
# =============================================================================
param([int]$Ancho, [int]$Alto)

$log = 'C:\log-resolucion.txt'
function Apunta($t) {
  "$((Get-Date).ToString('HH:mm:ss'))  $t" | Add-Content -Path $log -Encoding UTF8
  Write-Host "  $t"
}

$pinvoke = @"
using System;
using System.Runtime.InteropServices;
namespace KemperPantalla {
  [StructLayout(LayoutKind.Sequential)]
  public struct DEVMODE1 {
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmDeviceName;
    public short dmSpecVersion; public short dmDriverVersion; public short dmSize; public short dmDriverExtra;
    public int dmFields;
    public short dmOrientation; public short dmPaperSize; public short dmPaperLength; public short dmPaperWidth;
    public short dmScale; public short dmCopies; public short dmDefaultSource; public short dmPrintQuality;
    public short dmColor; public short dmDuplex; public short dmYResolution; public short dmTTOption; public short dmCollate;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmFormName;
    public short dmLogPixels; public short dmBitsPerPel;
    public int dmPelsWidth; public int dmPelsHeight; public int dmDisplayFlags; public int dmDisplayFrequency;
    public int dmICMMethod; public int dmICMIntent; public int dmMediaType; public int dmDitherType;
    public int dmReserved1; public int dmReserved2; public int dmPanningWidth; public int dmPanningHeight;
  }
  public class Pantalla {
    [DllImport("user32.dll")] public static extern int EnumDisplaySettings(string deviceName, int modeNum, ref DEVMODE1 devMode);
    [DllImport("user32.dll")] public static extern int ChangeDisplaySettings(ref DEVMODE1 devMode, int flags);
    public const int ENUM_CURRENT_SETTINGS = -1;
    public const int CDS_UPDATEREGISTRY = 0x01;
    public const int CDS_TEST = 0x02;

    private static DEVMODE1 Nuevo() {
      DEVMODE1 dm = new DEVMODE1();
      dm.dmDeviceName = new String(new char[32]);
      dm.dmFormName   = new String(new char[32]);
      dm.dmSize       = (short)Marshal.SizeOf(dm);
      return dm;
    }
    public static DEVMODE1 Actual() {
      DEVMODE1 dm = Nuevo();
      EnumDisplaySettings(null, ENUM_CURRENT_SETTINGS, ref dm);
      return dm;
    }
    public static string TamanosDisponibles() {
      var lista = new System.Collections.Generic.List<string>();
      for (int i = 0; i < 500; i++) {
        DEVMODE1 dm = Nuevo();
        if (EnumDisplaySettings(null, i, ref dm) == 0) break;
        string s = dm.dmPelsWidth + "x" + dm.dmPelsHeight;
        if (!lista.Contains(s)) lista.Add(s);
      }
      return string.Join(" ", lista.ToArray());
    }
    public static int TamanoEstructura() { return Marshal.SizeOf(typeof(DEVMODE1)); }
    // Aplica un MODO DE LA PROPIA LISTA de la pantalla, entero (con su profundidad
    // de color y su frecuencia), en vez de retocar el modo actual cambiandole el
    // ancho y el alto: eso ultimo falla cuando esa combinacion no existe en la
    // lista. Es lo que pasaba aqui: pedia 1920x1080 sobre el modo actual y Windows
    // contestaba "no lo admite", aunque 1920x1080 si este entre los disponibles.
    public static string Pon(int w, int h) {
      DEVMODE1 elegido = Nuevo(); bool hay = false;
      for (int intento = 0; intento < 2 && !hay; intento++) {
        for (int i = 0; i < 500; i++) {
          DEVMODE1 dm = Nuevo();
          if (EnumDisplaySettings(null, i, ref dm) == 0) break;
          if (dm.dmPelsWidth != w || dm.dmPelsHeight != h) continue;
          if (intento == 0 && dm.dmBitsPerPel < 32) continue;   // 1a vuelta: el mejor color
          elegido = dm; hay = true; break;
        }
      }
      if (!hay) return "NO_ESTA";
      // NO se usa la comprobacion previa (CDS_TEST): en varias tarjetas graficas
      // contesta "fallo" para modos que despues si funcionan. Se aplica y se
      // comprueba LEYENDO la resolucion real, que es la unica prueba que vale.
      int r = ChangeDisplaySettings(ref elegido, CDS_UPDATEREGISTRY);
      DEVMODE1 ahora = Actual();
      return "codigo " + r + ", profundidad " + elegido.dmBitsPerPel + ", pantalla ahora en " + ahora.dmPelsWidth + "x" + ahora.dmPelsHeight;
    }
  }
}
"@
try { Add-Type $pinvoke -ErrorAction Stop } catch { Apunta "ERROR al preparar las llamadas a Windows: $($_.Exception.Message)"; exit 1 }

Apunta "peticion: ${Ancho}x${Alto}"
$antes = [KemperPantalla.Pantalla]::Actual()
Apunta "ahora mismo: $($antes.dmPelsWidth)x$($antes.dmPelsHeight)"
Apunta "(la estructura que uso mide $([KemperPantalla.Pantalla]::TamanoEstructura()) bytes; tiene que ser 156)"

$disp = [KemperPantalla.Pantalla]::TamanosDisponibles()
if ([string]::IsNullOrWhiteSpace($disp)) { Apunta "ERROR: la pantalla no me dice ningun tamano"; exit 1 }
Apunta "tamanos que ofrece esta pantalla: $disp"

$pedido = "${Ancho}x${Alto}"
$lista = $disp -split ' '
$objetivo = $pedido
if ($lista -notcontains $pedido) {
  $area = $Ancho * $Alto
  $mejor = ""; $mejorArea = -1
  foreach ($t in $lista) {
    $p = $t -split 'x'
    if ($p.Count -ne 2) { continue }
    $a = [int]$p[0] * [int]$p[1]
    if ($a -le $area -and $a -gt $mejorArea) { $mejorArea = $a; $mejor = $t }
  }
  if ($mejor -eq "") {
    # todos los tamanos disponibles son mayores: se coge el mas pequeno de todos
    $minArea = -1
    foreach ($t in $lista) {
      $p = $t -split 'x'
      if ($p.Count -ne 2) { continue }
      $a = [int]$p[0] * [int]$p[1]
      if ($minArea -eq -1 -or $a -lt $minArea) { $minArea = $a; $mejor = $t }
    }
  }
  Apunta "el pedido ${pedido} no esta entre los que ofrece la pantalla; uso $mejor"
  $objetivo = $mejor
}

$p2 = $objetivo -split 'x'
Apunta "aplicando $objetivo ..."
$res = [KemperPantalla.Pantalla]::Pon([int]$p2[0], [int]$p2[1])
Apunta "resultado: $res"
Apunta "=== fin ==="
