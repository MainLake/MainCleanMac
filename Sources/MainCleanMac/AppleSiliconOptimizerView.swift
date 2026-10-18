import Foundation
import SwiftUI
import AppKit

struct AppleSiliconHardwareStatus {
    var chipName: String = "Apple M-Series"
    var physicalRAMGB: Int = 8
    var swapUsedBytes: Int64 = 0
    var vmVolumeBytes: Int64 = 0
    var localSnapshotsCount: Int = 0
    var universalAppsCount: Int = 0
    var intelOnlyAppsCount: Int = 0
    var nativeArm64AppsCount: Int = 0
    var estimatedIntelBinaryWasteBytes: Int64 = 0
    var totalVacuumableSQLiteBytes: Int64 = 0
}

enum MSeriesOptimizationKind: String, CaseIterable {
    case binaryArchitecture = "Arquitectura Universal & Rosetta 2"
    case neuralAndAIModels = "Neural Engine & Modelos de IA Local"
    case apfsSnapshotsAndSwap = "APFS, Swap & Memoria Unificada"
    case sqliteVacuum = "Compactación SQLite (Sin Pérdida)"
    case backgroundAgents = "LaunchAgents & Demonios Huérfanos"

    var icon: String {
        switch self {
        case .binaryArchitecture: return "cpu.fill"
        case .neuralAndAIModels: return "brain.head.profile"
        case .apfsSnapshotsAndSwap: return "memorychip.fill"
        case .sqliteVacuum: return "cylinder.split.1x2.fill"
        case .backgroundAgents: return "bolt.horizontal.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .binaryArchitecture: return RamanTheme.laserCyan
        case .neuralAndAIModels: return RamanTheme.antiStokesViolet
        case .apfsSnapshotsAndSwap: return RamanTheme.emeraldSafe
        case .sqliteVacuum: return .blue
        case .backgroundAgents: return RamanTheme.stokesAmber
        }
    }
}

struct MSeriesDeepItem: Identifiable, Hashable {
    var id: String { identifier }
    let identifier: String
    let title: String
    let subtitle: String
    let technicalDetail: String
    let kind: MSeriesOptimizationKind
    let sizeBytes: Int64
    let safety: SafetyLevel
    let actionButtonTitle: String
    let actionCode: String
    let targetPath: String?
}

struct AppleAppArchInfo: Identifiable, Hashable {
    var id: String { bundlePath }
    let name: String
    let bundlePath: String
    let executablePath: String
    let architectures: [String]
    let totalAppSize: Int64
    let estimatedIntelSliceBytes: Int64
    let isAppleSignedOrAppStore: Bool

    var isUniversal: Bool {
        architectures.contains("arm64") && architectures.contains("x86_64")
    }

    var isIntelOnly: Bool {
        !architectures.contains("arm64") && architectures.contains("x86_64")
    }

    var archLabel: String {
        if isUniversal { return "Universal (arm64 + Intel)" }
        if isIntelOnly { return "Rosetta 2 (Solo Intel)" }
        return "100% Nativo arm64"
    }

    var badgeColor: Color {
        if isUniversal { return RamanTheme.laserCyan }
        if isIntelOnly { return RamanTheme.stokesAmber }
        return RamanTheme.emeraldSafe
    }
}

