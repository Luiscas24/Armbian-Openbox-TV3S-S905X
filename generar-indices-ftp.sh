#!/bin/bash
# =========================================================================
# 📂 GENERADOR DE ÍNDICES FTP PARA GITHUB PAGES
# =========================================================================

REPO_RAIZ="$(pwd)"

echo "[+] Escaneando la bodega pool para generar índices FTP compatibles con lftp..."

# Buscamos todas las subcarpetas dentro de pool que contengan archivos .deb
find "$REPO_RAIZ/pool/" -type d | while read -r CARPETA; do
    
    # Contamos si hay archivos .deb en esta subcarpeta específica
    CONTEO_DEBS=$(find "$CARPETA" -maxdepth 1 -name "*.deb" | wc -l)
    
    if [ "$CONTEO_DEBS" -gt 0 ]; then
        NOMBRE_CARPETA=$(basename "$CARPETA")
        echo "📂 Indexando carpeta: $NOMBRE_CARPETA"
        
        # Iniciamos la estructura del index.html exclusivo de esta carpeta
        # Esto engaña a lftp haciéndole creer que es un listado de directorio tradicional
        cat <<EOF > "$CARPETA/index.html"
<!DOCTYPE html>
<html>
<head><title>Index of /$NOMBRE_CARPETA</title></head>
<body>
<h1>Index of /$NOMBRE_CARPETA</h1>
<hr><pre>
<a href="../">../</a>
EOF

        # Añadimos cada archivo .deb con su hash largo intacto al listado
        find "$CARPETA" -maxdepth 1 -name "*.deb" | while read -r ARCHIVO_DEB; do
            TEXTO_DEB=$(basename "$ARCHIVO_DEB")
            # lftp busca la estructura estándar de enlaces <a href="archivo">archivo</a>
            echo "<a href=\"$TEXTO_DEB\">$TEXTO_DEB</a>" >> "$CARPETA/index.html"
        done

        # Cerramos el archivo HTML secundario
        cat <<EOF >> "$CARPETA/index.html"
</pre><hr>
</body>
</html>
EOF
    fi
done

echo "✅ [OK] Índices FTP generados en las subcarpetas de pool sin tocar la raíz."
