# MainCleanMac 

[![macOS](https://img.shields.io/badge/macOS-14.0%2B%20Sonoma%20%7C%20Sequoia-black?style=flat-square&logo=apple)](https://apple.com)
[![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-M1%20%7C%20M2%20%7C%20M3%20%7C%20M4-0071e3?style=flat-square&logo=apple)](https://apple.com)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-F05138?style=flat-square&logo=swift)](https://swift.org)
[![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)](LICENSE)

**MainCleanMac** es una utilidad nativa de código abierto en **Swift y SwiftUI** diseñada específicamente para Mac con arquitectura **Apple Silicon**. Proporciona un sistema moderno de limpieza de almacenamiento, inspección profunda de datos del sistema y mantenimiento sin pérdida de datos.

---

## ⚡ Características

- **Modo Dual Adaptativo:**
  - **Modo Simple:** Interfaz intuitiva para cualquier usuario. Limpieza rápida en 1 clic de archivos temporales y recuperación de espacio sin configuraciones complejas.
  - **Modo Avanzado (Pro):** Control granular para desarrolladores y usuarios avanzados, con rutas POSIX completas, bundle IDs, telemetría de memoria unificada (Swap, RAM, instantáneas APFS) e inspección detallada.
- **Desinstalador Completo:**
  - Desinstalación limpia de aplicaciones y eliminación de carpetas residuales asociadas (`Application Support`, `Caches`, `Containers`, `Preferences`, `Saved Application State`).
  - Detección y eliminación de residuos de aplicaciones desinstaladas previamente (archivos huérfanos).
- **Inspección de "Datos del Sistema":**
  - Desglose y análisis detallado de directorios pesados clasificados dentro de Datos del Sistema en macOS.
  - Limpieza de instaladores estancados, cachés internas de navegadores y paquetes antiguos.
- **Optimizador Apple Silicon y Herramientas Dev:**
  - Detección de binarios universales con código redundante Intel x86_64 y soporte para adelgazamiento a `arm64`.
  - Compactación de bases de datos SQLite locales (`VACUUM`) sin pérdida de información ni cierre de sesiones.
  - Limpieza de artefactos de desarrollo (`node_modules`, `.venv`, `.next`, `target`).
  - Gestión y purga de Docker (contenedores, volúmenes, imágenes y build cache).
- **Escudo de Protección (`SafetyGuard`):**
  - Protección activa para prevenir la eliminación accidental de rutas críticas del sistema (`/System`, `/usr`, `/bin`) y archivos personales sensibles (`.ssh`, `.gnupg`, llaveros de contraseñas, bibliotecas).
- **Mantenimiento Programado:**
  - Soporte para automatización en segundo plano mediante un agente nativo de macOS (`launchd`).

---

## 🚀 Instalación

### Descarga directa
1. Descarga la versión más reciente desde [Releases](https://github.com/MainLake/MainCleanMac/releases).
2. Abre el archivo descargado y mueve `MainCleanMac.app` a tu carpeta `/Applications`.
3. Para abrir la aplicación por primera vez:
   - Haz **clic derecho** (o `Control` + clic) sobre `MainCleanMac.app` y selecciona **Abrir**.
   - Confirma la apertura en el mensaje de seguridad de macOS.

---

## 🛠️ Compilación desde el código fuente

### Requisitos previos
- macOS 14.0 (Sonoma) o superior.
- Mac con procesador Apple Silicon (M1, M2, M3 o M4).
- Xcode 15+ o Swift Toolchain 5.9+.

```bash
# Clonar el repositorio
git clone https://github.com/MainLake/MainCleanMac.git
cd MainCleanMac

# Ejecutar las pruebas unitarias
swift test

# Compilar e instalar en /Applications
./build_app.sh

# Ejecutar la aplicación
open MainCleanMac.app
```

---

## 🧪 Pruebas Automatizadas

El proyecto incluye una suite de pruebas para verificar la integridad del escaneo, cálculos de disco, clasificación de seguridad y lógica de negocio:

```bash
swift test
```

---

## 📄 Licencia

Este proyecto está bajo la Licencia MIT. Consulta el archivo [LICENSE](LICENSE) para más detalles.
