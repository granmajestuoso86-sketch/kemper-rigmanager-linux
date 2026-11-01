@echo off
rem ---------------------------------------------------------------------------
rem  instalar.cmd - lo lanza el fichero de respuestas en el primer inicio de
rem  sesion. Busca el medio del proyecto, deja copia de los instaladores en
rem  C:\INSTALADORES y llama a instalar.ps1.
rem
rem  REGLAS DE ESTE FICHERO (aprendidas a base de fallos):
rem   - SOLO caracteres ASCII, y nada de comillas en los comentarios: cmd.exe lee
rem     el .cmd con la pagina de codigos del sistema y el analizador se rompe.
rem   - Nada de cirugia de cadenas para adivinar rutas: la unidad se DETECTA
rem     comprobando que existe el fichero esperado.
rem   - Al pasar la unidad a PowerShell se pasa SIN barra final. Una barra antes
rem     de la comilla de cierre se interpreta como comilla escapada y PowerShell
rem     recibe una ruta rota (fallo real: intentaba abrir la ruta D:\ + comilla
rem     + payload). PowerShell ya la normaliza por su cuenta.
rem   - NO se redirige la salida de PowerShell al mismo registro que escribe este
rem     fichero: el .cmd mantiene el fichero abierto y las escrituras del script
rem     fallan con "being used by another process".
rem ---------------------------------------------------------------------------
setlocal
set "UNIDAD="
set "MEDIA="

for %%d in (D E F G H I J K L M N O P) do (
  if not defined UNIDAD if exist "%%d:\payload\instalar.ps1" (
    set "UNIDAD=%%d:"
    set "MEDIA=%%d:\"
  )
)

echo [%DATE% %TIME%] instalar.cmd UNIDAD=%UNIDAD% >> C:\kemper-install.log

if not defined UNIDAD (
  echo [%DATE% %TIME%] ERROR: no encuentro payload\instalar.ps1 en las unidades D a P >> C:\kemper-install.log
  exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%MEDIA%payload\instalar.ps1" -Media "%UNIDAD%" >> C:\log-powershell.txt 2>&1
exit /b %ERRORLEVEL%
