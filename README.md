# MainCleanMac 

[![macOS](https://img.shields.io/badge/macOS-14.0%2B%20Sonoma%20%7C%20Sequoia-black?style=flat-square&logo=apple)](https://apple.com)
[![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-M1%20%7C%20M2%20%7C%20M3%20%7C%20M4-0071e3?style=flat-square&logo=apple)](https://apple.com)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-F05138?style=flat-square&logo=swift)](https://swift.org)
[![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)](LICENSE)

**MainCleanMac** es una aplicación nativa para macOS en **Swift / SwiftUI** diseñada específicamente para procesadores **Apple Silicon**. Combina la facilidad de uso para cualquier persona con herramientas avanzadas para desarrolladores y usuarios pro, permitiendo recuperar gigabytes de almacenamiento sin romper configuraciones ni cerrar sesiones.

---

## ⚡ Características Principales

### 1. Experiencia de Doble Modo (`Modo Simple` vs. `Modo Avanzado (Pro)`)
- **Modo Simple (Predeterminado):** Diseñado para que cualquier usuario pueda optimizar su Mac con tranquilidad. Lenguaje claro, sin términos técnicos confusos y con dos acciones principales:
  - **Limpieza Rápida:** Elimina cachés de navegación, archivos temporales e instaladores antiguos de apps en un solo clic.
  - **Limpieza Profunda:** Recupera gigabytes atrapados en "Datos del Sistema", instaladores estancados y restos de programas ya eliminados.
- **Modo Avanzado (Pro):** Revela rutas exactas en formato POSIX (`~/Library/...`), identificadores de paquete (`bundleId`), telemetría de hardware en tiempo real (Swap, RAM Unificada, Instantáneas APFS) y controles granulares.

### 2. Desinstalador Completo de Aplicaciones
- Elimina cualquier aplicación junto con todos sus residuos ocultos en `~/Library` (`Application Support`, `Caches`, `Containers`, `Preferences`, `Saved Application State`).
- **Detección de Huérfanos:** Encuentra y elimina carpetas residuales de aplicaciones que borraste en el pasado.
- Desinstalación sin fricción mediante permisos de administración de aplicaciones (`TCC`).

### 3. Rayos X: Datos del Sistema y Explorador de Disco
- **¿Qué hay dentro de "Datos del Sistema"?:** Desglosa la "caja negra" del almacenamiento de macOS (juegos, contenedores, cachés de multimedia de Apple, instaladores como `com.docker.install` o `GoogleUpdater`).
- **Navegador por Tamaño:** Explora carpetas ordenadas de mayor a menor tamaño y envía al Basurero lo que no necesites.
- **Escudo de Seguridad Activo (`SafetyGuard`):** Protege automáticamente rutas críticas del sistema (`/System`, `/bin`, `/usr`) y del usuario (`~/.ssh`, `~/.gnupg`, Llaveros de contraseñas, Fototeca).

### 4. Optimizador Apple Silicon y Entorno Dev
- **Adelgazamiento de Binarios Mach-O:** Identifica aplicaciones con código duplicado para Intel (`x86_64`) y permite extraer la arquitectura nativa `arm64` (`lipo -thin arm64`).
- **Compactación SQLite sin Pérdida (`VACUUM`):** Desfragmenta bases de datos locales (Chrome, Safari, etc.) liberando páginas vacías sin tocar tus datos.
- **Limpieza de Proyectos:** Localiza carpetas pesadas como `node_modules`, `.venv`, `.next` y `target`.
- **Docker Manager:** Inspecciona y purga contenedores, volúmenes, imágenes y build cache.

### 5. Mantenimiento Automático en Segundo Plano
- Configura un agente nativo de macOS (`launchd`) para mantener tu equipo limpio de manera automática con la frecuencia que elijas.

---

## 🚀 Instalación y Primera Ejecución

### Descarga del Ejecutable
1. Descarga la versión más reciente desde [Releases](https://github.com/MainLake/adventurous-raman/releases).
2. Arrastra `MainCleanMac.app` a tu carpeta `/Applications`.

### ⚠️ Cómo abrir la app por primera vez (Sin cuenta de desarrollador de Apple)
Al no pagar la suscripción de $99 USD anuales de Apple, macOS Gatekeeper mostrará una advertencia al abrirla por primera vez:

> *"«MainCleanMac» no se puede abrir porque Apple no puede comprobar si contiene software malicioso."*

**Para autorizarla en 3 segundos (solo se hace una vez):**
1. Haz **clic derecho** (o `Control` + Clic) sobre `MainCleanMac.app`.
2. Selecciona **Abrir**.
3. En la ventana de confirmación, presiona el botón **Abrir**.

*(A partir de ese momento se abrirá con doble clic normal como cualquier otra app).*

> **Alternativa desde Ajustes:** Ve a **Ajustes del Sistema** > **Privacidad y seguridad** y presiona **"Abrir de todos modos"**.

---

## 🛠️ Compilación desde el Código Fuente

Requisitos:
- macOS 14.0 (Sonoma) o superior.
- Mac con procesador Apple Silicon (M1, M2, M3, M4).
- Swift 5.9+.

```bash
# Clonar el repositorio
git clone https://github.com/MainLake/adventurous-raman.git
cd adventurous-raman

# Ejecutar las pruebas unitarias automatizadas
swift test

# Compilar y empaquetar la app
./build_app.sh

# Abrir la app
open MainCleanMac.app
```

---

## 🧪 Pruebas Automatizadas

El proyecto cuenta con una suite de pruebas unitarias que validan:
- Blindaje de seguridad en rutas protegidas (`SafetyGuard`).
- Lógica de cálculo de almacenamiento APFS y formateo de bytes.
- Consistencia en el cambio de Modo Simple y Modo Avanzado.
- Gestión del registro de actividad en tiempo real.

Para ejecutarlas:
```bash
swift test
```

---

## 🏷️ Etiquetas / Topics para GitHub

Para mejorar la visibilidad del repositorio en las búsquedas de GitHub, añade estas etiquetas en la sección **About / Topics** de tu repositorio:

`macos` · `apple-silicon` · `swift` · `swiftui` · `cleaner` · `mac-cleaner` · `storage-cleaner` · `m1` · `m2` · `m3` · `m4` · `disk-cleanup` · `system-data` · `app-uninstaller` · `open-source` · `macos-utility` · `mac-utility` · `dev-tools` · `docker-cleaner` · `optimizer`

---

## 📄 Licencia

Distribuido bajo la Licencia MIT. Consulta `LICENSE` para más información.
