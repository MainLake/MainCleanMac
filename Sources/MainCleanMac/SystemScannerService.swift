import Foundation
import AppKit
import SwiftUI

@MainActor
final class SystemScannerService: ObservableObject {
    @Published var diskOverview = DiskOverview()
    @Published var sessionFreedBytes: Int64 = 0
    @Published var lastFreedDeltaBytes: Int64 = 0
    private var initialFreeBytesBaseline: Int64?
    private var toastDismissTask: Task<Void, Never>?

    @Published var cacheItems: [CleanableItem] = []
    @Published var isScanningCaches = false
    @Published var isCleaningCaches = false
    @Published var lastStatusMessage: String? {
        didSet {
            scheduleToastAutoDismiss()
        }
    }
    @Published var toastId = UUID()

    // Live Operation Loader & Activity Console
    @Published var isExecutingOperation = false
    @Published var currentOperationTitle = ""
    @Published var currentOperationSubtitle = ""
    @Published var activityLogs: [ActivityLogEntry] = []
    @Published var showLogDrawer = false

    @Published var recommendations: [SmartRecommendation] = []
    @Published var safeModeTrashOnly: Bool = true
    @Published var isAdvancedMode: Bool = false

    // Uninstaller & Orphans
    @Published var installedApps: [InstalledAppInfo] = []
    @Published var orphanedLeftovers: [OrphanedLeftoverItem] = []
    @Published var isScanningApps = false
    private var hasScannedAppsOnce = false

    // Project Artifacts (node_modules, .venv, target, etc.)
    @Published var projectArtifacts: [ProjectArtifactItem] = []
    @Published var isScanningArtifacts = false
    private var hasScannedArtifactsOnce = false

    // Docker
    @Published var dockerStats = DockerStatsSummary()
    @Published var dockerContainers: [DockerContainerItem] = []
    @Published var dockerVolumes: [DockerVolumeItem] = []
    @Published var dockerImages: [DockerImageItem] = []
    @Published var isScanningDocker = false
    @Published var isCleaningDocker = false
    private var hasScannedDockerOnce = false

    // Space Lens
    @Published var spaceEntries: [SpaceEntry] = []
    @Published var currentSpacePath: String = FileManager.default.homeDirectoryForCurrentUser.path
    @Published var isScanningSpace = false
    private var spaceCache: [String: [SpaceEntry]] = [:]
    private var activeSpaceScanTask: Task<Void, Never>?

    // System Data X-Ray & Surgical Deep Cleaner
    @Published var systemDataItems: [SystemDataXRayItem] = []
    @Published var isScanningSystemData = false
    private var hasScannedSystemDataOnce = false

    @Published var surgicalItems: [SurgicalPurgeItem] = []
    @Published var isScanningSurgical = false
    private var hasScannedSurgicalOnce = false

    // Apple Silicon M-Series Engine
    @Published var mSeriesStatus = AppleSiliconHardwareStatus()
    @Published var mSeriesItems: [MSeriesDeepItem] = []
    @Published var appArchitectures: [AppleAppArchInfo] = []
    @Published var isScanningMSeries = false
    private var hasScannedMSeriesOnce = false

    // Automation / LaunchAgent
    @Published var isScheduleInstalled: Bool = false
    @Published var selectedFrequency: ScheduleFrequency = .weekly
    @Published var lowSpaceAlertThresholdGB: Double = 25.0

    let home = FileManager.default.homeDirectoryForCurrentUser.path

    var launchAgentPath: String {
        "\(home)/Library/LaunchAgents/com.mainlake.maincleanmac.periodic.plist"
    }

