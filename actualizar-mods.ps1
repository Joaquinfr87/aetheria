<#
.SYNOPSIS
    Actualizador Automático del Modpack del Servidor (Versión Portable)
.DESCRIPTION
    Sincroniza el estado local de Minecraft con el repositorio remoto usando Packwiz.
    Diseñado para ejecutarse directamente dentro de la carpeta de la instancia/juego.
#>

# ==========================================
# 1. Entorno y Configuración Estricta
# ==========================================
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# URLs (Ya con el enlace RAW corregido)
$PackwizTomlUrl = "https://raw.githubusercontent.com/Joaquinfr87/aetheria/main/pack.toml"
$BootstrapUrl = "https://github.com/packwiz/packwiz-installer-bootstrap/releases/latest/download/packwiz-installer-bootstrap.jar"

# ==========================================
# ¡LA MAGIA PORTABLE ESTÁ AQUÍ!
# ==========================================
# En lugar de ir a %APPDATA%, usamos el directorio actual donde está este script
$MinecraftDir = $PSScriptRoot 
$LogFile = Join-Path -Path $MinecraftDir -ChildPath "actualizador-servidor.log"
$BootstrapPath = Join-Path -Path $MinecraftDir -ChildPath "packwiz-installer-bootstrap.jar"

# Nos aseguramos de estar trabajando en esta misma carpeta
Set-Location -Path $MinecraftDir

# ==========================================
# 2. Sistema de Logging Integrado
# ==========================================
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] [$Level] $Message"
    
    switch ($Level) {
        "INFO"  { Write-Host $Message -ForegroundColor Cyan }
        "OK"    { Write-Host $Message -ForegroundColor Green }
        "WARN"  { Write-Host $Message -ForegroundColor Yellow }
        "ERROR" { Write-Host $Message -ForegroundColor Red }
    }
    
    Add-Content -Path $LogFile -Value $LogEntry
}

if (Test-Path $LogFile) { Clear-Content $LogFile }
Clear-Host
Write-Log "Iniciando cliente de sincronización (Modo Portable)..." "INFO"
Write-Log "Directorio de trabajo: $MinecraftDir" "INFO"

# ==========================================
# 3. Validación de Dependencias (Java)
# ==========================================
Write-Log "Verificando dependencias del sistema..." "INFO"
try {
    $JavaVer = & java -version 2>&1
    Write-Log "Java detectado correctamente." "OK"
} catch {
    Write-Log "Java no está instalado o no está en el PATH." "ERROR"
    Write-Log "Abriendo el navegador para descargar Java 21..." "WARN"
    Start-Sleep -Seconds 2
    Start-Process "https://adoptium.net/es/temurin/releases/?version=21"
    
    Write-Host "`nPor favor, instala Java y vuelve a ejecutar este script." -ForegroundColor Yellow
    Write-Host "Presiona cualquier tecla para salir..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

# ==========================================
# 4. Motor de Sincronización (Packwiz)
# ==========================================
if (-Not (Test-Path -Path $BootstrapPath)) {
    Write-Log "Descargando motor de despliegue local (Packwiz Bootstrap)..." "INFO"
    try {
        Invoke-WebRequest -Uri $BootstrapUrl -OutFile $BootstrapPath -UseBasicParsing
        Write-Log "Motor descargado con éxito." "OK"
    } catch {
        Write-Log "Fallo de red al descargar el motor. Verifica tu conexión." "ERROR"
        exit 1
    }
}

Write-Log "Sincronizando estado local con el repositorio remoto..." "INFO"
Write-Host "--------------------------------------------------------" -ForegroundColor DarkGray

# Ejecución del proceso
$PackwizProcess = Start-Process -FilePath "java" -ArgumentList "-jar", "packwiz-installer-bootstrap.jar", "-s", "client", $PackwizTomlUrl -Wait -NoNewWindow -PassThru

Write-Host "--------------------------------------------------------" -ForegroundColor DarkGray

if ($PackwizProcess.ExitCode -ne 0) {
    Write-Log "Packwiz finalizó con código de error: $($PackwizProcess.ExitCode)" "ERROR"
    Write-Log "Revisa el log en $LogFile y envíaselo a Joaquín." "WARN"
    Read-Host "Presiona Enter para salir"
    exit 1
}

Write-Log "Sincronización finalizada exitosamente." "OK"

# ==========================================
# 5. Cierre
# ==========================================
Write-Log "¡Todo listo! Cierra esta ventana y abre el juego desde tu launcher." "OK"
Start-Sleep -Seconds 3
