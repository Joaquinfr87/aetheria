#!/bin/bash

# Inicializamos variables
failed_mods=()
failed_reasons=()
success_count=0
fail_count=0

# Limpiamos el log global previo
> errores.log

# Extraemos los IDs del JSON
mods=$(sudo jq -r '.files[].downloads[0]' /tmp/mrpack/modrinth.index.json | grep 'modrinth.com' | cut -d'/' -f5)

for mod_id in $mods; do
    echo "--------------------------------------"
    echo "Procesando ID: $mod_id"
    
    # Capturamos el error en un archivo temporal
    temp_err=$(mktemp)
    
    if packwiz modrinth install -y "$mod_id" 2> "$temp_err"; then
        echo "✅ LOGRADO"
        ((success_count++))
    else
        # Extraemos la última línea del error para el resumen
        error_msg=$(tail -n 2 "$temp_err" | head -n 1 | sed 's/^[ \t]*//')
        echo "❌ FALLÓ: $error_msg"
        
        failed_mods+=("$mod_id")
        failed_reasons+=("$error_msg")
        
        # Guardamos reporte detallado en el log
        echo "ID: $mod_id | Error: $error_msg" >> errores.log
        ((fail_count++))
    fi
    rm "$temp_err"
done

# --- REPORTE FINAL ---
echo -e "\n======================================"
echo "      REPORTE TÉCNICO DE FALLOS"
echo "======================================"
echo "Procesados: $((success_count + fail_count))"
echo "Exitosos:   $success_count"
echo "Fallidos:   $fail_count"
echo "--------------------------------------"

if [ ${#failed_mods[@]} -ne 0 ]; then
    echo -e "DETALLE DE ERRORES:\n"
    for i in "${!failed_mods[@]}"; do
        echo "Mod: https://modrinth.com/mod/${failed_mods[$i]}"
        echo "Causa: ${failed_reasons[$i]}"
        echo "-"
    done
    echo "--------------------------------------"
    echo "Log detallado disponible en: errores.log"
else
    echo "¡Configuración perfecta! No se detectaron errores."
fi
echo "======================================"
