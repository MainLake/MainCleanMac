import Foundation
import SwiftUI

enum NavigationTab: String, CaseIterable, Identifiable {
    case dashboard = "Pulso Raman"
    case smartCaches = "Barrido Láser"
    case uninstaller = "Aplicaciones"
    case appleSilicon = "Núcleo Chip M"
    case spaceLens = "Espectro Disco"

    var id: String { rawValue }

    var tagline: String {
        switch self {
        case .dashboard: return "ESTADO GENERAL Y SALUD"
        case .smartCaches: return "PURGA DE CACHÉS Y BASURA"
        case .uninstaller: return "APPS Y RESIDUOS HUÉRFANOS"
        case .appleSilicon: return "BINARIOS ARM64, DOCKER Y CÓDIGO"
        case .spaceLens: return "RAYOS X Y MAPA DE CARPETAS"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: return "waveform.path.ecg"
        case .smartCaches: return "laser.burst"
        case .uninstaller: return "square.stack.3d.up.fill"
        case .appleSilicon: return "cpu.fill"
        case .spaceLens: return "prism.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .dashboard: return RamanTheme.laserCyan
        case .smartCaches: return RamanTheme.stokesAmber
        case .uninstaller: return Color(red: 0.96, green: 0.36, blue: 0.62)
        case .appleSilicon: return RamanTheme.emeraldSafe
        case .spaceLens: return RamanTheme.antiStokesViolet
        }
    }
}

enum SafetyLevel: String, CaseIterable {
    case safe = "Seguro"
    case caution = "Revisar"
    case protected = "Protegido"

    var color: Color {
        switch self {
        case .safe: return .green
        case .caution: return .orange
        case .protected: return .red
        }
    }

    var icon: String {
        switch self {
        case .safe: return "checkmark.shield.fill"
        case .caution: return "exclamationmark.triangle.fill"
        case .protected: return "lock.shield.fill"
        }
    }

    var explanation: String {
        switch self {
        case .safe:
            return "Archivos temporales regenerables sin pérdida de datos."
        case .caution:
            return "Revisa antes de limpiar (puede requerir volver a descargar paquetes o vaciar Papelera)."
        case .protected:
            return "Ruta crítica del sistema o datos personales protegidos."
        }
    }
}

enum LogLevel {
    case info
    case success
    case warning
    case error

    var color: Color {
        switch self {
        case .info: return .cyan
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        }
    }

    var icon: String {
        switch self {
        case .info: return "arrow.right.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        }
    }
}

struct ActivityLogEntry: Identifiable, Hashable {
    let id = UUID()
    let timestamp: Date
    let message: String
    let detail: String?
    let level: LogLevel

    var timeString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm:ss"
        return fmt.string(from: timestamp)
    }
}

struct DiskOverview {
    var totalBytes: Int64 = 0
    var freeBytes: Int64 = 0
    var usedBytes: Int64 { max(0, totalBytes - freeBytes) }
    var usedPercentage: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes)
    }
}

enum CacheCategory: String, CaseIterable {
    case systemAndGeneral = "Sistema y Descargas"
    case browsersAndApps = "Navegadores y Multimedia"
    case packageManagers = "Gestores de Paquetes"
    case aiAndDevTools = "Herramientas IA y Testing"
    case xcodeAndSimulators = "Xcode y Compiladores"

    var icon: String {
        switch self {
        case .systemAndGeneral: return "macwindow"
        case .browsersAndApps: return "globe"
        case .packageManagers: return "shippingbox.fill"
        case .aiAndDevTools: return "cpu.fill"
        case .xcodeAndSimulators: return "hammer.fill"
        }
    }

    var color: Color {
        switch self {
        case .systemAndGeneral: return .mint
        case .browsersAndApps: return .blue
        case .packageManagers: return .orange
        case .aiAndDevTools: return .purple
        case .xcodeAndSimulators: return .cyan
        }
    }
}

