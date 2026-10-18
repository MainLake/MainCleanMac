<p align="center">
  <h1 align="center">MainCleanMac</h1>
  <p align="center">
    <strong>Optimizador de almacenamiento y mantenimiento para macOS en Apple Silicon</strong>
  </p>
  <p align="center">
    <a href="https://apple.com"><img src="https://img.shields.io/badge/macOS-14.0%2B%20(Sonoma%20%7C%20Sequoia)-000000?style=for-the-badge&logo=apple&logoColor=white" alt="macOS" /></a>
    <a href="https://apple.com"><img src="https://img.shields.io/badge/Apple%20Silicon-M1%20%7C%20M2%20%7C%20M3%20%7C%20M4-0071e3?style=for-the-badge&logo=apple&logoColor=white" alt="Apple Silicon" /></a>
    <a href="https://swift.org"><img src="https://img.shields.io/badge/Swift-5.9%2B-F05138?style=for-the-badge&logo=swift&logoColor=white" alt="Swift" /></a>
    <a href="LICENSE"><img src="https://img.shields.io/badge/Licencia-MIT-2ea44f?style=for-the-badge" alt="Licencia" /></a>
  </p>
</p>

---

**MainCleanMac** es una aplicación de escritorio nativa diseñada desde cero en Swift y SwiftUI para exprimir el rendimiento y la arquitectura de los procesadores Apple Silicon. Recupera gigabytes de almacenamiento acumulados en cachés, residuos de aplicaciones y datos del sistema, sin riesgo de borrar archivos personales ni cerrar sesiones.

---

## Funcionalidades

### 🌓 Interfaz de Doble Modo
- **Modo Simple:** Pensado para cualquier usuario. Una vista clara del disco y dos botones de acción inmediata: *Limpieza Rápida* (temporales y cachés seguras) y *Limpieza Profunda* (instaladores y residuos ocultos).
- **Modo Avanzado (Pro):** Para desarrolladores y usuarios avanzados. Despliega rutas POSIX completas, telemetría de hardware en tiempo real (Swap, memoria unificada, instantáneas APFS) y control individual elemento por elemento.

### 🗑️ Desinstalador de Aplicaciones
- Remueve por completo cualquier aplicación junto con sus carpetas ocultas en `~/Library` (`Application Support`, `Caches`, `Containers`, `Preferences`, `Saved Application State`).
- **Limpieza de Huérfanos:** Detecta y elimina restos de programas desinstalados en el pasado.

### 🔍 Explorador y Datos del Sistema
- **Radiografía de Datos del Sistema:** Identifica qué elementos están inflando la categoría "Datos del Sistema" en macOS (instaladores pesados, cachés internas de navegadores, modelos locales y paquetes).
- **Navegador de Disco:** Explora carpetas ordenadas por tamaño para inspeccionar o enviar al Basurero lo que ya no utilices.
- **Escudo de Seguridad (`SafetyGuard`):** Protege automáticamente rutas críticas del sistema (`/System`, `/usr`, `/bin`) y datos sensibles del usuario (`.ssh`, `.gnupg`, Llaveros de contraseñas, Fototeca).

### ⚡ Herramientas para Apple Silicon y Desarrollo
- **Adelgazamiento de Binarios Mach-O:** Identifica aplicaciones universales con código redundante para Intel y permite conservar únicamente la arquitectura `arm64`.
- **Compactación SQLite (`VACUUM`):** Desfragmenta y recupera espacio en bases de datos locales sin pérdida de datos.
- **Artefactos de Desarrollo:** Limpieza de dependencias y builds locales (`node_modules`, `.venv`, `.next`, `target`).
- **Gestor Docker:** Inspección y purga de contenedores, volúmenes, imágenes y build cache.

### ⏰ Mantenimiento Automático
- Programación periódica mediante un agente nativo de macOS (`launchd`) para mantener el equipo optimizado en segundo plano.

---

## Instalación

1. Descarga la versión más reciente en la sección de [Releases](https://github.com/MainLake/MainCleanMac/releases).
2. Arrastra `MainCleanMac.app` a tu carpeta `/Applications`.
3. Al abrirla por primera vez:
   - Haz clic derecho sobre `MainCleanMac.app` y selecciona **Abrir**.
   - Haz clic en **Abrir** en el cuadro de diálogo de macOS.

---

## Compilación

Requisitos:
- macOS 14.0 o superior
- Procesador Apple Silicon (M1, M2, M3 o M4)
- Xcode 15 o Swift 5.9+

```bash
# Clonar el repositorio
git clone https://github.com/MainLake/MainCleanMac.git
cd MainCleanMac

# Compilar y empaquetar
./build_app.sh

# Ejecutar
open MainCleanMac.app
```

---

## Pruebas

El proyecto cuenta con pruebas automatizadas para validar la lógica de escaneo, cálculos de disco, clasificación de seguridad y consistencia de la interfaz:

```bash
swift test
```

---

## Licencia

Distribuido bajo la Licencia MIT. Consulta el archivo [LICENSE](LICENSE) para más información.
