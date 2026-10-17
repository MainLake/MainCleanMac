import SwiftUI

struct SpaceLensView: View {
    @EnvironmentObject var scanner: SystemScannerService
    @State private var selectedMode: Int = 0 // 0 = Mapa de Carpetas, 1 = Rayos X: Datos del Sistema
    @State private var entryPendingConfirmation: SpaceEntry?
    @State private var xrayItemPendingDelete: SystemDataXRayItem?

    var pathComponents: [(name: String, fullPath: String)] {
        let parts = scanner.currentSpacePath.split(separator: "/").map(String.init)
        var result: [(String, String)] = [("/", "/")]
        var running = ""
        for p in parts {
            running += "/\(p)"
            result.append((p, running))
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top Lens Header
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 10) {
                        Text("Espectro Disco")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                        Text("ANÁLISIS VOLUMÉTRICO")
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .foregroundStyle(RamanTheme.antiStokesViolet)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(RamanTheme.antiStokesViolet.opacity(0.16), in: Capsule())
                    }
                    Text(
                        selectedMode == 0
                            ? "Navegación de alta velocidad por carpetas con candado de seguridad para rutas críticas."
                            : "Radiografía exacta de qué compone la caja negra de 'Datos del Sistema' de macOS."
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Picker("", selection: $selectedMode) {
                    Text("Mapa de Carpetas").tag(0)
                    Text("Rayos X: Datos del Sistema").tag(1)
                }
                .pickerStyle(.segmented)
                .frame(width: 340)

                Button {
                    Task {
                        if selectedMode == 0 {
                            await scanner.scanDirectory(path: scanner.currentSpacePath, forceRefresh: true)
                        } else {
                            await scanner.scanSystemDataXRay()
                        }
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .help("Recalcular")
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 20)
            .onAppear {
                scanner.ensureSpaceLensLoaded()
                scanner.ensureSystemDataLoaded()
            }

            Divider().overlay(Color.white.opacity(0.07))

            if selectedMode == 0 {
                folderExplorerSubView
            } else {
                systemDataXRaySubView
            }
        }
        .alert(
            "¿Mover '\(entryPendingConfirmation?.name ?? "")' al Basurero?",
            isPresented: Binding(
                get: { entryPendingConfirmation != nil },
                set: { if !$0 { entryPendingConfirmation = nil } }
            )
        ) {
            Button("Cancelar", role: .cancel) {
                entryPendingConfirmation = nil
            }
            Button("Mover al Basurero", role: .destructive) {
                if let entry = entryPendingConfirmation {
                    Task { await scanner.moveToTrash(entry: entry) }
                }
                entryPendingConfirmation = nil
            }
        } message: {
            if let entry = entryPendingConfirmation {
                Text("Tamaño: \(ByteFormatter.string(from: entry.sizeBytes)).\n\(entry.protectionReason ?? "Puedes recuperarlo desde el Basurero si lo necesitas.")")
            }
        }
        .alert(
            "¿Liberar '\(xrayItemPendingDelete?.title ?? "")'?",
            isPresented: Binding(
                get: { xrayItemPendingDelete != nil },
                set: { if !$0 { xrayItemPendingDelete = nil } }
            )
        ) {
            Button("Cancelar", role: .cancel) {
                xrayItemPendingDelete = nil
            }
            Button("Sí, Liberar Espacio", role: .destructive) {
                if let item = xrayItemPendingDelete {
                    Task { await scanner.cleanSystemDataItem(item) }
                }
                xrayItemPendingDelete = nil
            }
        } message: {
            if let item = xrayItemPendingDelete {
                Text("\(item.explanation)\n\nEspacio a recuperar: \(ByteFormatter.string(from: item.sizeBytes))")
            }
        }
    }

    // MARK: - Sub-Tab 0: Folder Explorer

    private var folderExplorerSubView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Navigation Bar + Breadcrumbs
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Button {
                        Task { await scanner.scanDirectory(path: "/") }
                    } label: {
                        Label("Raíz (/)", systemImage: "internaldrive")
                            .font(.caption.weight(.medium))
                    }

                    Button {
                        let home = FileManager.default.homeDirectoryForCurrentUser.path
                        Task { await scanner.scanDirectory(path: home) }
                    } label: {
                        Label("Usuario", systemImage: "house")
                            .font(.caption.weight(.medium))
                    }

                    Button {
                        Task { await scanner.scanDirectory(path: "/Applications") }
                    } label: {
                        Label("Apps", systemImage: "square.grid.2x2")
                            .font(.caption.weight(.medium))
                    }

                    Button {
                        let parent = (scanner.currentSpacePath as NSString).deletingLastPathComponent
                        if !parent.isEmpty {
                            Task { await scanner.scanDirectory(path: parent) }
                        }
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.caption.bold())
                    }
                    .disabled(scanner.currentSpacePath == "/")
                }
                .buttonStyle(.bordered)

                Divider().frame(height: 18)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(pathComponents.enumerated()), id: \.offset) { idx, comp in
                            Button {
                                Task { await scanner.scanDirectory(path: comp.fullPath) }
                            } label: {
                                Text(comp.name == "/" ? "Macintosh HD" : comp.name)
                                    .font(.caption.weight(idx == pathComponents.count - 1 ? .bold : .medium))
                                    .foregroundStyle(idx == pathComponents.count - 1 ? .white : .secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.white.opacity(idx == pathComponents.count - 1 ? 0.12 : 0.04), in: Capsule())
                            }
                            .buttonStyle(.plain)

                            if idx < pathComponents.count - 1 {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(.secondary.opacity(0.6))
                            }
                        }
                    }
                }

                if scanner.isScanningSpace {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Calculando...")
                            .font(.caption2)
                            .foregroundStyle(RamanTheme.laserCyan)
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.2))

            Divider().overlay(RamanTheme.borderSubtle)

            if scanner.spaceEntries.isEmpty && scanner.isScanningSpace {
                VStack(spacing: 14) {
                    ProgressView()
                        .scaleEffect(1.15)
                        .tint(RamanTheme.antiStokesViolet)
                    Text("Abriendo \(scanner.currentSpacePath)...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if scanner.spaceEntries.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "folder")
                        .font(.system(size: 46))
                        .foregroundStyle(.secondary)
                    Text("Sin elementos mayores a 512 KB")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(scanner.spaceEntries) { entry in
                            HStack(spacing: 14) {
                                Button {
                                    if entry.isDirectory {
                                        Task { await scanner.scanDirectory(path: entry.path) }
                                    } else {
                                        scanner.revealInFinder(path: entry.path)
                                    }
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: entry.isDirectory ? "folder.fill" : "doc.fill")
                                            .font(.title3)
                                            .foregroundStyle(entry.isDirectory ? RamanTheme.laserCyan : RamanTheme.antiStokesViolet)
                                            .frame(width: 24)

                                        VStack(alignment: .leading, spacing: 5) {
                                            HStack(spacing: 8) {
                                                Text(entry.name)
                                                    .font(.subheadline.weight(.medium))
                                                    .lineLimit(1)
                                                if entry.safety != .safe {
                                                    SafetyBadgeView(level: entry.safety)
                                                }
                                                Spacer()
                                                if entry.sizeBytes > 0 {
                                                    Text(ByteFormatter.string(from: entry.sizeBytes))
                                                        .font(.system(.subheadline, design: .rounded).monospacedDigit().bold())
                                                        .foregroundStyle(.primary)
                                                } else if scanner.isScanningSpace {
                                                    Text("...")
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                }
                                            }

                                            GeometryReader { geo in
                                                ZStack(alignment: .leading) {
                                                    Capsule()
                                                        .fill(Color.white.opacity(0.07))
                                                    Capsule()
                                                        .fill(
                                                            entry.safety == .protected
                                                                ? LinearGradient(colors: [RamanTheme.infraredRed, RamanTheme.stokesAmber], startPoint: .leading, endPoint: .trailing)
                                                                : RamanTheme.spectrumGradient
                                                        )
                                                        .frame(width: max(6, geo.size.width * entry.relativeWeight))
                                                }
                                            }
                                            .frame(height: 5)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)

                                HStack(spacing: 8) {
                                    Button {
                                        scanner.revealInFinder(path: entry.path)
                                    } label: {
                                        Image(systemName: "magnifyingglass")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .frame(width: 26, height: 26)
                                            .background(Color.white.opacity(0.06), in: Circle())
                                    }
                                    .buttonStyle(.plain)
                                    .help("Ver en Finder")

                                    if entry.safety == .protected {
                                        Image(systemName: "lock.fill")
                                            .font(.caption)
                                            .foregroundStyle(RamanTheme.infraredRed.opacity(0.8))
                                            .frame(width: 26, height: 26)
                                            .help(entry.protectionReason ?? "Protegido por seguridad")
                                    } else {
                                        Button(role: .destructive) {
                                            if entry.safety == .caution || entry.sizeBytes > 500 * 1024 * 1024 {
                                                entryPendingConfirmation = entry
                                            } else {
                                                Task { await scanner.moveToTrash(entry: entry) }
                                            }
                                        } label: {
                                            Image(systemName: "trash")
                                                .font(.caption)
                                                .foregroundStyle(RamanTheme.infraredRed)
                                                .frame(width: 26, height: 26)
                                                .background(RamanTheme.infraredRed.opacity(0.12), in: Circle())
                                        }
                                        .buttonStyle(.plain)
                                        .help("Mover al Basurero")
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
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
    }

    // MARK: - Sub-Tab 1: System Data X-Ray

    private var systemDataXRaySubView: some View {
        let totalExplained = scanner.systemDataItems.reduce(Int64(0)) { $0 + $1.sizeBytes }
        let totalCleanable = scanner.systemDataItems.filter(\.canCleanDirectly).reduce(Int64(0)) { $0 + $1.sizeBytes }

        return Group {
            if scanner.isScanningSystemData && scanner.systemDataItems.isEmpty {
                VStack(spacing: 14) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(RamanTheme.laserCyan)
                    Text("Radiografiando los 'Datos del Sistema' ocultos de macOS...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(spacing: 20) {
                            RamanPrismLogo(size: 52)

                            VStack(alignment: .leading, spacing: 5) {
                                Text("¿Por qué macOS reporta más de 100 GB en 'Datos del Sistema'?")
                                    .font(.headline)
                                Text("macOS agrupa ahí todo lo que vive fuera de carpetas estándar: juegos auto-actualizables dentro de .app (como Riot / League of Legends), paquetes Homebrew (/opt/homebrew), contenedores de IA/Docker, cachés de análisis neuronal de Fotos y directorios de código personalizados.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text(ByteFormatter.string(from: totalExplained))
                                    .font(.system(.title2, design: .rounded).monospacedDigit().bold())
                                    .foregroundStyle(RamanTheme.laserCyan)
                                Text("Purgable directo: \(ByteFormatter.string(from: totalCleanable))")
                                    .font(.caption2.bold())
                                    .foregroundStyle(RamanTheme.emeraldSafe)
                            }
                        }
                        .padding(18)
                        .background(RamanTheme.panelBg, in: RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(RamanTheme.laserCyan.opacity(0.28), lineWidth: 1)
                        )

                        ForEach(scanner.systemDataItems) { item in
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(item.safety.color.opacity(0.15))
                                        .frame(width: 38, height: 38)
                                    Image(systemName: item.safety.icon)
                                        .foregroundStyle(item.safety.color)
                                }

                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 8) {
                                        Text(item.title)
                                            .font(.subheadline.weight(.semibold))
                                        Text(item.category)
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(RamanTheme.laserCyan)
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 2)
                                            .background(RamanTheme.laserCyan.opacity(0.12), in: Capsule())
                                        SafetyBadgeView(level: item.safety)
                                    }
                                    Text(item.explanation)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(item.path)
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(.secondary.opacity(0.7))
                                        .lineLimit(1)
                                }

                                Spacer()

                                Text(ByteFormatter.string(from: item.sizeBytes))
                                    .font(.system(.callout, design: .rounded).monospacedDigit().bold())

                                Button {
                                    scanner.revealInFinder(path: item.path)
                                } label: {
                                    Image(systemName: "magnifyingglass")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 28, height: 28)
                                        .background(Color.white.opacity(0.06), in: Circle())
                                }
                                .buttonStyle(.plain)
                                .help("Ver en Finder")

                                if item.canCleanDirectly {
                                    Button {
                                        if item.safety == .caution {
                                            xrayItemPendingDelete = item
                                        } else {
                                            Task { await scanner.cleanSystemDataItem(item) }
                                        }
                                    } label: {
                                        Text("Liberar")
                                            .font(.caption.weight(.semibold))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(item.safety == .safe ? RamanTheme.emeraldSafe : RamanTheme.stokesAmber)
                                    .foregroundStyle(.black)
                                    .disabled(scanner.isExecutingOperation)
                                } else {
                                    Image(systemName: "lock.fill")
                                        .font(.caption)
                                        .foregroundStyle(.secondary.opacity(0.6))
                                        .frame(width: 64)
                                }
                            }
                            .padding(14)
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
    }
}