struct CleanableItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let description: String
    let impactNote: String
    let path: String
    let category: CacheCategory
    let safety: SafetyLevel
    var sizeBytes: Int64
    var isSelected: Bool
    var useTrashInsteadOfPermanentDelete: Bool = true
    var customCleanCommand: String? = nil
}

struct SmartRecommendation: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let reason: String
    let actionLabel: String
    let potentialSavingsBytes: Int64
    let safety: SafetyLevel
    let targetTab: NavigationTab
    let icon: String
}

struct AppLeftoverFile: Identifiable, Hashable {
    let id = UUID()
    let path: String
    let kind: String
    let sizeBytes: Int64
}

struct InstalledAppInfo: Identifiable, Hashable {
    var id: String { bundlePath }
    let name: String
    let bundleId: String
    let bundlePath: String
    let appSizeBytes: Int64
    let leftovers: [AppLeftoverFile]
    let lastUsedDate: Date?
    let isSystemOrProtected: Bool
    let requiresAdminToTrash: Bool

    var totalSizeBytes: Int64 {
        appSizeBytes + leftovers.reduce(0) { $0 + $1.sizeBytes }
    }

    var leftoversSizeBytes: Int64 {
        leftovers.reduce(0) { $0 + $1.sizeBytes }
    }
}

struct OrphanedLeftoverItem: Identifiable, Hashable {
    var id: String { path }
    let name: String
    let path: String
    let locationType: String
    let sizeBytes: Int64
    var isSelected: Bool = true
}

struct ProjectArtifactItem: Identifiable, Hashable {
    var id: String { path }
    let projectName: String
    let artifactType: String
    let path: String
    let sizeBytes: Int64
    let lastModified: Date?
    var isSelected: Bool = true

    var daysSinceModified: Int {
        guard let lastModified else { return 0 }
        return max(0, Calendar.current.dateComponents([.day], from: lastModified, to: Date()).day ?? 0)
    }
}

struct DockerContainerItem: Identifiable, Hashable {
    let id: String
    let name: String
    let image: String
    let status: String
    let state: String
    var isRunning: Bool { state.lowercased() == "running" }
}

struct DockerVolumeItem: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let driver: String
}

struct DockerImageItem: Identifiable, Hashable {
    let id: String
    let repository: String
    let tag: String
    let size: String
}

struct DockerStatsSummary {
    var imagesSize: String = "0B"
    var imagesReclaimable: String = "0B"
    var containersSize: String = "0B"
    var volumesSize: String = "0B"
    var buildCacheSize: String = "0B"
    var isDockerRunning: Bool = false
}

struct SpaceEntry: Identifiable, Hashable {
    var id: String { path }
    let name: String
    let path: String
    let sizeBytes: Int64
    let isDirectory: Bool
    let safety: SafetyLevel
    let protectionReason: String?
    var relativeWeight: Double = 0.0
}

enum ScheduleFrequency: String, CaseIterable, Identifiable {
    case daily = "Diario"
    case weekly = "Semanal"
    case monthly = "Mensual"

    var id: String { rawValue }
}

enum SurgicalCategory: String, CaseIterable {
    case appSupportSurgery = "Cirugía en Application Support (Sin perder sesiones)"
    case orphanedAppsData = "Datos de Apps Ya Desinstaladas (Fantasmas)"
    case duplicateRuntimes = "Versiones Duplicadas de Node / Python / Herramientas"
    case macOSWallpaperAndMedia = "Videos 4K y Fondos Ocultos de macOS"
    case hiddenDotfileBloat = "Cachés en Carpetas Ocultas (~/.claude, ~/.local, ~/.npm)"

    var icon: String {
        switch self {
        case .appSupportSurgery: return "scissors"
        case .orphanedAppsData: return "Theatermasks.fill"
        case .duplicateRuntimes: return "square.stack.3d.up.badge.a.fill"
        case .macOSWallpaperAndMedia: return "film.stack.fill"
        case .hiddenDotfileBloat: return "eye.trianglebadge.exclamationmark.fill"
        }
    }

