# RamanSweep · Adventurous M-Series Cleaner

**RamanSweep** (nacido en el proyecto `adventurous-raman`) es un optimizador de almacenamiento y limpiador profundo nativo en **Swift / SwiftUI** diseñado específicamente para Macs con procesadores **Apple Silicon (M1 / M2 / M3 / M4)**.

## Características Principales

- **Motor Chip M (`AppleSiliconOptimizerView`):**
  - **Inspector y Adelgazador de Binarios Mach-O (`arm64` vs `x86_64`):** Detecta aplicaciones *Universal* y *Rosetta 2*, protegiendo firmas criptográficas de la App Store y permitiendo adelgazar binarios con `lipo -thin arm64`.
  - **Compactación SQLite sin Pérdida (`VACUUM`):** Desfragmenta bases de datos locales (Chrome, Safari, Codex, etc.) sin borrar datos ni cerrar sesiones.
  - **Neural Engine & Caché Darwin:** Limpia cachés de inferencia visual (`mediaanalysisd`), modelos LLM locales y miniaturas/shaders de QuickLook (`DARWIN_USER_CACHE`).
  - **Telemetría de Memoria Unificada e Instantáneas APFS:** Monitorea el uso de Swap en SSD y ejecuta `tmutil thinlocalsnapshots` para recuperar bloques retenidos.
  - **Cazador de LaunchAgents Huérfanos:** Detecta demonios en `~/Library/LaunchAgents` cuyo ejecutable ya no existe.
- **Rayos X: Datos del Sistema (`SystemDataXRayView`):**
  - Abre la "caja negra" de los *Datos del sistema* de macOS, explicando exactamente qué carpetas ocultas, juegos auto-actualizables, contenedores o gestores de paquetes están consumiendo espacio y permitiendo liberarlos de forma segura.
- **Desinstalador Completo sin Contraseña (`AppUninstallerView`):**
  - Desinstala aplicaciones junto con todos sus residuos en `~/Library` (`Application Support`, `Caches`, `Containers`, `Preferences`, `Saved Application State`) e integra permisos TCC (`App Management` / `Finder AppleEvents`) al estilo Pearcleaner.
- **Explorador Visual con Escudo de Seguridad (`SpaceLensView`):**
  - Navegación instantánea en memoria con bloqueo activo (`SafetyGuard`) sobre rutas críticas (`~/Library/Keychains`, `~/.ssh`, `Photos Library`, `/System`).
- **Zona Desarrollador & Docker (`DevAndDockerHubView`):**
  - Purga inteligente de `node_modules`, `.venv`, `target`, `.next` y gestión completa de contenedores, volúmenes, imágenes y build cache de Docker.
- **Automatización Silenciosa (`AutomationSchedulerView`):**
  - Programación periódica nativa mediante `launchd` (`com.mainlake.ramansweep.periodic`).

## Compilación y Ejecución

```bash
./build_app.sh
open RamanSweep.app
```
