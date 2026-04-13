#!/bin/bash
MRPACK_FILE="$1"
PACK_DIR="$2"

if [ -z "$MRPACK_FILE" ] || [ -z "$PACK_DIR" ]; then
    echo "Uso: $0 <archivo.mrpack> <directorio_destino>"
    exit 1
fi

if [ ! -f "$MRPACK_FILE" ]; then
    echo "Error: No existe $MRPACK_FILE"
    exit 1
fi

# Verificar herramientas
command -v packwiz >/dev/null 2>&1 || { echo "Error: packwiz no instalado"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "Error: jq no instalado"; exit 1; }

mkdir -p "$PACK_DIR"
cd "$PACK_DIR" || exit 1

# Extraer .mrpack
TEMP_DIR=$(mktemp -d)
unzip -q "$MRPACK_FILE" -d "$TEMP_DIR"
INDEX="$TEMP_DIR/modrinth.index.json"

if [ ! -f "$INDEX" ]; then
    echo "Error: No se encontró modrinth.index.json"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Leer versión de Minecraft y loader
MC_VERSION=$(jq -r '.dependencies.minecraft' "$INDEX")
LOADER=$(jq -r '.dependencies | keys[] | select(. != "minecraft")' "$INDEX" | head -1)
LOADER_VERSION=$(jq -r ".dependencies.\"$LOADER\"" "$INDEX")

if [ -z "$LOADER" ]; then
    echo "Error: No se detectó loader (neoforge/forge/fabric)"
    rm -rf "$TEMP_DIR"
    exit 1
fi

echo "MC Version: $MC_VERSION"
echo "Loader: $LOADER ($LOADER_VERSION)"

# Crear pack.toml manualmente (evita prompts)
cat > pack.toml << EOF
name = "$(basename "$PACK_DIR")"
author = "auto-import"
version = "1.0.0"
pack-format = "packwiz:1.0.0"

[index]
hash-format = "sha256"
file = "index.toml"

[versions]
minecraft = "$MC_VERSION"
$LOADER = "$LOADER_VERSION"
EOF

# Crear index.toml vacío inicial
echo "hash = {}" > index.toml

# Añadir mods
TOTAL=$(jq '.files | length' "$INDEX")
SUCCESS=0
FAIL=0
FAILED_LIST=()

for ((i=0; i<TOTAL; i++)); do
    URL=$(jq -r ".files[$i].downloads[0]" "$INDEX")
    PATH_FILE=$(jq -r ".files[$i].path" "$INDEX")
    
    if [[ "$URL" =~ https://cdn.modrinth.com/data/([^/]+)/versions/([^/]+)/ ]]; then
        PROJ="${BASH_REMATCH[1]}"
        VER="${BASH_REMATCH[2]}"
        echo -n "[$i/$TOTAL] Añadiendo $PROJ@$VER ... "
        if packwiz modrinth add -y "${PROJ}@${VER}" >/dev/null 2>&1; then
            echo "OK"
            ((SUCCESS++))
        else
            echo "ERROR"
            ((FAIL++))
            FAILED_LIST+=("$PROJ@$VER")
        fi
    else
        echo "[$i/$TOTAL] Copiando archivo no-mod: $PATH_FILE"
        mkdir -p "$(dirname "$PATH_FILE")"
        cp "$TEMP_DIR/$PATH_FILE" "$PATH_FILE" 2>/dev/null || echo "  Advertencia: no se pudo copiar $PATH_FILE"
    fi
done

# Copiar overrides si existen
if [ -d "$TEMP_DIR/overrides" ]; then
    echo "Copiando overrides..."
    cp -r "$TEMP_DIR/overrides"/* . 2>/dev/null
fi

# Refrescar índice
echo "Refrescando índice..."
packwiz refresh >/dev/null 2>&1

# Limpiar
rm -rf "$TEMP_DIR"

# Mostrar resumen
echo "============================"
echo "Mods añadidos correctamente: $SUCCESS"
echo "Fallos: $FAIL"
if [ $FAIL -gt 0 ]; then
    echo "Mods fallidos:"
    for mod in "${FAILED_LIST[@]}"; do
        echo "  - $mod"
    done
fi
echo "============================"