struct AppleSiliconOptimizerView: View {
    @EnvironmentObject var scanner: SystemScannerService
    // 4 Strictly Separated Sub-Tabs:
    // 0 = Optimizador M-Series
    // 1 = Binarios Mach-O (arm64 vs Intel)
    // 2 = Artefactos de Código (node_modules / .venv)
    // 3 = Contenedores Docker
    @State private var selectedSection: Int = 0
    @State private var itemPendingConfirm: MSeriesDeepItem?
    @State private var appPendingThin: AppleAppArchInfo?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top Header
            HStack(spacing: 16) {
                HStack(spacing: 10) {
                    Text("Desarrollo y Chip M")
                        .font(.system(size: 22, weight: .bold))
                    Text(scanner.mSeriesStatus.chipName.uppercased())
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(MainCleanTheme.emeraldSafe)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(MainCleanTheme.emeraldSafe.opacity(0.14), in: Capsule())
                }

                Spacer()

                Picker("", selection: $selectedSection) {
                    Text("Optimización M").tag(0)
                    Text("Arquitectura Apps").tag(1)
                    Text("Proyectos (\(scanner.projectArtifacts.count))").tag(2)
                    Text("Docker").tag(3)
                }
                .pickerStyle(.segmented)
                .frame(width: 470)

                Button {
                    Task {
                        if selectedSection == 0 || selectedSection == 1 {
                            await scanner.scanAppleSiliconDeep()
                        } else if selectedSection == 2 {
                            await scanner.scanProjectArtifacts()
                        } else {
                            await scanner.refreshDocker()
                        }
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(scanner.isScanningMSeries || scanner.isExecutingOperation)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 20)
            .onAppear {
                scanner.ensureMSeriesLoaded()
                scanner.ensureDevAndDockerLoaded()
            }

            Divider().overlay(Color.white.opacity(0.07))

            // Render strictly ONE sub-tool at a time
            switch selectedSection {
            case 0:
                mSeriesDeepSubView
            case 1:
                binaryArchInspectorSubView
            case 2:
                ProjectArtifactsSubView()
            default:
                DockerManagerView()
            }
        }
        .alert(
            "Confirmar Optimización: \(itemPendingConfirm?.title ?? "")",
            isPresented: Binding(
                get: { itemPendingConfirm != nil },
                set: { if !$0 { itemPendingConfirm = nil } }
            )
        ) {
            Button("Cancelar", role: .cancel) { itemPendingConfirm = nil }
            Button("Ejecutar Optimización", role: .destructive) {
                if let item = itemPendingConfirm {
                    Task { await scanner.executeMSeriesOptimization(item) }
                }
                itemPendingConfirm = nil
            }
        } message: {
            if let item = itemPendingConfirm {
                Text("\(item.subtitle)\n\nDetalle: \(item.technicalDetail)")
            }
        }
        .alert(
            "Adelgazar binario de \(appPendingThin?.name ?? "") a solo arm64",
            isPresented: Binding(
                get: { appPendingThin != nil },
                set: { if !$0 { appPendingThin = nil } }
            )
        ) {
            Button("Cancelar", role: .cancel) { appPendingThin = nil }
            Button("Extraer solo arm64 (lipo)", role: .destructive) {
                if let app = appPendingThin {
                    Task { await scanner.thinUniversalAppToArm64(app) }
                }
                appPendingThin = nil
            }
        } message: {
            if let app = appPendingThin {
                Text("Se usará la herramienta nativa 'lipo -thin arm64' sobre el ejecutable principal de '\(app.name)' y se re-firmará localmente para conservar solo el código nativo de tu chip \(scanner.mSeriesStatus.chipName).")
            }
        }
    }

    // MARK: - Sub-Tab 0: Deep M-Series Optimizations

