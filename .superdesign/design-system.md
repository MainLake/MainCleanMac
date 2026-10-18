# MainCleanMac — Design System & Architecture (`v1.0.0-pre`)

## 1. Product Context & Jobs-To-Be-Done (JTBD)
- **Product Name**: `MainCleanMac` (`MainCleanMac.app`, Bundle ID `com.mainlake.maincleanmac`)
- **Platform**: Native macOS Application (Apple Silicon M1/M2/M3/M4 optimized, SwiftUI / AppKit)
- **Core Philosophy**: **"Moderno, sobrio, directo y 100% accionable"**. No flashy neon gimmicks or cryptic metaphors. Every label states literally what it does. Every action gives real-time visual feedback, auto-dismissing notifications (4s timer bar), and immediately updates the free disk space counter.

## 2. Navigation Architecture (5 Literal, Non-Overlapping Sections)
1. **Resumen General** (`ESPACIO EN DISCO Y ACCIONES RÁPIDAS`)
   - **Live Storage Bar**: Shows Free Space (updates immediately with animated delta badge `+X GB liberados` when anything is cleaned), Used Space, Apps, and Reclaimable Space.
   - **2 Primary One-Click Action Cards**:
     - **Card 1: Limpieza Rápida Segura (1 Clic — Sin Preguntar)**: Immediately cleans 100% safe caches (`~/Library/Caches`, logs, Crashpad, GPUCache, Service Workers, QuickLook, SQLite VACUUM) without confirmation dialogs or closing sessions.
     - **Card 2: Limpieza Profunda del Sistema**: Cleans heavy `Datos del Sistema` bloat (`com.docker.install`, orphaned app leftovers in `Application Support`, package manager caches `Homebrew`/`npm`/`pnpm`/`uv`/`Cargo`, macOS 4K aerial videos, hidden dotfile caches `~/.claude/projects`, APFS local snapshots).
   - **Limpieza Automática Programada**: Clean inline toggle & frequency selector (`Diario`, `Semanal`, `Mensual`) powered by `launchd`.
2. **Cachés y Datos del Sistema** (`LIMPIAR BASURA SIN PERDER SESIONES`)
   - Two-column master-detail view separating the 5 unified categories (zero duplicates across tabs):
     - *Cachés de Navegadores y Apps*
     - *Basura Interna en Application Support*
     - *Sistema, Logs y Videos 4K Ocultos*
     - *Gestores de Paquetes y Carpetas Ocultas*
     - *Xcode, Simuladores e IA Local*
3. **Desinstalador de Apps** (`BORRAR PROGRAMAS Y RESTOS HUÉRFANOS`)
   - Tab 1: **Aplicaciones Instaladas** (Left list + Right full breakdown of `.app` + `~/Library` files + "Desinstalar por Completo" via TCC / Finder).
   - Tab 2: **Restos de Apps Desinstaladas** (Unified list of all orphaned folders in `Application Support`, `Caches`, `Containers`, and `Preferences` from uninstalled apps like Claude, Zoom, Postman, Codex, Trae).
4. **Desarrollo, Docker y Chip M** (`PROYECTOS, VERSIONES, CONTENEDORES Y HARDWARE`)
   - Tab 1: **Dependencias de Proyectos** (`node_modules`, `.venv`, `target`, `.next` + duplicate runtimes in `~/.nvm` and `~/.pyenv`).
   - Tab 2: **Docker** (Containers, Volumes, Images, Build Cache).
   - Tab 3: **Hardware Apple Silicon** (Mach-O `arm64 vs Intel` inspector & `lipo` thinning, Unified RAM / Swap / SQLite Vacuum / APFS Snapshots).
5. **Explorador de Disco** (`NAVEGAR CARPETAS POR TAMAÑO Y ELIMINAR`)
   - Fast interactive folder size explorer with top shortcut pills to *"Datos del Sistema"* locations (`Inicio`, `Application Support`, `Containers`, `Apps`, `Raíz /`) and direct **"Eliminar"** buttons on every non-critical subfolder.

## 3. Visual Direction & Palette (Modern, Restrained macOS Dark Pro)
- **Aesthetic**: Inspired by Linear, Raycast, and Apple's native System Settings in Dark Mode — restrained, high-contrast typography, 1px hairline borders, subtle surfaces, zero neon clutter.
- **Colors**:
  - **Window Background (`canvasBg`)**: `#0D0F12` (Deep neutral slate-charcoal)
  - **Sidebar / Rail Background (`sidebarBg`)**: `#12151A`
  - **Card / Surface (`panelBg`)**: `#161A20` with `1px solid rgba(255,255,255,0.07)` border
  - **Elevated Hover / Active Surface**: `#1C2129`
  - **Primary Accent (`brandBlue`)**: `#3B82F6` (Calm, trustworthy macOS pro blue)
  - **Safe / Free Space Accent (`safeGreen`)**: `#10B981` (Emerald green for safe actions and free storage)
  - **Deep Clean Accent (`deepAmber`)**: `#F59E0B` (Warm amber for Deep System Data cleaning)
  - **Danger / Delete (`dangerRed`)**: `#EF4444`
  - **Text Hierarchy**: Primary `#F3F4F6`, Secondary `#9CA3AF`, Muted/Monospace `#6B7280`
- **Typography**:
  - UI & Headings: `SF Pro Display` / `Inter` (`-apple-system, BlinkMacSystemFont, sans-serif`), tight tracking, clear weight contrast.
  - Paths, Sizes & Telemetry: `SF Mono` / `JetBrains Mono` with `tabular-nums` so byte counters animate smoothly without jitter.
- **Real-Time Feedback & Auto-Dismissing Notifications**:
  - **Inline Progress Bar**: During any scan or cleanup, show the active file path and live byte counter in real time.
  - **Auto-Dismissing Toast (4 seconds)**: Floating bottom-right notification with a visual countdown progress bar and a `+X MB/GB Liberados` badge that automatically disappears after 4 seconds.
  - **Live Free Space Reflection**: Every cleanup immediately adds the exact freed bytes to the Free Space counter (`max(osReportedFree, baselineFree + sessionFreedBytes)`) and shows a green pill `+X GB recuperados en esta sesión`.
