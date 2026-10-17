import Foundation
import SwiftUI

enum NavigationSection: String, CaseIterable {
    case general = "PRINCIPAL"
    case advanced = "AVANZADO"
}

enum NavigationTab: String, CaseIterable, Identifiable {
    case dashboard = "Smart Care"
    case appleSilicon = "Motor Chip M"
    case systemDataXRay = "Rayos X Sistema"
    case smartCaches = "Limpieza"
    case uninstaller = "Aplicaciones"
    case spaceLens = "Explorador"
    case devAndDocker = "Zona Dev & Docker"
    case automation = "Automatización"

    var id: String { rawValue }

    var section: NavigationSection {
        switch self {
        case .dashboard, .appleSilicon, .systemDataXRay, .smartCaches, .uninstaller, .spaceLens:
            return .general
        case .devAndDocker, .automation:
            return .advanced
        }
    }

    var icon: String {
        switch self {
        case .dashboard: return "sparkles.rectangle.stack.fill"
        case .appleSilicon: return "cpu.fill"
        case .systemDataXRay: return "waveform.path.ecg.rectangle.fill"
        case .smartCaches: return "paintbrush.pointed.fill"
        case .uninstaller: return "square.grid.2x2.fill"
        case .spaceLens: return "chart.pie.fill"
        case .devAndDocker: return "terminal.fill"
        case .automation: return "clock.badge.checkmark.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .dashboard: return .cyan
        case .appleSilicon: return .mint
        case .systemDataXRay: return .teal
        case .smartCaches: return .purple
        case .uninstaller: return .pink
        case .spaceLens: return .orange
        case .devAndDocker: return .blue
        case .automation: return .green
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

enum SafetyGuard {
    static let protectedExactOrPrefixPaths: [(prefix: String, reason: String)] = [
        ("/System", "Sistema operativo macOS protegido."),
        ("/bin", "Binarios esenciales del sistema."),
        ("/sbin", "Binarios de administración del sistema."),
        ("/usr/bin", "Herramientas base del sistema."),
        ("/usr/lib", "Librerías críticas de ejecución."),
        ("/private/var/db", "Bases de datos internas de macOS."),
        ("/Library/Extensions", "Extensiones del sistema."),
        ("/Applications/Safari.app", "Aplicación nativa de macOS.")
    ]

    static func evaluate(path: String, home: String) -> (SafetyLevel, String?) {
        if path == "/Library" || path == "\(home)/Library" || path == home || path == "/Users" || path == "/Applications" {
            return (.protected, "Carpeta raíz estructural de macOS. Entra en ella para inspeccionar subcarpetas específicas.")
        }

        for item in protectedExactOrPrefixPaths {
            if path == item.prefix || path.hasPrefix(item.prefix + "/") {
                return (.protected, item.reason)
            }
        }

        let userCritical: [(subpath: String, reason: String)] = [
            ("\(home)/Library/Keychains", "Llaveros y contraseñas locales."),
            ("\(home)/.ssh", "Llaves privadas SSH."),
            ("\(home)/.gnupg", "Llaves privadas GPG."),
            ("\(home)/Library/Application Support/MobileSync/Backup", "Respaldos de iPhone/iPad."),
            ("\(home)/Pictures/Photos Library.photoslibrary", "Fototeca principal."),
            ("\(home)/Library/Mail", "Correos electrónicos locales."),
            ("\(home)/Library/Messages", "Historial de iMessage.")
        ]

        for item in userCritical {
            if path == item.subpath || path.hasPrefix(item.subpath + "/") {
                return (.protected, item.reason)
            }
        }

        let cautionPaths: [(subpath: String, reason: String)] = [
            ("\(home)/Documents", "Documentos personales."),
            ("\(home)/Desktop", "Escritorio del usuario."),
            ("\(home)/main", "Proyectos y repositorios de trabajo."),
            ("/Applications", "Usa la pestaña Aplicaciones para desinstalar sin residuos."),
            ("\(home)/Library/Application Support", "Configuración y datos de aplicaciones.")
        ]

        for item in cautionPaths {
            if path == item.subpath || path.hasPrefix(item.subpath + "/") {
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
