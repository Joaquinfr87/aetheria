<#
.SYNOPSIS
    Actualizador Automático del Modpack (Zero-Dependencies)
.DESCRIPTION
    Sincroniza los mods usando Packwiz. Si el usuario no tiene Java, 
    el script descarga una versión portable localmente sin tocar el sistema operativo.
#>

# ==========================================
# 1. Configuración General
# ==========================================
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$PackwizTomlUrl = "https://raw.githubusercontent.com/Joaquinfr87/aetheria/main/pack.toml"
$BootstrapUrl = "https://github.com/packwiz/packwiz-installer-bootstrap/releases/latest/download/packwiz-installer-bootstrap.jar"
$JreDownloadUrl = "https://api.adoptium.net/v3/binary/latest/21/ga/windows/x64/jre/hotspot/normal/eclipse"

$MinecraftDir = $PSScriptRoot 
$LogFile = Join-Path -Path $MinecraftDir -ChildPath "actualizador.log"
$BootstrapPath = Join-Path -Path $MinecraftDir -ChildPath "packwiz-installer-bootstrap.jar"
$RuntimeDir = Join-Path -Path $MinecraftDir -ChildPath ".java-runtime" # Carpeta oculta para Java
$JreZipPath = Join-Path -Path $MinecraftDir -ChildPath "temp-jre.zip"

Set-Location -Path $MinecraftDir

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $Timestamp = Get-Date -Format "HH:mm:ss"
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
Write-Log "Iniciando cliente (Modo Auto-Suficiente)..." "INFO"

# ==========================================
# 2. Gestión del Embedded Java Runtime
# ==========================================
$JavaExePath = $null

# Primero, comprobamos si ya descargamos nuestro Java portable en el pasado
if (Test-Path $RuntimeDir) {
    # Busca el ejecutable java.exe dentro de la carpeta extraída
    $JavaExePath = (Get-ChildItem -Path $RuntimeDir -Filter "java.exe" -Recurse | Select-Object -First 1).FullName
}

# Si no existe, lo descargamos y extraemos (solo ocurrirá la primera vez)
if (-not $JavaExePath) {
    Write-Log "Entorno Java no detectado. Descargando Java Portable (aprox 40MB)..." "WARN"
    Write-Log "Esto solo pasará la primera vez. Por favor, espera..." "WARN"
    
    try {
        Invoke-WebRequest -Uri $JreDownloadUrl -OutFile $JreZipPath -UseBasicParsing
        
        Write-Log "Extrayendo archivos de Java..." "INFO"
        # Creamos la carpeta si no existe
        if (-Not (Test-Path $RuntimeDir)) { New-Item -ItemType Directory -Path $RuntimeDir | Out-Null }
        
        # Descomprimimos el zip nativamente
        Expand-Archive -Path $JreZipPath -DestinationPath $RuntimeDir -Force
        
        # Borramos el zip para no ocupar espacio
        Remove-Item $JreZipPath -Force
        
        # Buscamos la ruta exacta del nuevo java.exe
        $JavaExePath = (Get-ChildItem -Path $RuntimeDir -Filter "java.exe" -Recurse | Select-Object -First 1).FullName
        Write-Log "Java Portable configurado con éxito." "OK"
        
    } catch {
        Write-Log "Error crítico al descargar Java. Revisa tu conexión a internet." "ERROR"
        Read-Host "Presiona Enter para salir"
        exit 1
    }
}

# ==========================================
# 3. Motor de Sincronización (Packwiz)
# ==========================================
if (-Not (Test-Path -Path $BootstrapPath)) {
    Write-Log "Descargando motor Packwiz..." "INFO"
    Invoke-WebRequest -Uri $BootstrapUrl -OutFile $BootstrapPath -UseBasicParsing
}

Write-Log "Sincronizando mods y texturas con GitHub..." "INFO"
Write-Host "--------------------------------------------------------" -ForegroundColor DarkGray

# ¡AQUÍ ESTÁ LA MAGIA! En lugar de llamar a 'java' global, usamos nuestra ruta portable absoluta
$PackwizArgs = "-jar `"$BootstrapPath`" -s client `"$PackwizTomlUrl`""

try {
    # Usamos el operador '&' (Call Operator) para ejecutar una ruta que contiene espacios
    $PackwizProcess = Start-Process -FilePath $JavaExePath -ArgumentList $PackwizArgs -Wait -NoNewWindow -PassThru
} catch {
    Write-Log "Error al ejecutar Packwiz." "ERROR"
    exit 1
}

Write-Host "--------------------------------------------------------" -ForegroundColor DarkGray

if ($PackwizProcess.ExitCode -ne 0) {
    Write-Log "Packwiz finalizó con código de error: $($PackwizProcess.ExitCode)" "ERROR"
    Read-Host "Presiona Enter para salir"
    exit 1
}

Write-Log "¡Servidor actualizado! Cierra esto y abre tu juego." "OK"
Start-Sleep -Seconds 3