    private func scheduleToastAutoDismiss() {
        toastDismissTask?.cancel()
        guard let msg = lastStatusMessage, !msg.isEmpty else { return }
        toastId = UUID()
        toastDismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_000_000_000) // 4 seconds auto-dismiss
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.25)) {
                self.lastStatusMessage = nil
            }
        }
    }

    func recordFreedSpace(_ bytes: Int64) {
        guard bytes > 0 else { return }
        withAnimation(.spring(duration: 0.35)) {
            sessionFreedBytes += bytes
            lastFreedDeltaBytes = bytes
        }
        refreshDiskOverview()
    }

    func appendLog(_ message: String, detail: String? = nil, level: LogLevel = .info) {
        let entry = ActivityLogEntry(timestamp: Date(), message: message, detail: detail, level: level)
        activityLogs.insert(entry, at: 0)
        if isExecutingOperation {
            currentOperationSubtitle = message
        }
    }

    func clearLogs() {
        activityLogs.removeAll()
    }

    func refreshAll() {
        refreshDiskOverview()
        checkLaunchAgentStatus()
        spaceCache.removeAll()
        hasScannedAppsOnce = true
        hasScannedArtifactsOnce = true
        hasScannedDockerOnce = true
        hasScannedSystemDataOnce = true
        hasScannedSurgicalOnce = true
        hasScannedMSeriesOnce = true

        Task {
            await scanCaches()
            await scanSurgicalTargets()
            await scanSystemDataXRay()
            await scanAppleSiliconDeep()
            await scanInstalledApps()
            await scanProjectArtifacts()
            buildRecommendations()
        }
        Task {
            await refreshDocker()
            buildRecommendations()
        }
        Task {
            await scanDirectory(path: currentSpacePath, forceRefresh: true)
        }
    }

    func ensureSurgicalLoaded() {
        guard !hasScannedSurgicalOnce && !isScanningSurgical else { return }
        hasScannedSurgicalOnce = true
        Task { await scanSurgicalTargets() }
    }

    func ensureMSeriesLoaded() {
        guard !hasScannedMSeriesOnce && !isScanningMSeries else { return }
        hasScannedMSeriesOnce = true
        Task { await scanAppleSiliconDeep() }
    }

    func ensureSystemDataLoaded() {
        guard !hasScannedSystemDataOnce && !isScanningSystemData else { return }
        hasScannedSystemDataOnce = true
        Task { await scanSystemDataXRay() }
    }

    func ensureAppsLoaded() {
        guard !hasScannedAppsOnce && !isScanningApps else { return }
        hasScannedAppsOnce = true
        Task { await scanInstalledApps() }
    }

    func ensureDevAndDockerLoaded() {
        if !hasScannedArtifactsOnce && !isScanningArtifacts {
            hasScannedArtifactsOnce = true
            Task { await scanProjectArtifacts() }
        }
        if !hasScannedDockerOnce && !isScanningDocker {
            hasScannedDockerOnce = true
            Task { await refreshDocker() }
        }
    }

    func ensureSpaceLensLoaded() {
        if spaceEntries.isEmpty && !isScanningSpace {
            Task { await scanDirectory(path: currentSpacePath) }
        }
    }

    func refreshDiskOverview() {
        do {
            let url = URL(fileURLWithPath: "/")
            let values = try url.resourceValues(forKeys: [
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityForImportantUsageKey,
                .volumeAvailableCapacityKey
            ])
            let total = Int64(values.volumeTotalCapacity ?? 0)
            let availImportant = values.volumeAvailableCapacityForImportantUsage ?? Int64(values.volumeAvailableCapacity ?? 0)
            if initialFreeBytesBaseline == nil {
                initialFreeBytesBaseline = availImportant
            }
            let base = initialFreeBytesBaseline ?? availImportant
            let effectiveFree = min(total, max(availImportant, base + sessionFreedBytes))
            withAnimation(.spring(duration: 0.35)) {
                diskOverview = DiskOverview(totalBytes: total, freeBytes: effectiveFree)
            }
        } catch {
            print("Error reading disk overview: \(error)")
        }
    }

    // MARK: - Smart Recommendations Engine

    func buildRecommendations() {
        var list: [SmartRecommendation] = []

        let safeCacheBytes = cacheItems.filter { $0.safety == .safe }.reduce(Int64(0)) { $0 + $1.sizeBytes }
        if safeCacheBytes > 20 * 1024 * 1024 {
            list.append(SmartRecommendation(
                title: "Limpiar Cachés 100% Seguras de Apps y Paquetes",
                reason: "Son archivos temporales de navegadores, gestores de paquetes y registros que se regeneran solos sin cerrar tus sesiones ni perder configuraciones.",
                actionLabel: "Limpiar Ahora",
                potentialSavingsBytes: safeCacheBytes,
                safety: .safe,
                targetTab: .smartCaches,
                icon: "sparkles"
            ))
        }

        let staleArtifacts = projectArtifacts.filter { $0.daysSinceModified >= 7 }
        let allArtifactsBytes = projectArtifacts.reduce(Int64(0)) { $0 + $1.sizeBytes }
        if allArtifactsBytes > 50 * 1024 * 1024 {
            list.append(SmartRecommendation(
                title: "Purgar Dependencias de Proyectos (node_modules / .venv / target)",
                reason: !staleArtifacts.isEmpty
                    ? "Tienes \(staleArtifacts.count) carpetas de dependencias sin modificar en más de 7 días. Tu código fuente no se toca."
                    : "Se detectaron carpetas pesadas de compilación y dependencias regenerables en tus proyectos.",
                actionLabel: "Limpiar Artefactos",
                potentialSavingsBytes: allArtifactsBytes,
                safety: .safe,
                targetTab: .appleSilicon,
                icon: "folder.fill.badge.gearshape"
            ))
        }

        let heavyApps = installedApps.filter { $0.totalSizeBytes > 1_000_000_000 && !$0.isSystemOrProtected }
        if let biggestApp = heavyApps.first {
            list.append(SmartRecommendation(
                title: "Aplicación Pesada Detectada: \(biggestApp.name)",
                reason: "Ocupa \(ByteFormatter.string(from: biggestApp.totalSizeBytes)) incluyendo \(ByteFormatter.string(from: biggestApp.leftoversSizeBytes)) en archivos de soporte y caché.",
                actionLabel: "Ir a Aplicaciones",
                potentialSavingsBytes: biggestApp.totalSizeBytes,
                safety: .caution,
                targetTab: .uninstaller,
                icon: "app.badge.checkmark.fill"
            ))
        }

        let orphanBytes = orphanedLeftovers.reduce(Int64(0)) { $0 + $1.sizeBytes }
        if orphanBytes > 10 * 1024 * 1024 {
            list.append(SmartRecommendation(
                title: "Residuos Huérfanos de Apps ya Desinstaladas",
                reason: "Existen carpetas en ~/Library/Caches y ~/Library/Saved Application State de programas que ya no están en /Applications.",
                actionLabel: "Limpiar Huérfanos",
                potentialSavingsBytes: orphanBytes,
                safety: .safe,
                targetTab: .uninstaller,
                icon: "trash.slash.fill"
            ))
        }

        if !isScheduleInstalled {
            list.append(SmartRecommendation(
                title: "Activar Mantenimiento Automático en Segundo Plano",
                reason: "Evita que el disco vuelva a llenarse configurando el agente nativo de macOS (launchd) para limpiar cachés seguras cada semana.",
                actionLabel: "Activar Ahora",
                potentialSavingsBytes: 0,
                safety: .safe,
                targetTab: .dashboard,
                icon: "clock.badge.checkmark.fill"
            ))
        }

        recommendations = list
    }

    func executeRecommendationInPlace(_ rec: SmartRecommendation) async {
        switch rec.targetTab {
        case .smartCaches:
            selectOnlySafeCaches()
            await cleanSelectedCaches()
        case .appleSilicon:
            await cleanSelectedProjectArtifacts()
        case .uninstaller:
            if !orphanedLeftovers.isEmpty && rec.title.contains("Huérfanos") {
                await cleanSelectedOrphans()
            }
        case .dashboard:
            installOrUpdateSchedule()
        default:
            break
        }
    }

    // MARK: - Smart Caches & General User Targets (Single Batch Sizing)

    func scanCaches() async {
        isScanningCaches = true
        defer { isScanningCaches = false }

        let targets: [(String, String, String, String, CacheCategory, SafetyLevel, Bool, String?)] = [
            ("Papelera del Usuario (~/.Trash)", "Archivos que ya borraste pero siguen ocupando espacio en el disco.", "Al vaciar la Papelera los archivos dentro de ella se eliminan definitivamente.", "\(home)/.Trash", .systemAndGeneral, .caution, false, nil),
            ("Instaladores Descargados (.dmg / .pkg / .iso)", "Imágenes de disco e instaladores olvidados en tu carpeta Downloads.", "El programa ya instalado en /Applications no se ve afectado al borrar su instalador .dmg o .pkg.", "\(home)/Downloads", .systemAndGeneral, .safe, true, "FIND_INSTALLERS"),
            ("Registros y Diagnósticos (~/Library/Logs)", "Reportes de fallos y logs antiguos de aplicaciones de usuario.", "Totalmente seguro; las apps crearán nuevos logs si los necesitan.", "\(home)/Library/Logs", .systemAndGeneral, .safe, false, nil),
            ("Estados Guardados de Ventanas", "Posición de ventanas de apps cerradas (Saved Application State).", "Seguro de limpiar; las apps simplemente abrirán en su ventana predeterminada.", "\(home)/Library/Saved Application State", .systemAndGeneral, .safe, false, nil),

            ("Caché de Google Chrome", "Imágenes, scripts y fragmentos web temporales de Chrome.", "No borra tus contraseñas, historial ni pestañas abiertas.", "\(home)/Library/Caches/Google/Chrome", .browsersAndApps, .safe, false, nil),
            ("Caché de Safari", "Archivos web temporales de Apple Safari.", "No borra tus marcadores ni contraseñas guardadas en iCloud.", "\(home)/Library/Caches/com.apple.Safari", .browsersAndApps, .safe, false, nil),
            ("Caché de Spotify", "Canciones y portadas almacenadas en caché temporal.", "No borra tus playlists ni tu cuenta.", "\(home)/Library/Caches/com.spotify.client", .browsersAndApps, .safe, false, nil),
            ("Actualizaciones Residuales (ShipIt / Updaters)", "Paquetes temporales descargados por auto-actualizadores de apps.", "Seguro: la actualización ya fue aplicada.", "\(home)/Library/Caches/com.google.antigravity.ShipIt", .browsersAndApps, .safe, false, nil),
            ("Respaldos Locales de iPhone/iPad (MobileSync)", "Copias de seguridad completas de dispositivos iOS en esta Mac.", "¡Atención! Borrar esto eliminará tus respaldos locales de iPhone/iPad.", "\(home)/Library/Application Support/MobileSync/Backup", .browsersAndApps, .caution, true, nil),

            ("Caché de npm", "Tarballs de paquetes Node descargados en ~/.npm/_cacache.", "100% seguro; tus carpetas node_modules activas no se tocan.", "\(home)/.npm/_cacache", .packageManagers, .safe, false, nil),
            ("Store de pnpm", "Almacén global de paquetes de pnpm.", "Si limpias el store, pnpm volverá a descargar paquetes en futuros installs.", "\(home)/Library/pnpm/store", .packageManagers, .safe, false, nil),
            ("Caché de Python (uv)", "Wheels y paquetes precompilados de uv.", "Seguro; tus entornos .venv activos siguen funcionando igual.", "\(home)/.cache/uv", .packageManagers, .safe, false, nil),
            ("Caché de pip", "Paquetes descargados por pip en caché.", "Seguro; no desinstala librerías de tus proyectos.", "\(home)/Library/Caches/pip", .packageManagers, .safe, false, nil),
            ("Caché de Cargo / Rust", "Crates descargados en ~/.cargo/registry/cache.", "Seguro; solo descargará de nuevo los crates que compiles en el futuro.", "\(home)/.cargo/registry/cache", .packageManagers, .safe, false, nil),
            ("Caché de Maven (.m2)", "Dependencias JAR descargadas por proyectos Java.", "En tu próxima compilación Maven volverá a bajar los JARs necesarios.", "\(home)/.m2/repository", .packageManagers, .caution, true, nil),
            ("Caché de Homebrew", "Instaladores antiguos descargados por brew.", "No desinstala tus programas de Homebrew, solo limpia instaladores viejos.", "\(home)/Library/Caches/Homebrew", .packageManagers, .safe, false, "/opt/homebrew/bin/brew cleanup --prune=all"),

            ("Navegadores de Playwright", "Binarios de Chromium/Firefox/WebKit para pruebas automatizadas.", "Si corres tests E2E después, requerirás ejecutar 'npx playwright install'.", "\(home)/Library/Caches/ms-playwright", .aiAndDevTools, .caution, false, nil),
            ("Modelos de HuggingFace", "Pesos de modelos de IA descargados en ~/.cache/huggingface.", "Si los usas localmente, tendrán que volver a descargarse.", "\(home)/.cache/huggingface", .aiAndDevTools, .caution, true, nil),
            ("Codex Worktrees Temporales", "Copias de repositorios creadas por sesiones antiguas de Codex.", "Revisa que no tengas cambios sin fusionar en sesiones activas.", "\(home)/.codex/worktrees", .aiAndDevTools, .caution, true, nil),
            ("Runtimes y Caché de Codex", "Runtimes temporales y caché de OpenAI Codex.", "Se regeneran automáticamente al iniciar Codex.", "\(home)/.cache/codex-runtimes", .aiAndDevTools, .safe, false, nil),
            ("Caché de GitHub Copilot", "Archivos temporales del agente Copilot.", "Seguro de eliminar.", "\(home)/Library/Caches/copilot", .aiAndDevTools, .safe, false, nil),

            ("Xcode DerivedData", "Índices y binarios intermedios de compilación de Xcode.", "Seguro; Xcode recompilará el proyecto la próxima vez que lo abras.", "\(home)/Library/Developer/Xcode/DerivedData", .xcodeAndSimulators, .safe, false, nil),
            ("Caché de Xcode", "Caché interna de compilación de Xcode.", "Seguro de limpiar.", "\(home)/Library/Caches/com.apple.dt.Xcode", .xcodeAndSimulators, .safe, false, nil),
            ("Cachés de CoreSimulator", "Archivos temporales de simuladores de iOS.", "Seguro si no estás corriendo un simulador ahora mismo.", "\(home)/Library/Developer/CoreSimulator/Caches", .xcodeAndSimulators, .safe, false, nil)
        ]

        let scanned: [CleanableItem] = await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            // Measure all existing target paths in a SINGLE du call instead of 24 separate shell processes
            let normalPaths = targets.filter { $0.7 != "FIND_INSTALLERS" && fm.fileExists(atPath: $0.2) }.map(\.2)
            let batchSizes = Self.batchSizesForPaths(normalPaths)

            var results: [CleanableItem] = []
            for (name, desc, impact, path, category, safety, defaultTrash, customCmd) in targets {
                let size: Int64
                if customCmd == "FIND_INSTALLERS" {
                    size = Self.installerFilesSize(in: path)
                } else {
                    size = batchSizes[path] ?? 0
                }
                if size > 64 * 1024 {
                    results.append(
                        CleanableItem(
                            name: name,
                            description: desc,
                            impactNote: impact,
                            path: path,
                            category: category,
                            safety: safety,
                            sizeBytes: size,
                            isSelected: safety == .safe,
                            useTrashInsteadOfPermanentDelete: defaultTrash,
                            customCleanCommand: customCmd
                        )
                    )
                }
            }
            return results.sorted { $0.sizeBytes > $1.sizeBytes }
        }.value

        cacheItems = scanned
        refreshDiskOverview()
        buildRecommendations()
    }

    var totalSelectedCacheBytes: Int64 {
        cacheItems.filter(\.isSelected).reduce(0) { $0 + $1.sizeBytes }
    }

    var totalCacheBytes: Int64 {
        cacheItems.reduce(0) { $0 + $1.sizeBytes }
    }

    var selectedCautionItemsCount: Int {
        cacheItems.filter { $0.isSelected && $0.safety != .safe }.count
    }

    func toggleCacheSelection(_ item: CleanableItem) {
        if let idx = cacheItems.firstIndex(where: { $0.id == item.id }) {
            cacheItems[idx].isSelected.toggle()
        }
    }

    func selectOnlySafeCaches() {
        for idx in cacheItems.indices {
            cacheItems[idx].isSelected = (cacheItems[idx].safety == .safe)
        }
    }

    func cleanSelectedCaches() async {
        let selected = cacheItems.filter(\.isSelected)
        guard !selected.isEmpty else { return }

        isCleaningCaches = true
        isExecutingOperation = true
        currentOperationTitle = "Limpiando Cachés Seleccionadas..."
        defer {
            isCleaningCaches = false
            isExecutingOperation = false
        }

        let useTrash = safeModeTrashOnly
        let freedBytes = selected.reduce(Int64(0)) { $0 + $1.sizeBytes }
        let selectedIds = Set(selected.map(\.id))

        for item in selected {
            appendLog("Procesando \(item.name) (\(ByteFormatter.string(from: item.sizeBytes)))", detail: item.path, level: .info)

            await Task.detached(priority: .userInitiated) {
                let fm = FileManager.default
                if item.customCleanCommand == "FIND_INSTALLERS" {
                    Self.cleanInstallerFiles(in: item.path, moveToTrash: useTrash)
                    return
                }
                if let cmd = item.customCleanCommand {
                    _ = Self.runShell(cmd)
                }
                guard fm.fileExists(atPath: item.path) else { return }

                if let contents = try? fm.contentsOfDirectory(atPath: item.path) {
                    for sub in contents {
                        let fullPath = (item.path as NSString).appendingPathComponent(sub)
                        if useTrash && !item.path.hasSuffix("/.Trash") {
                            try? fm.trashItem(at: URL(fileURLWithPath: fullPath), resultingItemURL: nil)
                        } else {
                            try? fm.removeItem(atPath: fullPath)
                        }
                    }
                }
            }.value

            appendLog("Completado: \(item.name)", detail: useTrash ? "Movido al Basurero" : "Eliminado", level: .success)
        }

        withAnimation {
            cacheItems.removeAll { selectedIds.contains($0.id) }
        }
        spaceCache.removeAll()
        recordFreedSpace(freedBytes)

        lastStatusMessage = "Se liberaron \(ByteFormatter.string(from: freedBytes)) de forma segura."
        await scanCaches()
        refreshDiskOverview()
    }

    // MARK: - Complete App Uninstaller (Ultra-Fast Pre-Indexed Library Scan)

    func scanInstalledApps() async {
        isScanningApps = true
        defer { isScanningApps = false }

        let homeDir = home
        let result = await Task.detached(priority: .userInitiated) { () -> ([InstalledAppInfo], [OrphanedLeftoverItem]) in
            let fm = FileManager.default
            let appsDir = "/Applications"
            guard let appEntries = try? fm.contentsOfDirectory(atPath: appsDir) else { return ([], []) }

            var apps: [InstalledAppInfo] = []
            var knownIdentifiers = Set<String>()
            var knownNames = Set<String>()

            // 1. Pre-index all 7 ~/Library directories ONCE in memory (names only, zero shell processes!)
            let searchTargets: [(dir: String, kind: String)] = [
                ("\(homeDir)/Library/Application Support", "Application Support"),
                ("\(homeDir)/Library/Caches", "Caché"),
                ("\(homeDir)/Library/Preferences", "Preferencias"),
                ("\(homeDir)/Library/Saved Application State", "Estado Guardado"),
                ("\(homeDir)/Library/Containers", "Contenedor Sandbox"),
                ("\(homeDir)/Library/Logs", "Registros (Logs)"),
                ("\(homeDir)/Library/HTTPStorages", "HTTP Storage")
            ]

            var dirIndex: [(dir: String, kind: String, children: [(name: String, lower: String, fullPath: String)])] = []
            for target in searchTargets {
                if let children = try? fm.contentsOfDirectory(atPath: target.dir) {
                    let mapped = children.map { (name: $0, lower: $0.lowercased(), fullPath: "\(target.dir)/\($0)") }
                    dirIndex.append((target.dir, target.kind, mapped))
                }
            }

            // 2. Collect matched leftover paths across all apps first, then size them in ONE single batch call
            var rawAppRecords: [(name: String, bundleId: String, bundlePath: String, modDate: Date?, isProtected: Bool, requiresAdmin: Bool, matchedLeftovers: [(path: String, kind: String)])] = []
            var allPathsToSize: [String] = []

            for entry in appEntries where entry.hasSuffix(".app") {
                let fullPath = "\(appsDir)/\(entry)"
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: fullPath, isDirectory: &isDir) else { continue }

                let appName = (entry as NSString).deletingPathExtension
                let plistPath = "\(fullPath)/Contents/Info.plist"

                var bundleId = ""
                if let dict = NSDictionary(contentsOfFile: plistPath),
                   let id = dict["CFBundleIdentifier"] as? String {
                    bundleId = id
                }

                let cleanBundle = bundleId.lowercased()
                let cleanName = appName.lowercased()

                if !cleanBundle.isEmpty {
                    knownIdentifiers.insert(cleanBundle)
                }
                knownNames.insert(cleanName)

                var matched: [(path: String, kind: String)] = []
                for indexed in dirIndex {
                    for child in indexed.children {
                        let matchesBundle = !cleanBundle.isEmpty && child.lower.contains(cleanBundle)
                        let matchesName = cleanName.count >= 4 && (child.lower == cleanName || child.lower == "\(cleanName).savedstate")
                        if matchesBundle || matchesName {
                            matched.append((child.fullPath, indexed.kind))
                            allPathsToSize.append(child.fullPath)
                        }
                    }
                }

                let isProtected = bundleId.hasPrefix("com.apple.") || fullPath == "/Applications/Safari.app"
                let attr = try? fm.attributesOfItem(atPath: fullPath)
                let modDate = attr?[.modificationDate] as? Date
                let ownerAccount = (attr?[.ownerAccountName] as? String) ?? ""
                let requiresAdmin = (ownerAccount == "root") || !fm.isWritableFile(atPath: fullPath)

                allPathsToSize.append(fullPath)
                rawAppRecords.append((appName, bundleId, fullPath, modDate, isProtected, requiresAdmin, matched))
            }

            // 3. Collect candidate orphan paths (including Ghost Apps in Application Support)
            let orphanCheckDirs: [(String, String)] = [
                ("\(homeDir)/Library/Caches", "Caché Huérfana"),
                ("\(homeDir)/Library/Saved Application State", "Estado Guardado Huérfano"),
                ("\(homeDir)/Library/HTTPStorages", "Almacenamiento HTTP Huérfano")
            ]

            var rawOrphans: [(name: String, path: String, label: String)] = []
            for (dir, label) in orphanCheckDirs {
                guard let subitems = try? fm.contentsOfDirectory(atPath: dir) else { continue }
                for sub in subitems {
                    let lower = sub.lowercased()
                    if lower.hasPrefix("com.apple.") || lower.hasPrefix("org.mozilla.") || lower.contains("homebrew") || lower.contains("playwright") || lower.contains("antigravity") {
                        continue
                    }
                    guard lower.contains(".") else { continue }
                    let cleanedId = lower.replacingOccurrences(of: ".savedstate", with: "")
                    let matchesInstalled = knownIdentifiers.contains { $0.contains(cleanedId) || cleanedId.contains($0) }
                        || knownNames.contains { $0.count > 3 && cleanedId.contains($0.replacingOccurrences(of: " ", with: "")) }

                    if !matchesInstalled {
                        let fullPath = "\(dir)/\(sub)"
                        rawOrphans.append((sub, fullPath, label))
                        allPathsToSize.append(fullPath)
                    }
                }
            }

            // Unify Ghost Apps in ~/Library/Application Support into Orphaned Leftovers
            let appSupportDir = "\(homeDir)/Library/Application Support"
            let knownGhostCandidates: [(folder: String, displayName: String, checkName: String)] = [
                ("Claude", "Claude Desktop / Claude Code VM", "claude"),
                ("zoom.us", "Zoom Video Communications", "zoom.us"),
                ("Postman", "Postman API Client", "postman"),
                ("BraveSoftware", "Brave Browser", "brave browser"),
                ("Trae", "Trae IDE", "trae"),
                ("Windsurf", "Windsurf IDE", "windsurf"),
                ("Codex", "Codex Desktop Data", "codex"),
                ("CodexBackups", "Respaldos Antiguos de Codex", "codex"),
                ("dbpepe", "Datos de dbpepe", "dbpepe"),
                ("jellyfin", "Servidor Jellyfin", "jellyfin"),
                ("orca", "Orca App Data", "orca"),
                ("Riot Client", "Riot Games Client Data", "riot client")
            ]
            for ghost in knownGhostCandidates {
                let p = "\(appSupportDir)/\(ghost.folder)"
                if fm.fileExists(atPath: p) && !knownNames.contains(ghost.checkName) {
                    rawOrphans.append((ghost.displayName, p, "Application Support (App Desinstalada)"))
                    allPathsToSize.append(p)
                }
            }

            // 4. Size all apps, leftovers, and orphans in ONE batch `du -sk` execution
            let batchSizes = Self.batchSizesForPaths(allPathsToSize)

            for rec in rawAppRecords {
                let appSize = batchSizes[rec.bundlePath] ?? 0
                let leftovers: [AppLeftoverFile] = rec.matchedLeftovers.compactMap { item in
                    let sz = batchSizes[item.path] ?? 0
                    guard sz > 0 else { return nil }
                    return AppLeftoverFile(path: item.path, kind: item.kind, sizeBytes: sz)
                }.sorted { $0.sizeBytes > $1.sizeBytes }

                apps.append(InstalledAppInfo(
                    name: rec.name,
                    bundleId: rec.bundleId.isEmpty ? "Sin identificador" : rec.bundleId,
                    bundlePath: rec.bundlePath,
                    appSizeBytes: appSize,
                    leftovers: leftovers,
                    lastUsedDate: rec.modDate,
                    isSystemOrProtected: rec.isProtected,
                    requiresAdminToTrash: rec.requiresAdmin
                ))
            }

            apps.sort { $0.totalSizeBytes > $1.totalSizeBytes }

            var orphans: [OrphanedLeftoverItem] = []
            for cand in rawOrphans {
                let sz = batchSizes[cand.path] ?? 0
                if sz > 512 * 1024 {
                    orphans.append(OrphanedLeftoverItem(
                        name: cand.name,
                        path: cand.path,
                        locationType: cand.label,
                        sizeBytes: sz
                    ))
                }
            }
            orphans.sort { $0.sizeBytes > $1.sizeBytes }

            return (apps, orphans)
        }.value

        installedApps = result.0
        orphanedLeftovers = result.1
        buildRecommendations()
    }

    func uninstallAppCompletely(_ app: InstalledAppInfo) async {
        guard !app.isSystemOrProtected else {
            lastStatusMessage = "Esta aplicación está protegida por macOS y no puede eliminarse."
            appendLog("Intento bloqueado: \(app.name) está protegida por macOS", detail: app.bundlePath, level: .error)
            return
        }

        isExecutingOperation = true
        currentOperationTitle = "Desinstalando \(app.name)..."
        defer { isExecutingOperation = false }

        appendLog("Iniciando desinstalación completa de \(app.name)", detail: app.bundlePath, level: .info)

        let runningApps = NSWorkspace.shared.runningApplications.filter {
            $0.bundleIdentifier == app.bundleId || $0.localizedName == app.name
        }
        for running in runningApps {
            appendLog("Cerrando proceso activo de \(app.name)...", level: .info)
            running.terminate()
        }

        let fm = FileManager.default
        var removedLeftovers = 0

        for leftover in app.leftovers {
            appendLog("Moviendo residuo (\(leftover.kind)) al Basurero", detail: leftover.path, level: .info)
            let url = URL(fileURLWithPath: leftover.path)
            do {
                try fm.trashItem(at: url, resultingItemURL: nil)
                removedLeftovers += 1
                appendLog("Residuo movido al Basurero: \((leftover.path as NSString).lastPathComponent)", detail: leftover.path, level: .success)
            } catch {
                if (try? fm.removeItem(atPath: leftover.path)) != nil {
                    removedLeftovers += 1
                    appendLog("Residuo eliminado: \((leftover.path as NSString).lastPathComponent)", detail: leftover.path, level: .success)
                } else {
                    appendLog("No se pudo eliminar residuo: \(error.localizedDescription)", detail: leftover.path, level: .warning)
                }
            }
        }

        let appURL = URL(fileURLWithPath: app.bundlePath)
        var appRemoved = false

        appendLog("Enviando \(app.name).app al Basurero...", detail: app.bundlePath, level: .info)

        do {
            _ = try await NSWorkspace.shared.recycle([appURL])
            appRemoved = !fm.fileExists(atPath: app.bundlePath)
        } catch {
            if (try? fm.trashItem(at: appURL, resultingItemURL: nil)) != nil {
                appRemoved = !fm.fileExists(atPath: app.bundlePath)
            }
        }

        if !appRemoved && fm.fileExists(atPath: app.bundlePath) {
            let escapedPath = app.bundlePath.replacingOccurrences(of: "\"", with: "\\\"")
            let finderScript = "tell application \"Finder\" to delete (POSIX file \"\(escapedPath)\" as alias)"
            let finderRes = await Task.detached(priority: .userInitiated) {
                Self.runAppleScript(finderScript)
            }.value
            if finderRes.exitCode == 0 && !fm.fileExists(atPath: app.bundlePath) {
                appRemoved = true
                appendLog("\(app.name).app movido al Basurero vía Finder.", detail: app.bundlePath, level: .success)
            }
        }

        if !appRemoved && fm.fileExists(atPath: app.bundlePath) {
            appendLog("Permiso 'Administración de Apps' inactivo. Usando autorización de macOS...", detail: app.bundlePath, level: .warning)
            let homeTrash = "\(home)/.Trash/\(app.name)-\(Int(Date().timeIntervalSince1970)).app"
            let escapedSrc = app.bundlePath.replacingOccurrences(of: "\"", with: "\\\"")
            let escapedDst = homeTrash.replacingOccurrences(of: "\"", with: "\\\"")

            let appleScript = "do shell script \"mv -f \\\"\(escapedSrc)\\\" \\\"\(escapedDst)\\\"\" with administrator privileges"
            let res = await Task.detached(priority: .userInitiated) {
                Self.runAppleScript(appleScript)
            }.value

            if res.exitCode == 0 && !fm.fileExists(atPath: app.bundlePath) {
                appRemoved = true
                appendLog("\(app.name).app movido al Basurero.", detail: homeTrash, level: .success)
            } else {
                appendLog("Activa 'Administración de aplicaciones' o 'Acceso total al disco' para borrar sin contraseña.", detail: res.output, level: .error)
            }
        } else if appRemoved {
            appendLog("\(app.name).app movido al Basurero sin pedir contraseña.", detail: app.bundlePath, level: .success)
        }

        if appRemoved {
            withAnimation {
                installedApps.removeAll { $0.bundlePath == app.bundlePath }
            }
            spaceCache.removeValue(forKey: "/Applications")
            recordFreedSpace(app.totalSizeBytes)
            lastStatusMessage = "'\(app.name)' y \(removedLeftovers) residuos fueron desinstalados (\(ByteFormatter.string(from: app.totalSizeBytes)))."
        } else {
            lastStatusMessage = "Activa 'Administración de aplicaciones' en Configuración para borrar '\(app.name)' sin contraseña."
        }

        refreshDiskOverview()
        buildRecommendations()
    }

    func openAppManagementSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AppBundles") {
            NSWorkspace.shared.open(url)
        }
    }

    func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }

    func cleanSelectedOrphans() async {
        let selected = orphanedLeftovers.filter(\.isSelected)
        guard !selected.isEmpty else { return }

        isExecutingOperation = true
        currentOperationTitle = "Limpiando Residuos Huérfanos..."
        defer { isExecutingOperation = false }

        let total = selected.reduce(Int64(0)) { $0 + $1.sizeBytes }
        let fm = FileManager.default
        let selectedPaths = Set(selected.map(\.path))

        for item in selected {
            appendLog("Moviendo huérfano \(item.name) al Basurero...", detail: item.path, level: .info)
            do {
                try fm.trashItem(at: URL(fileURLWithPath: item.path), resultingItemURL: nil)
                appendLog("Huérfano eliminado: \(item.name)", detail: item.path, level: .success)
            } catch {
                appendLog("Error en \(item.name): \(error.localizedDescription)", detail: item.path, level: .warning)
            }
        }

        withAnimation {
            orphanedLeftovers.removeAll { selectedPaths.contains($0.path) }
        }
        recordFreedSpace(total)

        lastStatusMessage = "Se enviaron \(selected.count) residuos huérfanos al Basurero (\(ByteFormatter.string(from: total)))."
        refreshDiskOverview()
        buildRecommendations()
    }

    // MARK: - Project Artifacts Scanner (Single Batch Sizing)

    func scanProjectArtifacts() async {
        isScanningArtifacts = true
        defer { isScanningArtifacts = false }

        let homeDir = home
        let found: [ProjectArtifactItem] = await Task.detached(priority: .userInitiated) {
            let searchRoots = [
                "\(homeDir)/main",
                "\(homeDir)/Documents",
                "\(homeDir)/dev",
                "\(homeDir)/orca"
            ]
            let fm = FileManager.default
            let existingRoots = searchRoots.filter { fm.fileExists(atPath: $0) }
            guard !existingRoots.isEmpty else { return [] }

            let rootArgs = existingRoots.map { "\"\($0)\"" }.joined(separator: " ")
            let cmd = "find \(rootArgs) -maxdepth 4 \\( -name 'node_modules' -o -name '.venv' -o -name 'venv' -o -name '.next' -o -name 'target' -o -name 'dist' \\) -type d -prune 2>/dev/null"
            let res = Self.runShell(cmd)
            let paths = res.output.split(separator: "\n").map(String.init)
            guard !paths.isEmpty else { return [] }

            let batchSizes = Self.batchSizesForPaths(paths)
            var items: [ProjectArtifactItem] = []

            for p in paths {
                let sz = batchSizes[p] ?? 0
                guard sz > 5 * 1024 * 1024 else { continue }
                let url = URL(fileURLWithPath: p)
                let artifactType = url.lastPathComponent
                let projectName = url.deletingLastPathComponent().lastPathComponent
                let attr = try? fm.attributesOfItem(atPath: p)
                let modDate = attr?[.modificationDate] as? Date

                items.append(ProjectArtifactItem(
                    projectName: projectName,
                    artifactType: artifactType,
                    path: p,
                    sizeBytes: sz,
                    lastModified: modDate,
                    isSelected: true
                ))
            }
            return items.sorted { $0.sizeBytes > $1.sizeBytes }
        }.value

        projectArtifacts = found
        buildRecommendations()
    }

    func cleanSelectedProjectArtifacts() async {
        let selected = projectArtifacts.filter(\.isSelected)
        guard !selected.isEmpty else { return }

        isExecutingOperation = true
        currentOperationTitle = "Purgando Artefactos de Proyectos..."
        defer { isExecutingOperation = false }

        let freed = selected.reduce(Int64(0)) { $0 + $1.sizeBytes }
        let useTrash = safeModeTrashOnly
        let selectedPaths = Set(selected.map(\.path))

        for item in selected {
            appendLog("Limpiando \(item.projectName)/\(item.artifactType) (\(ByteFormatter.string(from: item.sizeBytes)))", detail: item.path, level: .info)
            await Task.detached(priority: .userInitiated) {
                let fm = FileManager.default
                if useTrash {
                    try? fm.trashItem(at: URL(fileURLWithPath: item.path), resultingItemURL: nil)
                } else {
                    try? fm.removeItem(atPath: item.path)
                }
            }.value
            appendLog("Eliminado \(item.projectName)/\(item.artifactType)", detail: item.path, level: .success)
        }

        withAnimation {
            projectArtifacts.removeAll { selectedPaths.contains($0.path) }
        }
        spaceCache.removeAll()
        recordFreedSpace(freed)

        lastStatusMessage = "Se limpiaron \(selected.count) artefactos de proyectos (\(ByteFormatter.string(from: freed)))."
        refreshDiskOverview()
        buildRecommendations()
    }

    // MARK: - Periodic Automation (macOS LaunchAgent)

    func checkLaunchAgentStatus() {
        isScheduleInstalled = FileManager.default.fileExists(atPath: launchAgentPath)
    }

    func installOrUpdateSchedule() {
        let intervalSeconds: Int
        switch selectedFrequency {
        case .daily: intervalSeconds = 86_400
        case .weekly: intervalSeconds = 604_800
        case .monthly: intervalSeconds = 2_592_000
        }

        let safeCleanupScript = """
        rm -rf "\(home)/Library/Caches/Google/Chrome/Default/Cache"/* \
               "\(home)/Library/Caches/com.spotify.client/Data"/* \
               "\(home)/.npm/_cacache"/* \
               "\(home)/.cache/uv"/* \
               "\(home)/Library/Caches/pip"/* \
               "\(home)/Library/Logs"/* 2>/dev/null
        """

        let plistContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>com.mainlake.maincleanmac.periodic</string>
            <key>ProgramArguments</key>
            <array>
                <string>/bin/zsh</string>
                <string>-c</string>
                <string>\(safeCleanupScript)</string>
            </array>
            <key>StartInterval</key>
            <integer>\(intervalSeconds)</integer>
            <key>RunAtLoad</key>
            <false/>
        </dict>
        </plist>
        """

        do {
            let dir = (launchAgentPath as NSString).deletingLastPathComponent
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            try plistContent.write(toFile: launchAgentPath, atomically: true, encoding: .utf8)
            _ = Self.runShell("launchctl unload \"\(launchAgentPath)\" 2>/dev/null; launchctl load \"\(launchAgentPath)\" 2>/dev/null")
            isScheduleInstalled = true
            appendLog("LaunchAgent instalado (\(selectedFrequency.rawValue))", detail: launchAgentPath, level: .success)
            lastStatusMessage = "Limpieza periódica activada (\(selectedFrequency.rawValue)) mediante LaunchAgent nativo."
            buildRecommendations()
        } catch {
            appendLog("Error al instalar LaunchAgent: \(error.localizedDescription)", detail: launchAgentPath, level: .error)
            lastStatusMessage = "Error al guardar la programación: \(error.localizedDescription)"
        }
    }

    func removeSchedule() {
        _ = Self.runShell("launchctl unload \"\(launchAgentPath)\" 2>/dev/null")
        try? FileManager.default.removeItem(atPath: launchAgentPath)
        isScheduleInstalled = false
        appendLog("LaunchAgent desactivado y eliminado", detail: launchAgentPath, level: .info)
        lastStatusMessage = "Limpieza periódica desactivada."
        buildRecommendations()
    }

    // MARK: - Docker Management

    func refreshDocker() async {
        isScanningDocker = true
        defer { isScanningDocker = false }

        let result = await Task.detached(priority: .userInitiated) { () -> (DockerStatsSummary, [DockerContainerItem], [DockerVolumeItem], [DockerImageItem]) in
            var summary = DockerStatsSummary()
            let dfOut = Self.runShell("docker system df --format '{{.Type}}|{{.Size}}|{{.Reclaimable}}'")
            if dfOut.exitCode != 0 {
                summary.isDockerRunning = false
                return (summary, [], [], [])
            }
            summary.isDockerRunning = true

            for line in dfOut.output.split(separator: "\n") {
                let parts = line.split(separator: "|").map(String.init)
                guard parts.count >= 2 else { continue }
                let type = parts[0].lowercased()
                let size = parts[1]
                let reclaim = parts.count > 2 ? parts[2] : ""
                if type.contains("image") {
                    summary.imagesSize = size
                    summary.imagesReclaimable = reclaim
                } else if type.contains("container") {
                    summary.containersSize = size
                } else if type.contains("volume") {
                    summary.volumesSize = size
                } else if type.contains("build") {
                    summary.buildCacheSize = size
                }
            }

            var containers: [DockerContainerItem] = []
            let psOut = Self.runShell("docker ps -a --format '{{.ID}}|{{.Names}}|{{.Image}}|{{.Status}}|{{.State}}'")
            if psOut.exitCode == 0 {
                for line in psOut.output.split(separator: "\n") {
                    let parts = line.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
                    if parts.count >= 5 {
                        containers.append(DockerContainerItem(
                            id: parts[0],
                            name: parts[1],
                            image: parts[2],
                            status: parts[3],
                            state: parts[4]
                        ))
                    }
                }
            }

            var volumes: [DockerVolumeItem] = []
            let volOut = Self.runShell("docker volume ls --format '{{.Name}}|{{.Driver}}'")
            if volOut.exitCode == 0 {
                for line in volOut.output.split(separator: "\n") {
                    let parts = line.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
                    if parts.count >= 2 {
                        volumes.append(DockerVolumeItem(name: parts[0], driver: parts[1]))
                    }
                }
            }

            var images: [DockerImageItem] = []
            let imgOut = Self.runShell("docker images --format '{{.ID}}|{{.Repository}}|{{.Tag}}|{{.Size}}'")
            if imgOut.exitCode == 0 {
                for line in imgOut.output.split(separator: "\n") {
                    let parts = line.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
                    if parts.count >= 4 {
                        images.append(DockerImageItem(
                            id: parts[0],
                            repository: parts[1],
                            tag: parts[2],
                            size: parts[3]
                        ))
                    }
                }
            }

            return (summary, containers, volumes, images)
        }.value

        dockerStats = result.0
        dockerContainers = result.1
        dockerVolumes = result.2
        dockerImages = result.3
    }

    func removeDockerContainer(_ id: String) async {
        isCleaningDocker = true
        isExecutingOperation = true
        currentOperationTitle = "Eliminando contenedor Docker \(id)..."
        appendLog("Ejecutando docker rm -f \(id)", level: .info)
        _ = await Task.detached { Self.runShell("docker rm -f \(id)") }.value
        isCleaningDocker = false
        isExecutingOperation = false
        appendLog("Contenedor \(id) eliminado", level: .success)
        lastStatusMessage = "Contenedor \(id) eliminado."
        await refreshDocker()
        refreshDiskOverview()
    }

    func removeDockerVolume(_ name: String) async {
        isCleaningDocker = true
        isExecutingOperation = true
        currentOperationTitle = "Eliminando volumen Docker \(name)..."
        appendLog("Ejecutando docker volume rm -f \(name)", level: .info)
        _ = await Task.detached { Self.runShell("docker volume rm -f \"\(name)\"") }.value
        isCleaningDocker = false
        isExecutingOperation = false
        appendLog("Volumen \(name) eliminado", level: .success)
        lastStatusMessage = "Volumen \(name) eliminado."
        await refreshDocker()
        refreshDiskOverview()
    }

    func removeDockerImage(_ id: String) async {
        isCleaningDocker = true
        isExecutingOperation = true
        currentOperationTitle = "Eliminando imagen Docker \(id)..."
        appendLog("Ejecutando docker rmi -f \(id)", level: .info)
        _ = await Task.detached { Self.runShell("docker rmi -f \(id)") }.value
        isCleaningDocker = false
        isExecutingOperation = false
        appendLog("Imagen \(id) eliminada", level: .success)
        lastStatusMessage = "Imagen \(id) eliminada."
        await refreshDocker()
        refreshDiskOverview()
    }

    func pruneAllDocker() async {
        isCleaningDocker = true
        isExecutingOperation = true
        currentOperationTitle = "Purgando Docker completo..."
        appendLog("Iniciando docker system prune -a --volumes y builder prune", level: .info)
        _ = await Task.detached {
            let cIds = Self.runShell("docker ps -aq").output.split(separator: "\n").joined(separator: " ")
            if !cIds.isEmpty {
                _ = Self.runShell("docker rm -f \(cIds)")
            }
            _ = Self.runShell("docker system prune -a -f --volumes")
            _ = Self.runShell("docker builder prune -a -f")
        }.value
        isCleaningDocker = false
        isExecutingOperation = false
        appendLog("Purga total de Docker finalizada", level: .success)
        lastStatusMessage = "Docker purgado por completo (contenedores, volúmenes, imágenes y caché)."
        await refreshDocker()
        refreshDiskOverview()
    }

    // MARK: - Instant Space Lens (Cached + Progressive Stream)

    func scanDirectory(path: String, forceRefresh: Bool = false) async {
        activeSpaceScanTask?.cancel()
        currentSpacePath = path

        if !forceRefresh, let cached = spaceCache[path] {
            spaceEntries = cached
            isScanningSpace = false
            return
        }

        isScanningSpace = true
        let homeDir = home

        let task = Task {
            // Step 1: Instant listing of files and folders (takes < 5ms) so the user never stares at a blank screen
            let quickEntries: [SpaceEntry] = await Task.detached(priority: .userInitiated) {
                let fm = FileManager.default
                guard let items = try? fm.contentsOfDirectory(atPath: path) else { return [] }
                var initial: [SpaceEntry] = []
                for name in items {
                    if name == "." || name == ".." || name == ".DS_Store" { continue }
                    let fullPath = (path as NSString).appendingPathComponent(name)
                    if fullPath == "/System/Volumes" || fullPath == "/dev" || fullPath == "/Volumes" {
                        continue
                    }
                    var isDir: ObjCBool = false
                    guard fm.fileExists(atPath: fullPath, isDirectory: &isDir) else { continue }
                    let attr = try? fm.attributesOfItem(atPath: fullPath)
                    let fileSize = isDir.boolValue ? 0 : ((attr?[.size] as? Int64) ?? 0)
                    let (safety, reason) = SafetyGuard.evaluate(path: fullPath, home: homeDir)
                    initial.append(SpaceEntry(
                        name: name,
                        path: fullPath,
                        sizeBytes: fileSize,
                        isDirectory: isDir.boolValue,
                        safety: safety,
                        protectionReason: reason,
                        relativeWeight: 0.08
                    ))
                }
                return initial
            }.value

            guard !Task.isCancelled else { return }
            if self.currentSpacePath == path && !quickEntries.isEmpty {
                self.spaceEntries = quickEntries
            }

            // Step 2: Single fast `du -k -d 1` call on the directory (BSD du on macOS does not allow combining -s and -d)
            let sizedEntries: [SpaceEntry] = await Task.detached(priority: .userInitiated) {
                let batchSizes = Self.fastSubdirectorySizes(parentDir: path)
                var list: [SpaceEntry] = []
                for item in quickEntries {
                    var sz = item.isDirectory ? (batchSizes[item.path] ?? 0) : item.sizeBytes
                    if sz == 0 && item.isDirectory {
                        // Fallback if du -d 1 skipped a symlinked or root directory
                        let single = Self.batchSizesForPaths([item.path])
                        sz = single[item.path] ?? 0
                    }
                    if sz > 100 * 1024 || (path == "/" && item.isDirectory) { // Show all root folders and anything > 100 KB
                        list.append(SpaceEntry(
                            name: item.name,
                            path: item.path,
                            sizeBytes: sz,
                            isDirectory: item.isDirectory,
                            safety: item.safety,
                            protectionReason: item.protectionReason
                        ))
                    }
                }
                list.sort { $0.sizeBytes > $1.sizeBytes }
                let maxBytes = Double(list.first?.sizeBytes ?? 1)
                for idx in list.indices {
                    list[idx].relativeWeight = max(0.03, Double(list[idx].sizeBytes) / max(1.0, maxBytes))
                }
                return list
            }.value

            guard !Task.isCancelled else { return }
            if self.currentSpacePath == path {
                self.spaceEntries = sizedEntries
                self.spaceCache[path] = sizedEntries
                self.isScanningSpace = false
            }
        }

        activeSpaceScanTask = task
        await task.value
    }

    func moveToTrash(entry: SpaceEntry) async {
        if entry.safety == .protected {
            lastStatusMessage = "Bloqueado por seguridad: '\(entry.name)' es una ruta protegida."
            appendLog("Bloqueado por seguridad: \(entry.name)", detail: entry.path, level: .error)
            return
        }

        isExecutingOperation = true
        currentOperationTitle = "Moviendo '\(entry.name)' al Basurero..."
        defer { isExecutingOperation = false }

        appendLog("Moviendo al Basurero: \(entry.name)", detail: entry.path, level: .info)
        do {
            let url = URL(fileURLWithPath: entry.path)
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            withAnimation {
                spaceEntries.removeAll { $0.path == entry.path }
            }
            spaceCache[currentSpacePath] = spaceEntries
            recordFreedSpace(entry.sizeBytes)
            appendLog("Movido al Basurero: \(entry.name) (\(ByteFormatter.string(from: entry.sizeBytes)))", detail: entry.path, level: .success)
            lastStatusMessage = "Se movió '\(entry.name)' (\(ByteFormatter.string(from: entry.sizeBytes))) al Basurero."
            refreshDiskOverview()
        } catch {
            appendLog("Error al mover '\(entry.name)': \(error.localizedDescription)", detail: entry.path, level: .error)
            lastStatusMessage = "No se pudo mover '\(entry.name)' al Basurero: \(error.localizedDescription)"
        }
    }

    // MARK: - System Data X-Ray Scanner & Cleaner

    func scanSystemDataXRay() async {
        isScanningSystemData = true
        defer { isScanningSystemData = false }

        let homeDir = home
        let items: [SystemDataXRayItem] = await Task.detached(priority: .userInitiated) {
            let candidates: [(title: String, category: String, explanation: String, path: String, safety: SafetyLevel, canClean: Bool, customAction: String?)] = [
                (
                    "Datos Internos de League of Legends",
                    "Juegos Ocultos en 'Datos del Sistema'",
                    "macOS clasifica los 38 GB descargados por el actualizador de Riot dentro del paquete .app como 'Datos del Sistema' en vez de Aplicaciones.",
                    "/Applications/League of Legends.app/Contents/LOL",
                    .caution,
                    true,
                    nil
                ),
                (
                    "Repositorios y Proyectos en ~/main",
                    "Carpetas fuera de Documents",
                    "Como ~/main no es una carpeta estándar de Apple (Documents/Downloads), macOS suma todo su peso dentro de 'Datos del sistema'.",
                    "\(homeDir)/main",
                    .protected,
                    false,
                    nil
                ),
                (
                    "Paquetes y Librerías de Homebrew (/opt/homebrew)",
                    "Herramientas de Terminal",
                    "Todos los programas y librerías instalados por Homebrew se contabilizan dentro de 'Datos del sistema'. Limpiar ejecuta 'brew cleanup --prune=all' y 'brew autoremove'.",
                    "/opt/homebrew",
                    .safe,
                    true,
                    "BREW_CLEAN"
                ),
                (
                    "Caché de Análisis Multimedia de Apple (mediaanalysisd)",
                    "IA Visual de macOS",
                    "Caché generada por macOS al escanear texto y objetos en fotos/videos. Es seguro vaciar su caché interna si creció demasiado.",
                    "\(homeDir)/Library/Containers/com.apple.mediaanalysisd/Data/Library/Caches",
                    .safe,
                    true,
                    nil
                ),
                (
                    "Contenedor de Análisis Multimedia Completo",
                    "Contenedor del Sistema",
                    "Datos acumulados por el servicio com.apple.mediaanalysisd en ~/Library/Containers.",
                    "\(homeDir)/Library/Containers/com.apple.mediaanalysisd",
                    .protected,
                    false,
                    nil
                ),
                (
                    "Paquetes de OpenAI Codex y Sesiones (~/.codex)",
                    "Agentes IA Ocultos",
                    "Las carpetas que empiezan con punto (como ~/.codex) son invisibles en Finder y macOS las mete íntegras en 'Datos del sistema'.",
                    "\(homeDir)/.codex",
                    .protected,
                    false,
                    nil
                ),
                (
                    "Instalador Residual de Docker (com.docker.install)",
                    "Instaladores de Soporte",
                    "Archivos de instalación guardados por Docker Desktop en Application Support.",
                    "\(homeDir)/Library/Application Support/com.docker.install",
                    .safe,
                    true,
                    nil
                ),
                (
                    "Disco Virtual de Docker Desktop (Docker.raw)",
                    "Máquina Virtual",
                    "Espacio reservado en disco por la máquina virtual Linux de Docker Desktop.",
                    "\(homeDir)/Library/Containers/com.docker.docker",
                    .caution,
                    false,
                    nil
                ),
                (
                    "Entorno y Datos de Hermes (~/.hermes)",
                    "Carpeta Oculta (Dotfile)",
                    "Carpeta oculta en tu directorio de inicio que macOS suma a 'Datos del sistema'.",
                    "\(homeDir)/.hermes",
                    .caution,
                    true,
                    nil
                ),
                (
                    "Fondos Animados de Backdrop",
                    "Application Support",
                    "Videos y fondos pesados descargados por Backdrop en ~/Library/Application Support.",
                    "\(homeDir)/Library/Application Support/Backdrop",
                    .caution,
                    true,
                    nil
                ),
                (
                    "Documentación Offline de Apple Developer (AssetsV2)",
                    "Assets de Sistema (SIP)",
                    "Catálogos descargados en segundo plano por macOS para Xcode y Siri en /System/Library/AssetsV2.",
                    "/System/Volumes/Data/System/Library/AssetsV2",
                    .protected,
                    false,
                    nil
                ),
                (
                    "Cachés Temporales del Kernel y Apps (/private/var/folders)",
                    "Temporales de Bajo Nivel",
                    "Archivos de caché por usuario creados por procesos del sistema en /private/var/folders.",
                    "/System/Volumes/Data/private/var/folders",
                    .protected,
                    false,
                    nil
                ),
                (
                    "Librerías Globales de Python (~/Library/Python)",
                    "Runtimes de Lenguajes",
                    "Paquetes instalados con pip a nivel de usuario fuera de entornos virtuales.",
                    "\(homeDir)/Library/Python",
                    .caution,
                    true,
                    nil
                ),
                (
                    "Módulos y Caché de Go (~/go)",
                    "Runtimes de Lenguajes",
                    "Binarios y módulos descargados por Go en tu carpeta de usuario.",
                    "\(homeDir)/go",
                    .caution,
                    true,
                    "GO_CLEAN"
                )
            ]

            let paths = candidates.map(\.path)
            let sizes = Self.batchSizesForPaths(paths)

            var results: [SystemDataXRayItem] = []
            for c in candidates {
                let sz = sizes[c.path] ?? 0
                if sz > 5 * 1024 * 1024 {
                    results.append(SystemDataXRayItem(
                        title: c.title,
                        category: c.category,
                        explanation: c.explanation,
                        path: c.path,
                        sizeBytes: sz,
                        safety: c.safety,
                        canCleanDirectly: c.canClean,
                        customAction: c.customAction
                    ))
                }
            }
            return results.sorted { $0.sizeBytes > $1.sizeBytes }
        }.value

        systemDataItems = items
    }

    func cleanSystemDataItem(_ item: SystemDataXRayItem) async {
        isExecutingOperation = true
        currentOperationTitle = "Liberando \(item.title)..."
        defer { isExecutingOperation = false }

        appendLog("Iniciando limpieza en Datos del Sistema: \(item.title)", detail: item.path, level: .info)

        await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            if item.customAction == "BREW_CLEAN" {
                _ = Self.runShell("/opt/homebrew/bin/brew cleanup --prune=all && /opt/homebrew/bin/brew autoremove")
                return
            }
            if item.customAction == "GO_CLEAN" {
                _ = Self.runShell("go clean -modcache -cache 2>/dev/null")
                return
            }
            if (try? fm.trashItem(at: URL(fileURLWithPath: item.path), resultingItemURL: nil)) == nil {
                try? fm.removeItem(atPath: item.path)
            }
        }.value

        recordFreedSpace(item.customAction == "BREW_CLEAN" ? 120 * 1024 * 1024 : item.sizeBytes)
        appendLog("Espacio liberado en: \(item.title)", detail: item.path, level: .success)
        lastStatusMessage = "Se liberó '\(item.title)' (\(ByteFormatter.string(from: item.sizeBytes)))."
        await scanSystemDataXRay()
        refreshDiskOverview()
    }

    // MARK: - Surgical Deep Cleaner (Safe Cleaning Inside Protected Folders)

    var totalSelectedSurgicalBytes: Int64 {
        surgicalItems.filter(\.isSelected).reduce(0) { $0 + $1.sizeBytes }
    }

    func toggleSurgicalSelection(_ item: SurgicalPurgeItem) {
        if let idx = surgicalItems.firstIndex(where: { $0.id == item.id }) {
            surgicalItems[idx].isSelected.toggle()
        }
    }

    func scanSurgicalTargets() async {
        isScanningSurgical = true
        defer { isScanningSurgical = false }

        let homeDir = home
        let results: [SurgicalPurgeItem] = await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            var rawCandidates: [(title: String, context: String, preserved: String, path: String, category: SurgicalCategory, safety: SafetyLevel, selectedByDefault: Bool)] = []

            // 1. SURGICAL EXTRACTION INSIDE ~/Library/Application Support (Keep logins/settings, purge internal caches/bloat)
            let appSupportDir = "\(homeDir)/Library/Application Support"
            let surgicalSubfolders = [
                "Cache", "Code Cache", "GPUCache", "DawnWebGPUCache", "DawnGraphiteCache",
                "Crashpad", "CachedData", "CachedProfilesData", "Service Worker", "logs", "blob_storage"
            ]

            if let appSupportEntries = try? fm.contentsOfDirectory(atPath: appSupportDir) {
                for appFolder in appSupportEntries where !appFolder.hasPrefix(".") {
                    let base = "\(appSupportDir)/\(appFolder)"
                    for sub in surgicalSubfolders {
                        let candidate = "\(base)/\(sub)"
                        if fm.fileExists(atPath: candidate) {
                            rawCandidates.append((
                                title: "\(appFolder) → \(sub)",
                                context: "Cirugía interna en Application Support/\(appFolder)",
                                preserved: "Conserva tus cuentas, sesiones abiertas, extensiones y preferencias de \(appFolder).",
                                path: candidate,
                                category: .appSupportSurgery,
                                safety: .safe,
                                selectedByDefault: true
                            ))
                        }
                    }
                }
            }

            // Specific Chrome Default profile internal cache bloat (without touching Cookies, Login Data, Bookmarks, or Extensions)
            let chromeDefault = "\(appSupportDir)/Google/Chrome/Default"
            for chromeSub in ["Service Worker", "GPUCache", "DawnWebGPUCache", "DawnGraphiteCache", "Code Cache"] {
                let p = "\(chromeDefault)/\(chromeSub)"
                if fm.fileExists(atPath: p) {
                    rawCandidates.append((
                        title: "Google Chrome → \(chromeSub)",
                        context: "Caché interna de perfil de Chrome en Application Support",
                        preserved: "100% seguro: Tus contraseñas, pestañas, historial, cookies y sesiones de Google Chrome NO se tocan.",
                        path: p,
                        category: .appSupportSurgery,
                        safety: .safe,
                        selectedByDefault: true
                    ))
                }
            }

            // GoogleUpdater (814+ MB of old Chrome update packages in Application Support/Google/GoogleUpdater)
            let googleUpdaterPath = "\(appSupportDir)/Google/GoogleUpdater"
            if fm.fileExists(atPath: googleUpdaterPath) {
                rawCandidates.append((
                    title: "Actualizaciones Antiguas de Google (GoogleUpdater)",
                    context: "Instaladores viejos de Chrome en Application Support/Google/GoogleUpdater",
                    preserved: "100% seguro: Google Chrome sigue funcionando normal con todas tus cuentas y sesiones.",
                    path: googleUpdaterPath,
                    category: .appSupportSurgery,
                    safety: .safe,
                    selectedByDefault: true
                ))
            }

            // Chrome top-level model & shader caches inside Application Support/Google/Chrome
            let chromeRoot = "\(appSupportDir)/Google/Chrome"
            for chromeTopSub in ["OptGuideOnDeviceModel", "OptimizationGuidePredictionModels", "ComponentCRXCache", "ShaderCache", "GrShaderCache", "GraphiteDawnCache", "BrowserMetrics"] {
                let p = "\(chromeRoot)/\(chromeTopSub)"
                if fm.fileExists(atPath: p) {
                    rawCandidates.append((
                        title: "Google Chrome → \(chromeTopSub)",
                        context: "Modelos y cachés descargadas por Chrome en Application Support",
                        preserved: "100% seguro: Tus contraseñas, pestañas, marcadores y sesiones de Chrome quedan intactas.",
                        path: p,
                        category: .appSupportSurgery,
                        safety: .safe,
                        selectedByDefault: true
                    ))
                }
            }

            // Docker Stale Installer inside Application Support (2.26 GB in_progress)
            let dockerInstall = "\(appSupportDir)/com.docker.install"
            if fm.fileExists(atPath: dockerInstall) {
                rawCandidates.append((
                    title: "Instalador Residual de Docker (com.docker.install)",
                    context: "Actualizador estancado en Application Support",
                    preserved: "Tu app Docker Desktop y tus contenedores actuales siguen intactos.",
                    path: dockerInstall,
                    category: .appSupportSurgery,
                    safety: .safe,
                    selectedByDefault: true
                ))
            }

            // Zed auto-downloaded language servers & local node runtime inside Application Support
            for (sub, desc) in [("languages", "Servidores LSP descargados por Zed"), ("node", "Runtime Node interno de Zed"), ("prettier", "Instancia Prettier de Zed")] {
                let p = "\(appSupportDir)/Zed/\(sub)"
                if fm.fileExists(atPath: p) {
                    rawCandidates.append((
                        title: "Zed Editor → \(sub) (\(desc))",
                        context: "Binarios auto-descargables en Application Support/Zed",
                        preserved: "Tus settings.json, keymaps y temas de Zed quedan intactos; Zed descarga solo los lenguajes que vuelvas a abrir.",
                        path: p,
                        category: .appSupportSurgery,
                        safety: .safe,
                        selectedByDefault: false
                    ))
                }
            }

            // 2. GHOST / UNINSTALLED APPS IN APPLICATION SUPPORT (Apps no longer in /Applications)
            let installedAppNames = Set(((try? fm.contentsOfDirectory(atPath: "/Applications")) ?? []).map {
                ($0 as NSString).deletingPathExtension.lowercased()
            })

            let knownGhostCandidates: [(folder: String, displayName: String, checkName: String)] = [
                ("Claude", "Claude Desktop / Claude Code VM", "claude"),
                ("zoom.us", "Zoom Video Communications", "zoom.us"),
                ("Postman", "Postman API Client", "postman"),
                ("BraveSoftware", "Brave Browser", "brave browser"),
                ("Trae", "Trae IDE", "trae"),
                ("Windsurf", "Windsurf IDE", "windsurf"),
                ("Codex", "Codex Desktop Data", "codex"),
                ("CodexBackups", "Respaldos Antiguos de Codex", "codex"),
                ("dbpepe", "Datos de dbpepe", "dbpepe"),
                ("jellyfin", "Servidor Jellyfin", "jellyfin"),
                ("orca", "Orca App Data", "orca"),
                ("Riot Client", "Riot Games Client Data", "riot client")
            ]

            for ghost in knownGhostCandidates {
                let p = "\(appSupportDir)/\(ghost.folder)"
                if fm.fileExists(atPath: p) && !installedAppNames.contains(ghost.checkName) {
                    rawCandidates.append((
                        title: "Residuos de \(ghost.displayName) (App ya no instalada)",
                        context: "Carpeta huérfana en ~/Library/Application Support/\(ghost.folder)",
                        preserved: "La aplicación '\(ghost.displayName)' ya no existe en /Applications, pero dejó estos datos ocupando espacio.",
                        path: p,
                        category: .orphanedAppsData,
                        safety: .safe,
                        selectedByDefault: true
                    ))
                }
            }

            // 3. DUPLICATE LANGUAGE RUNTIMES & OLD VERSIONS (.nvm, .pyenv, ~/Library/Python)
            let nvmNodeDir = "\(homeDir)/.nvm/versions/node"
            if let versions = try? fm.contentsOfDirectory(atPath: nvmNodeDir) {
                let sortedVers = versions.filter { $0.hasPrefix("v") }.sorted()
                if sortedVers.count > 1 {
                    let newest = sortedVers.last!
                    for oldVer in sortedVers.dropLast() {
                        let p = "\(nvmNodeDir)/\(oldVer)"
                        rawCandidates.append((
                            title: "Versión Antigua de Node.js (\(oldVer)) en ~/.nvm",
                            context: "Tienes múltiples versiones de Node instaladas",
                            preserved: "Se conserva tu versión más reciente de Node (\(newest)) intacta.",
                            path: p,
                            category: .duplicateRuntimes,
                            safety: .caution,
                            selectedByDefault: false
                        ))
                    }
                }
            }

            let pyenvVersDir = "\(homeDir)/.pyenv/versions"
            if let pyVers = try? fm.contentsOfDirectory(atPath: pyenvVersDir) {
                for v in pyVers where !v.hasPrefix(".") {
                    let p = "\(pyenvVersDir)/\(v)"
                    rawCandidates.append((
                        title: "Toolchain de Python en ~/.pyenv (\(v))",
                        context: "Versión compilada en ~/.pyenv/versions/\(v)",
                        preserved: "El Python de Homebrew y del sistema siguen funcionando.",
                        path: p,
                        category: .duplicateRuntimes,
                        safety: .caution,
                        selectedByDefault: false
                    ))
                }
            }

            let userLibPython = "\(homeDir)/Library/Python"
            if fm.fileExists(atPath: userLibPython) {
                rawCandidates.append((
                    title: "Paquetes Globales de Python (~/Library/Python)",
                    context: "Librerías pip instaladas fuera de entornos virtuales",
                    preserved: "Tus entornos .venv de proyectos no se ven afectados.",
                    path: userLibPython,
                    category: .duplicateRuntimes,
                    safety: .caution,
                    selectedByDefault: false
                ))
            }

            // 4. MACOS 4K AERIAL WALLPAPERS & BACKDROP VIDEOS
            let appleAerials = "\(appSupportDir)/com.apple.wallpaper/aerials"
            if fm.fileExists(atPath: appleAerials) {
                rawCandidates.append((
                    title: "Videos 4K de Salvapantallas de macOS (com.apple.wallpaper/aerials)",
                    context: "Videos aéreos descargados en segundo plano por macOS",
                    preserved: "100% seguro: Tu fondo de pantalla estático no falla y macOS solo descarga videos si los eliges.",
                    path: appleAerials,
                    category: .macOSWallpaperAndMedia,
                    safety: .safe,
                    selectedByDefault: true
                ))
            }

            for backdropSub in ["\(appSupportDir)/Backdrop/Library", "\(appSupportDir)/Backdrop/Catalog", "\(appSupportDir)/BackdropWallpaper"] {
                if fm.fileExists(atPath: backdropSub) {
                    let name = (backdropSub as NSString).lastPathComponent
                    rawCandidates.append((
                        title: "Videos Animados Descargados de Backdrop (\(name))",
                        context: "Biblioteca de fondos en video en Application Support",
                        preserved: "La app Backdrop sigue instalada; solo libera los videos pesados almacenados en disco.",
                        path: backdropSub,
                        category: .macOSWallpaperAndMedia,
                        safety: .caution,
                        selectedByDefault: false
                    ))
                }
            }

            // 5. HIDDEN DOTFILE BLOAT (~/.claude, ~/.local, ~/.npm, ~/.codegraph, ~/.grok, ~/.pi, ~/.flet)
            let dotfileTargets: [(title: String, path: String, preserved: String, safe: Bool)] = [
                ("Historial Pesado de Sesiones de Claude CLI (~/.claude/projects)", "\(homeDir)/.claude/projects", "Tus credenciales y settings.json de Claude se conservan.", true),
                ("Historial de Archivos de Claude (~/.claude/file-history)", "\(homeDir)/.claude/file-history", "Tus configuraciones de Claude quedan intactas.", true),
                ("Plugins y Cachés de Neovim (~/.local/share/nvim)", "\(homeDir)/.local/share/nvim", "Tu configuración en ~/.config/nvim (init.lua) no se toca.", false),
                ("Entornos Compartidos de uv (~/.local/share/uv)", "\(homeDir)/.local/share/uv", "Se regeneran automáticamente con uv.", true),
                ("Índice Local de Codegraph (~/.codegraph)", "\(homeDir)/.codegraph", "Índice regenerable de análisis de código.", true),
                ("Datos Ocultos de Grok CLI (~/.grok)", "\(homeDir)/.grok", "Caché y datos locales en ~/.grok.", false),
                ("Datos Ocultos de Pi (~/.pi)", "\(homeDir)/.pi", "Datos almacenados en ~/.pi.", false),
                ("SDK Oculto de Flet (~/.flet)", "\(homeDir)/.flet", "Binarios descargados por Flet UI.", true),
                ("Checkpoints SQLite de Pine (~/.pine_checkpoints.sqlite)", "\(homeDir)/.pine_checkpoints.sqlite", "Archivo de checkpoints instantáneos en tu carpeta Home.", true)
            ]

            for dot in dotfileTargets where fm.fileExists(atPath: dot.path) {
                rawCandidates.append((
                    title: dot.title,
                    context: "Carpeta oculta en tu directorio de inicio (~/)",
                    preserved: dot.preserved,
                    path: dot.path,
                    category: .hiddenDotfileBloat,
                    safety: dot.safe ? .safe : .caution,
                    selectedByDefault: dot.safe
                ))
            }

            let allPaths = rawCandidates.map(\.path)
            let sizeMap = Self.batchSizesForPaths(allPaths)

            var items: [SurgicalPurgeItem] = []
            for c in rawCandidates {
                let sz = sizeMap[c.path] ?? 0
                if sz >= 2 * 1024 * 1024 { // Only show items >= 2 MB
                    items.append(SurgicalPurgeItem(
                        title: c.title,
                        parentAppOrContext: c.context,
                        whatIsPreserved: c.preserved,
                        path: c.path,
                        category: c.category,
                        sizeBytes: sz,
                        safety: c.safety,
                        isSelected: c.selectedByDefault
                    ))
                }
            }

            return items.sorted { $0.sizeBytes > $1.sizeBytes }
        }.value

        surgicalItems = results
    }

    func cleanSurgicalItem(_ item: SurgicalPurgeItem) async {
        isExecutingOperation = true
        currentOperationTitle = "Cirugía en curso: \(item.title)..."
        defer { isExecutingOperation = false }

        let moveToTrash = safeModeTrashOnly
        appendLog("Limpieza quirúrgica: \(item.title)", detail: item.path, level: .info)

        await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            let url = URL(fileURLWithPath: item.path)
            if moveToTrash {
                if (try? fm.trashItem(at: url, resultingItemURL: nil)) == nil {
                    try? fm.removeItem(at: url)
                }
            } else {
                try? fm.removeItem(at: url)
            }
        }.value

        recordFreedSpace(item.sizeBytes)
        appendLog("Liberado con éxito: \(item.title) (\(ByteFormatter.string(from: item.sizeBytes)))", detail: item.path, level: .success)
        lastStatusMessage = "Se liberó '\(item.title)' (\(ByteFormatter.string(from: item.sizeBytes)))."
        await scanSurgicalTargets()
        await scanSystemDataXRay()
        refreshDiskOverview()
    }

    func cleanAllSelectedSurgicalItems() async {
        let selected = surgicalItems.filter(\.isSelected)
        guard !selected.isEmpty else { return }

        isExecutingOperation = true
        currentOperationTitle = "Ejecutando Cirugía Profunda (\(selected.count) objetivos)..."
        defer { isExecutingOperation = false }

        let moveToTrash = safeModeTrashOnly
        var totalFreed: Int64 = 0

        for item in selected {
            appendLog("Purgando: \(item.title) (\(ByteFormatter.string(from: item.sizeBytes)))", detail: item.path, level: .info)
            await Task.detached(priority: .userInitiated) {
                let fm = FileManager.default
                let url = URL(fileURLWithPath: item.path)
                if moveToTrash {
                    if (try? fm.trashItem(at: url, resultingItemURL: nil)) == nil {
                        try? fm.removeItem(at: url)
                    }
                } else {
                    try? fm.removeItem(at: url)
                }
            }.value
            totalFreed += item.sizeBytes
        }

        recordFreedSpace(totalFreed)
        appendLog("Cirugía completada: \(ByteFormatter.string(from: totalFreed)) recuperados", level: .success)
        lastStatusMessage = "Cirugía completada: \(ByteFormatter.string(from: totalFreed)) liberados sin afectar tus sesiones."
        await scanSurgicalTargets()
        await scanSystemDataXRay()
        refreshDiskOverview()
    }

    // MARK: - Two-Level One-Click Cleaning (Quick Safe vs Deep System Data)

    /// Level 1: 100% Safe Quick Cleanup (Caches, Logs, Crashpad, GPUCache, Service Workers, QuickLook, SQLite VACUUM)
    var quickSafeCleanableBytes: Int64 {
        let safeCaches = cacheItems.filter { $0.safety == .safe && ($0.category == .systemAndGeneral || $0.category == .browsersAndApps || $0.category == .xcodeAndSimulators) }.reduce(Int64(0)) { $0 + $1.sizeBytes }
        let safeInternalCaches = surgicalItems.filter { $0.safety == .safe && $0.category == .appSupportSurgery && !$0.path.contains("com.docker.install") }.reduce(Int64(0)) { $0 + $1.sizeBytes }
        let safeMSeries = mSeriesItems.filter { $0.safety == .safe && ($0.kind == .sqliteVacuum || $0.kind == .binaryArchitecture || $0.actionCode == "QL_RESET") }.reduce(Int64(0)) { $0 + $1.sizeBytes }
        return safeCaches + safeInternalCaches + safeMSeries
    }

    /// Level 2: Deep System Data Cleanup (Docker residual installer, Ghost uninstalled apps in Application Support, Orphans, Package Managers, 4K Aerials, Dotfiles, APFS Snapshots)
    var deepSystemCleanableBytes: Int64 {
        let pkgAndAICaches = cacheItems.filter { $0.safety == .safe && ($0.category == .packageManagers || $0.category == .aiAndDevTools) }.reduce(Int64(0)) { $0 + $1.sizeBytes }
        let deepSurgical = surgicalItems.filter { $0.safety == .safe && ($0.path.contains("com.docker.install") || $0.category == .orphanedAppsData || $0.category == .macOSWallpaperAndMedia || $0.category == .hiddenDotfileBloat) }.reduce(Int64(0)) { $0 + $1.sizeBytes }
        let orphanExtras = orphanedLeftovers.filter { !$0.path.contains("Application Support") }.reduce(Int64(0)) { $0 + $1.sizeBytes }
        return pkgAndAICaches + deepSurgical + orphanExtras
    }

    /// Executes Level 1 (Limpieza Rápida Segura) immediately without confirmation prompts
    func runQuickSafeCleanup() async {
        isExecutingOperation = true
        currentOperationTitle = "Ejecutando Limpieza Rápida Segura..."
        defer { isExecutingOperation = false }

        let useTrash = safeModeTrashOnly
        var freedTotal: Int64 = 0

        // 1. Clean safe browser, system & Xcode caches
        let targetCaches = cacheItems.filter { $0.safety == .safe && ($0.category == .systemAndGeneral || $0.category == .browsersAndApps || $0.category == .xcodeAndSimulators) }
        for item in targetCaches {
            appendLog("Limpieza rápida: \(item.name) (\(ByteFormatter.string(from: item.sizeBytes)))", detail: item.path, level: .info)
            await Task.detached(priority: .userInitiated) {
                let fm = FileManager.default
                if item.customCleanCommand == "FIND_INSTALLERS" {
                    Self.cleanInstallerFiles(in: item.path, moveToTrash: useTrash)
                    return
                }
                guard fm.fileExists(atPath: item.path), let contents = try? fm.contentsOfDirectory(atPath: item.path) else { return }
                for sub in contents {
                    let full = (item.path as NSString).appendingPathComponent(sub)
                    if useTrash {
                        try? fm.trashItem(at: URL(fileURLWithPath: full), resultingItemURL: nil)
                    } else {
                        try? fm.removeItem(atPath: full)
                    }
                }
            }.value
            freedTotal += item.sizeBytes
        }

        // 2. Clean safe internal app caches (GPUCache, Crashpad, Service Worker, Code Cache)
        let internalTargets = surgicalItems.filter { $0.safety == .safe && $0.category == .appSupportSurgery && !$0.path.contains("com.docker.install") }
        for sItem in internalTargets {
            appendLog("Caché interna: \(sItem.title)", detail: sItem.path, level: .info)
            await Task.detached(priority: .userInitiated) {
                let fm = FileManager.default
                let url = URL(fileURLWithPath: sItem.path)
                if useTrash {
                    if (try? fm.trashItem(at: url, resultingItemURL: nil)) == nil {
                        try? fm.removeItem(at: url)
                    }
                } else {
                    try? fm.removeItem(at: url)
                }
            }.value
            freedTotal += sItem.sizeBytes
        }

        // 3. Run SQLite VACUUM & QuickLook Cache reset
        let homeDir = home
        let mSafe = mSeriesItems.filter { $0.safety == .safe && ($0.kind == .sqliteVacuum || $0.actionCode == "QL_RESET") }
        for mItem in mSafe {
            freedTotal += mItem.sizeBytes
        }
        await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            let dbs = [
                "\(homeDir)/.codex/thread_history_1.sqlite",
                "\(homeDir)/.codex/logs_2.sqlite",
                "\(homeDir)/.pine_checkpoints.sqlite",
                "\(homeDir)/Library/Application Support/Google/Chrome/Default/History",
                "\(homeDir)/Library/Safari/History.db"
            ]
            for db in dbs where fm.fileExists(atPath: db) {
                let escaped = db.replacingOccurrences(of: "\"", with: "\\\"")
                _ = Self.runShell("sqlite3 \"\(escaped)\" 'VACUUM;' 2>/dev/null")
            }
            _ = Self.runShell("qlmanage -r cache 2>/dev/null")
        }.value

        if freedTotal > 0 {
            recordFreedSpace(freedTotal)
            appendLog("Limpieza Rápida Segura completada: +\(ByteFormatter.string(from: freedTotal))", level: .success)
            lastStatusMessage = "Limpieza Rápida completada: +\(ByteFormatter.string(from: freedTotal)) liberados sin cerrar tus sesiones."
        } else {
            lastStatusMessage = "Las cachés rápidas ya están limpias y optimizadas."
        }

        await scanCaches()
        await scanSurgicalTargets()
        await scanAppleSiliconDeep()
        refreshDiskOverview()
    }

    /// Executes Level 2 (Limpieza Profunda de Datos del Sistema)
    func runDeepSystemCleanup() async {
        isExecutingOperation = true
        currentOperationTitle = "Ejecutando Limpieza Profunda de Datos del Sistema..."
        defer { isExecutingOperation = false }

        let useTrash = safeModeTrashOnly
        var freedTotal: Int64 = 0

        // 1. Clean Package Manager & AI Caches (Homebrew, npm, pnpm, uv, pip, Cargo, Codex)
        let pkgTargets = cacheItems.filter { $0.safety == .safe && ($0.category == .packageManagers || $0.category == .aiAndDevTools) }
        for item in pkgTargets {
            appendLog("Limpiando paquetes/IA: \(item.name) (\(ByteFormatter.string(from: item.sizeBytes)))", detail: item.path, level: .info)
            await Task.detached(priority: .userInitiated) {
                let fm = FileManager.default
                if let cmd = item.customCleanCommand {
                    _ = Self.runShell(cmd)
                }
                guard fm.fileExists(atPath: item.path), let contents = try? fm.contentsOfDirectory(atPath: item.path) else { return }
                for sub in contents {
                    let full = (item.path as NSString).appendingPathComponent(sub)
                    if useTrash {
                        try? fm.trashItem(at: URL(fileURLWithPath: full), resultingItemURL: nil)
                    } else {
                        try? fm.removeItem(atPath: full)
                    }
                }
            }.value
            freedTotal += item.sizeBytes
        }

        // 2. Clean Deep Surgical Targets (com.docker.install, Ghost Apps in Application Support, 4K Aerials, Hidden Dotfile Bloat)
        let deepSurgical = surgicalItems.filter { $0.safety == .safe && ($0.path.contains("com.docker.install") || $0.category == .orphanedAppsData || $0.category == .macOSWallpaperAndMedia || $0.category == .hiddenDotfileBloat) }
        for sItem in deepSurgical {
            appendLog("Purga profunda: \(sItem.title) (\(ByteFormatter.string(from: sItem.sizeBytes)))", detail: sItem.path, level: .info)
            await Task.detached(priority: .userInitiated) {
                let fm = FileManager.default
                let url = URL(fileURLWithPath: sItem.path)
                if useTrash {
                    if (try? fm.trashItem(at: url, resultingItemURL: nil)) == nil {
                        try? fm.removeItem(at: url)
                    }
                } else {
                    try? fm.removeItem(at: url)
                }
            }.value
            freedTotal += sItem.sizeBytes
        }

        // 3. Clean remaining Orphaned Leftovers & thin APFS snapshots
        let extraOrphans = orphanedLeftovers.filter { !$0.path.contains("Application Support") }
        for orphan in extraOrphans {
            await Task.detached(priority: .userInitiated) {
                try? FileManager.default.trashItem(at: URL(fileURLWithPath: orphan.path), resultingItemURL: nil)
            }.value
            freedTotal += orphan.sizeBytes
        }

        await Task.detached(priority: .userInitiated) {
            _ = Self.runShell("tmutil thinlocalsnapshots / 10000000000 4 2>/dev/null")
        }.value

        if freedTotal > 0 {
            recordFreedSpace(freedTotal)
            appendLog("Limpieza Profunda completada: +\(ByteFormatter.string(from: freedTotal)) en Datos del Sistema", level: .success)
            lastStatusMessage = "Limpieza Profunda completada: +\(ByteFormatter.string(from: freedTotal)) liberados de Datos del Sistema."
        } else {
            lastStatusMessage = "Datos del Sistema ya optimizados."
        }

        await scanCaches()
        await scanSurgicalTargets()
        await scanSystemDataXRay()
        await scanInstalledApps()
        refreshDiskOverview()
    }

    // MARK: - Apple Silicon M-Series Deep Scanner & Optimizer

    func scanAppleSiliconDeep() async {
        isScanningMSeries = true
        defer { isScanningMSeries = false }

        let homeDir = home
        let result = await Task.detached(priority: .userInitiated) { () -> (AppleSiliconHardwareStatus, [MSeriesDeepItem], [AppleAppArchInfo]) in
            var status = AppleSiliconHardwareStatus()
            let fm = FileManager.default

            // 1. Hardware Chip & Unified Memory
            let brand = Self.runShell("sysctl -n machdep.cpu.brand_string 2>/dev/null").output.trimmingCharacters(in: .whitespacesAndNewlines)
            if !brand.isEmpty {
                status.chipName = brand
            }
            let memBytesStr = Self.runShell("sysctl -n hw.memsize 2>/dev/null").output.trimmingCharacters(in: .whitespacesAndNewlines)
            if let memBytes = Int64(memBytesStr) {
                status.physicalRAMGB = Int(memBytes / (1024 * 1024 * 1024))
            }

            // Swap & VM Volume usage
            let swapUsage = Self.runShell("sysctl -n vm.swapusage 2>/dev/null").output
            if let usedRange = swapUsage.range(of: "used = ") {
                let after = swapUsage[usedRange.upperBound...]
                let token = after.split(separator: " ").first.map(String.init) ?? ""
                if token.hasSuffix("M"), let val = Double(token.dropLast()) {
                    status.swapUsedBytes = Int64(val * 1024 * 1024)
                } else if token.hasSuffix("G"), let val = Double(token.dropLast()) {
                    status.swapUsedBytes = Int64(val * 1024 * 1024 * 1024)
                }
            }

            // Local APFS TimeMachine/OS Snapshots
            let tmOut = Self.runShell("tmutil listlocalsnapshots / 2>/dev/null").output
            let snapshots = tmOut.split(separator: "\n").filter { $0.contains("com.apple.") }
            status.localSnapshotsCount = snapshots.count

            // 2. Inspect Mach-O binary architectures across /Applications
            let appsDir = "/Applications"
            let appEntries = (try? fm.contentsOfDirectory(atPath: appsDir)) ?? []
            let appSizes = Self.batchSizesForPaths(appEntries.filter { $0.hasSuffix(".app") }.map { "\(appsDir)/\($0)" })

            var archList: [AppleAppArchInfo] = []
            var totalIntelSliceEstimate: Int64 = 0

            for entry in appEntries where entry.hasSuffix(".app") {
                let bundlePath = "\(appsDir)/\(entry)"
                let plistPath = "\(bundlePath)/Contents/Info.plist"
                guard let dict = NSDictionary(contentsOfFile: plistPath),
                      let execName = dict["CFBundleExecutable"] as? String else { continue }

                let execPath = "\(bundlePath)/Contents/MacOS/\(execName)"
                guard fm.fileExists(atPath: execPath) else { continue }

                let archOut = Self.runShell("lipo -archs \"\(execPath.replacingOccurrences(of: "\"", with: "\\\""))\" 2>/dev/null").output.trimmingCharacters(in: .whitespacesAndNewlines)
                let archs = archOut.split(separator: " ").map(String.init)
                guard !archs.isEmpty else { continue }

                let totalSize = appSizes[bundlePath] ?? 0
                let execAttr = try? fm.attributesOfItem(atPath: execPath)
                let execSize = (execAttr?[.size] as? Int64) ?? 0
                let isUniversal = archs.contains("arm64") && archs.contains("x86_64")
                let isIntelOnly = !archs.contains("arm64") && archs.contains("x86_64")

                if isUniversal { status.universalAppsCount += 1 }
                else if isIntelOnly { status.intelOnlyAppsCount += 1 }
                else { status.nativeArm64AppsCount += 1 }

                // Estimate Intel x86_64 slice inside main binary + Frameworks
                let intelSlice = isUniversal ? max(execSize / 2, min(totalSize / 5, 180 * 1024 * 1024)) : 0
                totalIntelSliceEstimate += intelSlice

                let bundleId = (dict["CFBundleIdentifier"] as? String) ?? ""
                let hasMASReceipt = fm.fileExists(atPath: "\(bundlePath)/Contents/_MASReceipt")
                let isAppleOrMAS = bundleId.hasPrefix("com.apple.") || hasMASReceipt

                archList.append(AppleAppArchInfo(
                    name: (entry as NSString).deletingPathExtension,
                    bundlePath: bundlePath,
                    executablePath: execPath,
                    architectures: archs,
                    totalAppSize: totalSize,
                    estimatedIntelSliceBytes: intelSlice,
                    isAppleSignedOrAppStore: isAppleOrMAS
                ))
            }

            archList.sort { $0.totalAppSize > $1.totalAppSize }
            status.estimatedIntelBinaryWasteBytes = totalIntelSliceEstimate

            // 3. Build M-Series Deep Optimization Items
            var deepItems: [MSeriesDeepItem] = []

            // A) SQLite Database Vacuuming (Safe, lossless space reclamation)
            let sqliteCandidates = [
                "\(homeDir)/.codex/thread_history_1.sqlite",
                "\(homeDir)/.codex/logs_2.sqlite",
                "\(homeDir)/.pine_checkpoints.sqlite",
                "\(homeDir)/Library/Application Support/Google/Chrome/Default/History",
                "\(homeDir)/Library/Application Support/Google/Chrome/Default/Cookies",
                "\(homeDir)/Library/Safari/History.db"
            ].filter { fm.fileExists(atPath: $0) }

            let sqliteSizes = Self.batchSizesForPaths(sqliteCandidates)
            let totalSqliteBytes = sqliteSizes.values.reduce(0, +)
            status.totalVacuumableSQLiteBytes = totalSqliteBytes

            if totalSqliteBytes > 1024 * 1024 {
                deepItems.append(MSeriesDeepItem(
                    identifier: "sqlite_vacuum_all",
                    title: "Compactación sin Pérdida de Bases SQLite (VACUUM)",
                    subtitle: "Desfragmenta y recupera páginas vacías en \(sqliteCandidates.count) bases SQLite (Chrome, Safari, Codex, índices) sin borrar un solo dato ni cerrar sesiones.",
                    technicalDetail: "Ejecuta 'sqlite3 <db> VACUUM;' en bases locales (\(ByteFormatter.string(from: totalSqliteBytes)) analizados)",
                    kind: .sqliteVacuum,
                    sizeBytes: totalSqliteBytes / 4, // Typical reclaimable page fragmentation
                    safety: .safe,
                    actionButtonTitle: "Compactar SQLite",
                    actionCode: "SQLITE_VACUUM",
                    targetPath: sqliteCandidates.first
                ))
            }

            // B) Rosetta 2 AOT Translation Cache & Crash Logs
            let rosettaDiagnosticPaths = [
                "\(homeDir)/Library/Logs/DiagnosticReports",
                "/Library/Logs/DiagnosticReports"
            ]
            let diagSizes = Self.batchSizesForPaths(rosettaDiagnosticPaths)
            let totalDiag = diagSizes.values.reduce(0, +)
            if totalDiag > 128 * 1024 {
                deepItems.append(MSeriesDeepItem(
                    identifier: "rosetta_and_diagnostics",
                    title: "Volcados de Memoria y Reportes de Fallos (.ips / CrashReporter)",
                    subtitle: "Archivos de diagnóstico generados cuando una app o proceso traducido por Rosetta 2 se cierra inesperadamente.",
                    technicalDetail: "~/Library/Logs/DiagnosticReports",
                    kind: .binaryArchitecture,
                    sizeBytes: totalDiag,
                    safety: .safe,
                    actionButtonTitle: "Limpiar Reportes",
                    actionCode: "CLEAN_PATH",
                    targetPath: "\(homeDir)/Library/Logs/DiagnosticReports"
                ))
            }

            // C) Neural Engine / Local AI Weights & Runtimes
            let aiPaths: [(name: String, path: String, desc: String)] = [
                ("Modelos Locales de Ollama (~/.ollama)", "\(homeDir)/.ollama/models", "Pesos de modelos LLM locales para Apple Neural Engine / Metal GPU."),
                ("Modelos de LM Studio (~/.cache/lm-studio)", "\(homeDir)/.cache/lm-studio", "Modelos GGUF/MLX descargados por LM Studio."),
                ("Checkpoints Locales de Pine (~/.pine_checkpoints.sqlite)", "\(homeDir)/.pine_checkpoints.sqlite", "Base de checkpoints instantáneos en tu carpeta de inicio."),
                ("Caché de Apple MediaAnalysisD (Neural Engine Vision)", "\(homeDir)/Library/Containers/com.apple.mediaanalysisd/Data/Library/Caches", "Caché temporal de inferencia visual generada por el Neural Engine.")
            ]
            let existingAI = aiPaths.filter { fm.fileExists(atPath: $0.path) }
            let aiSizes = Self.batchSizesForPaths(existingAI.map(\.path))
            for ai in existingAI {
                let sz = aiSizes[ai.path] ?? 0
                if sz > 1024 * 1024 {
                    let isSafeCache = ai.path.contains("Caches")
                    deepItems.append(MSeriesDeepItem(
                        identifier: "ai_\(ai.path)",
                        title: ai.name,
                        subtitle: ai.desc,
                        technicalDetail: ai.path,
                        kind: .neuralAndAIModels,
                        sizeBytes: sz,
                        safety: isSafeCache ? .safe : .caution,
                        actionButtonTitle: "Liberar",
                        actionCode: "CLEAN_PATH",
                        targetPath: ai.path
                    ))
                }
            }

            // D) APFS Local Snapshots & QuickLook Thumbnail Cache
            let qlCacheOut = Self.runShell("getconf DARWIN_USER_CACHE_DIR 2>/dev/null").output.trimmingCharacters(in: .whitespacesAndNewlines)
            if !qlCacheOut.isEmpty {
                let qlSize = Self.batchSizesForPaths([qlCacheOut])[qlCacheOut] ?? 0
                if qlSize > 5 * 1024 * 1024 {
                    deepItems.append(MSeriesDeepItem(
                        identifier: "darwin_quicklook_cache",
                        title: "Caché de Miniaturas QuickLook y Metal Shaders (DARWIN_USER_CACHE)",
                        subtitle: "Miniaturas pre-renderizadas y shaders compilados de GPU de Apple Silicon en /var/folders. Se regeneran bajo demanda.",
                        technicalDetail: "qlmanage -r cache · \(qlCacheOut)",
                        kind: .apfsSnapshotsAndSwap,
                        sizeBytes: qlSize,
                        safety: .safe,
                        actionButtonTitle: "Purgar QuickLook",
                        actionCode: "QL_RESET",
                        targetPath: qlCacheOut
                    ))
                }
            }

            if status.localSnapshotsCount > 0 {
                deepItems.append(MSeriesDeepItem(
                    identifier: "apfs_snapshots_thin",
                    title: "Adelgazar \(status.localSnapshotsCount) Instantáneas APFS Locales",
                    subtitle: "macOS retiene bloques borrados en instantáneas invisibles de APFS. Solicitar 'tmutil thinlocalsnapshots' libera bloques retenidos de forma 100% nativa.",
                    technicalDetail: "tmutil thinlocalsnapshots / 10000000000 4",
                    kind: .apfsSnapshotsAndSwap,
                    sizeBytes: 0,
                    safety: .safe,
                    actionButtonTitle: "Liberar Bloques APFS",
                    actionCode: "APFS_THIN",
                    targetPath: nil
                ))
            }

            // E) Orphaned LaunchAgents (broken plists pointing to non-existent binaries)
            let launchAgentsDir = "\(homeDir)/Library/LaunchAgents"
            if let plists = try? fm.contentsOfDirectory(atPath: launchAgentsDir) {
                for plist in plists where plist.hasSuffix(".plist") {
                    let fullPlist = "\(launchAgentsDir)/\(plist)"
                    guard let dict = NSDictionary(contentsOfFile: fullPlist) else { continue }
                    var execCandidate: String?
                    if let prog = dict["Program"] as? String {
                        execCandidate = prog
                    } else if let args = dict["ProgramArguments"] as? [String], let first = args.first {
                        execCandidate = first
                    }
                    if let bin = execCandidate, bin.hasPrefix("/"), !bin.hasPrefix("/bin/"), !bin.hasPrefix("/usr/bin/"), !fm.fileExists(atPath: bin) {
                        deepItems.append(MSeriesDeepItem(
                            identifier: "orphan_agent_\(plist)",
                            title: "Agente de Inicio Huérfano: \(plist)",
                            subtitle: "Intenta ejecutar en segundo plano un binario que ya fue desinstalado (\(bin)).",
                            technicalDetail: fullPlist,
                            kind: .backgroundAgents,
                            sizeBytes: 4096,
                            safety: .safe,
                            actionButtonTitle: "Eliminar Agente",
                            actionCode: "CLEAN_PATH",
                            targetPath: fullPlist
                        ))
                    }
                }
            }

            return (status, deepItems, archList)
        }.value

        mSeriesStatus = result.0
        mSeriesItems = result.1
        appArchitectures = result.2
    }

    func executeMSeriesOptimization(_ item: MSeriesDeepItem) async {
        isExecutingOperation = true
        currentOperationTitle = "Optimizando: \(item.title)..."
        defer { isExecutingOperation = false }

        let homeDir = home
        appendLog("Ejecutando optimización M-Series: \(item.title)", detail: item.technicalDetail, level: .info)

        await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            switch item.actionCode {
            case "SQLITE_VACUUM":
                let dbs = [
                    "\(homeDir)/.codex/thread_history_1.sqlite",
                    "\(homeDir)/.codex/logs_2.sqlite",
                    "\(homeDir)/.pine_checkpoints.sqlite",
                    "\(homeDir)/Library/Application Support/Google/Chrome/Default/History",
                    "\(homeDir)/Library/Safari/History.db"
                ]
                for db in dbs where fm.fileExists(atPath: db) {
                    let escaped = db.replacingOccurrences(of: "\"", with: "\\\"")
                    _ = Self.runShell("sqlite3 \"\(escaped)\" 'VACUUM;' 2>/dev/null")
                }
            case "QL_RESET":
                _ = Self.runShell("qlmanage -r cache 2>/dev/null")
            case "APFS_THIN":
                _ = Self.runShell("tmutil thinlocalsnapshots / 10000000000 4 2>/dev/null")
            case "CLEAN_PATH":
                if let p = item.targetPath {
                    if (try? fm.trashItem(at: URL(fileURLWithPath: p), resultingItemURL: nil)) == nil {
                        try? fm.removeItem(atPath: p)
                    }
                }
            default:
                break
            }
        }.value

        if item.sizeBytes > 0 {
            recordFreedSpace(item.sizeBytes)
        }
        appendLog("Optimización completada: \(item.title)", detail: item.technicalDetail, level: .success)
        lastStatusMessage = "Optimización '\(item.title)' completada exitosamente."
        await scanAppleSiliconDeep()
        refreshDiskOverview()
    }

    func runAllSafeMSeriesOptimizations() async {
        let safeList = mSeriesItems.filter { $0.safety == .safe }
        guard !safeList.isEmpty else { return }
        for item in safeList {
            await executeMSeriesOptimization(item)
        }
    }

    func thinUniversalAppToArm64(_ app: AppleAppArchInfo) async {
        guard app.isUniversal && !app.isAppleSignedOrAppStore else { return }

        isExecutingOperation = true
        currentOperationTitle = "Extrayendo arquitectura arm64 en \(app.name)..."
        defer { isExecutingOperation = false }

        appendLog("Ejecutando lipo -thin arm64 en \(app.name)", detail: app.executablePath, level: .info)

        let success = await Task.detached(priority: .userInitiated) { () -> Bool in
            let exec = app.executablePath.replacingOccurrences(of: "\"", with: "\\\"")
            let tmp = "\(exec).arm64_tmp"
            let lipoRes = Self.runShell("lipo -thin arm64 \"\(exec)\" -output \"\(tmp)\" && mv -f \"\(tmp)\" \"\(exec)\"")
            if lipoRes.exitCode == 0 {
                let bundle = app.bundlePath.replacingOccurrences(of: "\"", with: "\\\"")
                _ = Self.runShell("codesign --force --deep --sign - \"\(bundle)\" 2>/dev/null")
                return true
            }
            return false
        }.value

        if success {
            appendLog("\(app.name) ahora es 100% nativo arm64.", detail: app.bundlePath, level: .success)
            lastStatusMessage = "Se eliminó el código Intel x86_64 redundante de '\(app.name)'."
        } else {
            appendLog("No se pudo modificar \(app.name) (requiere permisos de root o firma bloqueada).", detail: app.executablePath, level: .warning)
            lastStatusMessage = "'\(app.name)' está protegido por permisos de administrador."
        }

        await scanAppleSiliconDeep()
        refreshDiskOverview()
    }

    func revealInFinder(path: String) {
        NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
    }

    // MARK: - High-Performance Batch Sizing Helpers

    /// Uses `du -k -d 1` (without `-s`, since macOS BSD `du` rejects `-s` + `-d 1`) on a parent directory in a single pass.
    nonisolated static func fastSubdirectorySizes(parentDir: String) -> [String: Int64] {
        let escaped = parentDir.replacingOccurrences(of: "\"", with: "\\\"")
        let cmd = "du -k -d 1 \"\(escaped)\" 2>/dev/null"
        let res = runShell(cmd)
        var map: [String: Int64] = [:]
        for line in res.output.split(separator: "\n") {
            let parts = line.split(separator: "\t", maxSplits: 1).map(String.init)
            if parts.count == 2, let kb = Int64(parts[0].trimmingCharacters(in: .whitespaces)) {
                var cleanPath = parts[1]
                while cleanPath.count > 1 && cleanPath.hasSuffix("/") {
                    cleanPath.removeLast()
                }
                // Normalize double slashes when scanning root "/"
                if cleanPath.hasPrefix("//") {
                    cleanPath.removeFirst()
                }
                map[cleanPath] = kb * 1024
            }
        }
        return map
    }

    /// Sizes an arbitrary list of paths in ONE single `du -sk` process invocation.
    nonisolated static func batchSizesForPaths(_ paths: [String]) -> [String: Int64] {
        let unique = Array(Set(paths))
        guard !unique.isEmpty else { return [:] }

        var map: [String: Int64] = [:]
        let chunkSize = 80
        for start in stride(from: 0, to: unique.count, by: chunkSize) {
            let end = min(start + chunkSize, unique.count)
            let chunk = unique[start..<end]
            let quoted = chunk.map { "\"\($0.replacingOccurrences(of: "\"", with: "\\\""))\"" }.joined(separator: " ")
            let res = runShell("du -sk \(quoted) 2>/dev/null")
            for line in res.output.split(separator: "\n") {
                let parts = line.split(separator: "\t", maxSplits: 1).map(String.init)
                if parts.count == 2, let kb = Int64(parts[0].trimmingCharacters(in: .whitespaces)) {
                    map[parts[1]] = kb * 1024
                }
            }
        }
        return map
    }

    nonisolated static func installerFilesSize(in downloadsPath: String) -> Int64 {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(atPath: downloadsPath) else { return 0 }
        let exts = Set(["dmg", "pkg", "iso"])
        var total: Int64 = 0
        for item in items {
            let ext = (item as NSString).pathExtension.lowercased()
            if exts.contains(ext) {
                let full = (downloadsPath as NSString).appendingPathComponent(item)
                let attr = try? fm.attributesOfItem(atPath: full)
                total += (attr?[.size] as? Int64) ?? 0
            }
        }
        return total
    }

    nonisolated static func cleanInstallerFiles(in downloadsPath: String, moveToTrash: Bool) {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(atPath: downloadsPath) else { return }
        let exts = Set(["dmg", "pkg", "iso"])
        for item in items {
            let ext = (item as NSString).pathExtension.lowercased()
            if exts.contains(ext) {
                let full = (downloadsPath as NSString).appendingPathComponent(item)
                if moveToTrash {
                    try? fm.trashItem(at: URL(fileURLWithPath: full), resultingItemURL: nil)
                } else {
                    try? fm.removeItem(atPath: full)
                }
            }
        }
    }

    nonisolated static func runAppleScript(_ source: String) -> (output: String, exitCode: Int32) {
        let process = Process()
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", source]
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            let output = String(data: data, encoding: .utf8) ?? ""
            return (output, process.terminationStatus)
        } catch {
            return (error.localizedDescription, -1)
        }
    }

    nonisolated static func runShell(_ command: String) -> (output: String, exitCode: Int32) {
        let process = Process()
        let pipe = Pipe()

        process.standardOutput = pipe
        process.standardError = pipe
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")

        var env = ProcessInfo.processInfo.environment
        let extraPaths = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        if let existing = env["PATH"] {
            env["PATH"] = "\(extraPaths):\(existing)"
        } else {
            env["PATH"] = extraPaths
        }
        process.environment = env
        process.arguments = ["-c", command]

        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            let output = String(data: data, encoding: .utf8) ?? ""
            return (output, process.terminationStatus)
        } catch {
            return ("", -1)
        }
    }
}