    var color: Color {
        switch self {
        case .appSupportSurgery: return RamanTheme.laserCyan
        case .orphanedAppsData: return RamanTheme.stokesAmber
        case .duplicateRuntimes: return RamanTheme.antiStokesViolet
        case .macOSWallpaperAndMedia: return .pink
        case .hiddenDotfileBloat: return RamanTheme.emeraldSafe
        }
    }
}

struct SurgicalPurgeItem: Identifiable, Hashable {
    var id: String { path }
    let title: String
    let parentAppOrContext: String
    let whatIsPreserved: String
    let path: String
    let category: SurgicalCategory
    let sizeBytes: Int64
    let safety: SafetyLevel
    var isSelected: Bool = true
}

enum SafetyGuard {
    static let protectedExactOrPrefixPaths: [(prefix: String, reason: String)] = [
        ("/System", "Sistema operativo macOS protegido por SIP."),
        ("/bin", "Binarios esenciales del sistema."),
        ("/sbin", "Binarios de administración del sistema."),
        ("/usr/bin", "Herramientas base del sistema."),
        ("/usr/lib", "Librerías críticas de ejecución."),
        ("/private/var/db", "Bases de datos internas de macOS."),
        ("/Library/Extensions", "Extensiones del sistema."),
        ("/Applications/Safari.app", "Aplicación nativa de macOS.")
    ]

    static func evaluate(path: String, home: String) -> (SafetyLevel, String?) {
        // Structural root containers cannot be deleted as a whole, but their children CAN be inspected and deleted!
        let structuralRoots: Set<String> = [
            "/", "/Users", "/Applications", "/Library",
            home,
            "\(home)/Library",
            "\(home)/Library/Application Support",
            "\(home)/Library/Containers",
            "\(home)/Library/Caches",
            "\(home)/Documents",
            "\(home)/Desktop",
            "\(home)/Downloads"
        ]
        if structuralRoots.contains(path) {
            return (.protected, "Carpeta estructural raíz. Haz clic en ella para abrirla y eliminar subcarpetas específicas.")
        }

        for item in protectedExactOrPrefixPaths {
            if path == item.prefix || path.hasPrefix(item.prefix + "/") {
                return (.protected, item.reason)
            }
        }

        let userCritical: [(subpath: String, reason: String)] = [
            ("\(home)/Library/Keychains", "Llaveros y contraseñas encriptadas de macOS."),
            ("\(home)/.ssh", "Llaves criptográficas privadas SSH."),
            ("\(home)/.gnupg", "Llaves criptográficas privadas GPG."),
            ("\(home)/Pictures/Photos Library.photoslibrary", "Fototeca principal del usuario."),
            ("\(home)/Library/Mail", "Base de datos local de Apple Mail."),
            ("\(home)/Library/Messages", "Historial local de iMessage.")
        ]

        for item in userCritical {
            if path == item.subpath || path.hasPrefix(item.subpath + "/") {
                return (.protected, item.reason)
            }
        }

        // Everything else inside ~/Library/Application Support, ~/Library/Containers, dotfiles, etc. is UNLOCKED so the user can clean it!
        let cautionPaths: [(subpath: String, reason: String)] = [
            ("\(home)/Documents/", "Archivo dentro de Documentos personales."),
            ("\(home)/Desktop/", "Archivo en tu Escritorio."),
            ("\(home)/main/", "Carpeta de tus repositorios de código."),
            ("\(home)/Library/Application Support/", "Datos o caché de aplicación en Application Support."),
            ("\(home)/Library/Containers/", "Contenedor sandboxed de aplicación.")
        ]

        for item in cautionPaths {
            if path.hasPrefix(item.subpath) {
                return (.caution, item.reason)
            }
        }

        return (.safe, nil)
    }
}

enum ByteFormatter {
    static func string(from bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
