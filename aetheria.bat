@echo off
title Lanzador del Servidor Minecraft
color 0B

echo ===================================================
echo Iniciando conexion con el servidor...
echo ===================================================
echo.

:: Esto asegura que la terminal se ubique en la misma carpeta donde esta el archivo .bat
cd /d "%~dp0"

:: Llama a PowerShell, ignora las restricciones y ejecuta tu script .ps1
PowerShell -NoProfile -ExecutionPolicy Bypass -File ".\actualizar-mods.ps1"

:: Si por alguna razon el script falla y se cierra, esto mantiene la ventana abierta para leer el error
echo.
pause
