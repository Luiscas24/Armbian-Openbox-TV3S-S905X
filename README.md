# 🧰 armbian-tv3s-toolbox

Una caja de herramientas diseñada para optimizar, parchear y completar la instalación de Armbian en dispositivos TV3s y TV Boxes con procesador **Amlogic S905X** (Hardware económico de ~$80,000 COP). 

Este proyecto nace como una solución comunitaria ante la caída de los servidores beta oficiales de Armbian, permitiendo acceder a drivers y kernels actualizados de forma independiente.

---

### ⚠️ Requisito Previo (Paso 0)
Este proyecto **no reemplaza tu sistema actual ni elimina Android TV**. El ecosistema funciona en modo dual. Antes de usar esta caja de herramientas, debes:
1. Descargar e instalar una imagen base de Armbian para S905X en tu tarjeta MicroSD.
2. Configurar e iniciar el TV Stick desde la MicroSD por primera vez.

---

### 🚀 Hoja de Ruta del Proyecto (Iteración paso a paso)

*   [ ] **Fase 1: Motor del Sistema (Kernel & Conectividad):** Compilación automatizada en la nube de un Kernel moderno (6.x Edge) que incluye los drivers de red críticos (Realtek) actualmente inaccesibles. *(Siguiente paso)*
*   [ ] **Fase 2: Almacenamiento Híbrido:** Script de post-instalación para montar de forma segura la memoria interna (eMMC) y compartir archivos con Android TV.
*   [ ] **Fase 3: Inyección de Rendimiento:** Activación automatizada de zRAM (compresión de memoria) para optimizar los límites de la RAM (1GB/2GB).
*   [ ] **Fase 4: Estación de Trabajo Ligera:** Scripts de instalación optimizada para VS Codium y Chromium Educativo con bloqueador de anuncios integrado.

---
*Desarrollado con fines educativos y de impacto social para la democratización del acceso a hardware de ultra-bajo costo.*