    private var mSeriesDeepSubView: some View {
        Group {
            if scanner.isScanningMSeries && scanner.mSeriesItems.isEmpty {
                VStack(spacing: 14) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(RamanTheme.emeraldSafe)
                    Text("Analizando memoria unificada, snapshots APFS y bases SQLite...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack(spacing: 14) {
                            MSeriesTelemetryCard(
                                title: scanner.mSeriesStatus.chipName,
                                value: "\(scanner.mSeriesStatus.physicalRAMGB) GB RAM Unificada",
                                subtitle: "Swap en SSD: \(ByteFormatter.string(from: scanner.mSeriesStatus.swapUsedBytes))",
                                icon: "cpu.fill",
                                color: RamanTheme.emeraldSafe
                            )

                            MSeriesTelemetryCard(
                                title: "Binarios Universales / Intel",
                                value: "\(scanner.mSeriesStatus.universalAppsCount) Universales · \(scanner.mSeriesStatus.intelOnlyAppsCount) Rosetta",
                                subtitle: "Código x86_64 redundante: ~\(ByteFormatter.string(from: scanner.mSeriesStatus.estimatedIntelBinaryWasteBytes))",
                                icon: "square.stack.3d.forward.dottedline.fill",
                                color: RamanTheme.laserCyan
                            )

                            MSeriesTelemetryCard(
                                title: "Instantáneas APFS & SQLite",
                                value: "\(scanner.mSeriesStatus.localSnapshotsCount) Snapshots locales",
                                subtitle: "Bases SQLite compactables: \(ByteFormatter.string(from: scanner.mSeriesStatus.totalVacuumableSQLiteBytes))",
                                icon: "cylinder.split.1x2.fill",
                                color: RamanTheme.antiStokesViolet
                            )
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("OPTIMIZACIONES DE BAJO NIVEL PARA FAMILIA M")
                                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button {
                                    Task { await scanner.runAllSafeMSeriesOptimizations() }
                                } label: {
                                    Label("Ejecutar Todas las Seguras", systemImage: "bolt.shield.fill")
                                        .font(.caption.weight(.bold))
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(RamanTheme.emeraldSafe)
                                .foregroundStyle(.black)
                                .disabled(scanner.isExecutingOperation)
                            }

                            ForEach(scanner.mSeriesItems) { item in
                                HStack(spacing: 14) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(item.kind.color.opacity(0.16))
                                            .frame(width: 40, height: 40)
                                        Image(systemName: item.kind.icon)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(item.kind.color)
                                    }

                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack(spacing: 8) {
                                            Text(item.title)
                                                .font(.subheadline.weight(.semibold))
                                            Text(item.kind.rawValue)
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundStyle(item.kind.color)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(item.kind.color.opacity(0.14), in: Capsule())
                                            SafetyBadgeView(level: item.safety)
                                        }
                                        Text(item.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(item.technicalDetail)
                                            .font(.caption2.monospaced())
                                            .foregroundStyle(.secondary.opacity(0.75))
                                            .lineLimit(1)
                                    }

                                    Spacer()

                                    if item.sizeBytes > 0 {
                                        Text(ByteFormatter.string(from: item.sizeBytes))
                                            .font(.system(.callout, design: .rounded).monospacedDigit().bold())
                                            .foregroundStyle(RamanTheme.laserCyan)
                                    }

                                    if let path = item.targetPath {
                                        Button {
                                            scanner.revealInFinder(path: path)
                                        } label: {
                                            Image(systemName: "magnifyingglass")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .frame(width: 26, height: 26)
                                                .background(Color.white.opacity(0.06), in: Circle())
                                        }
                                        .buttonStyle(.plain)
                                        .help("Ver en Finder")
                                    }

                                    Button {
                                        if item.safety == .caution {
                                            itemPendingConfirm = item
                                        } else {
                                            Task { await scanner.executeMSeriesOptimization(item) }
                                        }
                                    } label: {
                                        Text(item.actionButtonTitle)
                                            .font(.caption.weight(.semibold))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(item.safety == .safe ? RamanTheme.laserCyan : RamanTheme.stokesAmber)
                                    .foregroundStyle(.black)
                                    .disabled(scanner.isExecutingOperation)
                                }
                                .padding(14)
                                .background(RamanTheme.panelBg, in: RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(RamanTheme.borderSubtle, lineWidth: 1)
                                )
                            }
                        }
                    }
                    .padding(28)
                }
            }
        }
    }

    // MARK: - Sub-Tab 1: Mach-O Binary Inspector (arm64 vs x86_64)

    private var binaryArchInspectorSubView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("INSPECTOR DE BINARIOS MACH-O (ARM64 VS INTEL X86_64)")
                            .font(.system(size: 11, weight: .heavy, design: .monospaced))
                            .foregroundStyle(RamanTheme.laserCyan)
                        Text("Las aplicaciones 'Universal' contienen binarios duplicados para chips Intel y Apple Silicon. Las apps con sello criptográfico de Apple o App Store están protegidas.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                ForEach(scanner.appArchitectures) { app in
                    HStack(spacing: 14) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: app.bundlePath))
                            .resizable()
                            .frame(width: 34, height: 34)

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 8) {
                                Text(app.name)
                                    .font(.subheadline.weight(.semibold))
                                Text(app.archLabel)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(app.badgeColor)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2)
                                    .background(app.badgeColor.opacity(0.14), in: Capsule())
                            }
                            Text("Peso total: \(ByteFormatter.string(from: app.totalAppSize)) · Arquitecturas: \(app.architectures.joined(separator: ", "))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if app.isUniversal {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("~\(ByteFormatter.string(from: app.estimatedIntelSliceBytes))")
                                    .font(.subheadline.monospacedDigit().bold())
                                    .foregroundStyle(RamanTheme.laserCyan)
                                Text("Slice x86_64")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            if app.isAppleSignedOrAppStore {
                                Text("Firma Protegida")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.white.opacity(0.05), in: Capsule())
                            } else {
                                Button {
                                    appPendingThin = app
                                } label: {
                                    Text("Adelgazar a arm64")
                                        .font(.caption.weight(.semibold))
                                }
                                .buttonStyle(.bordered)
                                .disabled(scanner.isExecutingOperation)
                            }
                        } else if app.isIntelOnly {
                            Text("Requiere Rosetta 2")
                                .font(.caption2.bold())
                                .foregroundStyle(RamanTheme.stokesAmber)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(RamanTheme.emeraldSafe)
                        }
                    }
                    .padding(12)
                    .background(RamanTheme.panelBg, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(RamanTheme.borderSubtle, lineWidth: 1)
                    )
                }
            }
            .padding(28)
        }
    }
}

struct MSeriesTelemetryCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.system(.headline, design: .rounded).bold())
                .lineLimit(1)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RamanTheme.panelBg, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(color.opacity(0.25), lineWidth: 1)
        )
    }
}
