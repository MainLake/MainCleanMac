import SwiftUI

struct SpaceLensView: View {
    @EnvironmentObject var scanner: SystemScannerService
    // 0 = Cirugía Profunda (Accionable en Rutas Protegidas)
    // 1 = Rayos X: Datos del Sistema
    // 2 = Mapa de Carpetas (con navegación e inspección dentro de rutas raíz)
    @State private var selectedMode: Int = 0
    @State private var selectedSurgicalCategory: SurgicalCategory = .appSupportSurgery
    @State private var entryPendingConfirmation: SpaceEntry?
    @State private var xrayItemPendingDelete: SystemDataXRayItem?
    @State private var surgicalItemPendingDelete: SurgicalPurgeItem?

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

    var activeSurgicalCategories: [SurgicalCategory] {
        SurgicalCategory.allCases.filter { cat in
            !scanner.surgicalItems.filter { $0.category == cat }.isEmpty
        }
    }

    var currentSurgicalItems: [SurgicalPurgeItem] {
        let items = scanner.surgicalItems.filter { $0.category == selectedSurgicalCategory }
        if !items.isEmpty { return items }
        if let first = activeSurgicalCategories.first {
            return scanner.surgicalItems.filter { $0.category == first }
        }
        return []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top Lens Header
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 10) {
                        Text("Explorador de Disco")
                            .font(.system(size: 24, weight: .bold))
                        Text("DATOS DEL SISTEMA Y CARPETAS")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(MainCleanTheme.accentIndigo)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(MainCleanTheme.accentIndigo.opacity(0.16), in: Capsule())
                    }
                    Text(
                        selectedMode == 0
                            ? "Limpia subcarpetas pesadas dentro de Application Support, apps fantasmas y carpetas ocultas sin perder tus sesiones."
                            : (selectedMode == 1
                                ? "Desglose exacto de qué está ocupando espacio dentro de 'Datos del Sistema' en tu Mac."
                                : "Navegador de carpetas por tamaño: entra en cualquier ruta para inspeccionar y enviar al Basurero lo que no uses.")
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Picker("", selection: $selectedMode) {
                    Text("Limpieza Interna (\(scanner.surgicalItems.count))").tag(0)
                    Text("Datos del Sistema").tag(1)
                    Text("Navegar Carpetas").tag(2)
                }
                .pickerStyle(.segmented)
                .frame(width: 450)

                Button {
                    Task {
                        if selectedMode == 0 {
                            await scanner.scanSurgicalTargets()
                        } else if selectedMode == 1 {
                            await scanner.scanSystemDataXRay()
                        } else {
                            await scanner.scanDirectory(path: scanner.currentSpacePath, forceRefresh: true)
                        }
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .help("Reescanear")
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 20)
            .onAppear {
                scanner.ensureSurgicalLoaded()
                scanner.ensureSpaceLensLoaded()
                scanner.ensureSystemDataLoaded()
            }

            Divider().overlay(Color.white.opacity(0.07))

            if selectedMode == 0 {
                surgicalDeepCleanerSubView
            } else if selectedMode == 1 {
                systemDataXRaySubView
            } else {
                folderExplorerSubView
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
        .alert(
            "Confirmar Cirugía: \(surgicalItemPendingDelete?.title ?? "")",
            isPresented: Binding(
                get: { surgicalItemPendingDelete != nil },
                set: { if !$0 { surgicalItemPendingDelete = nil } }
            )
        ) {
            Button("Cancelar", role: .cancel) {
                surgicalItemPendingDelete = nil
            }
            Button("Purgar Ahora", role: .destructive) {
                if let item = surgicalItemPendingDelete {
                    Task { await scanner.cleanSurgicalItem(item) }
                }
                surgicalItemPendingDelete = nil
            }
        } message: {
            if let item = surgicalItemPendingDelete {
                Text("\(item.whatIsPreserved)\n\nEspacio a liberar: \(ByteFormatter.string(from: item.sizeBytes))")
            }
        }
    }

    // MARK: - Sub-Tab 0: Surgical Deep Cleaner (Safe Cleaning Inside Protected Folders)

    private var surgicalDeepCleanerSubView: some View {
        let totalFoundBytes = scanner.surgicalItems.reduce(Int64(0)) { $0 + $1.sizeBytes }

        return Group {
            if scanner.isScanningSurgical && scanner.surgicalItems.isEmpty {
                VStack(spacing: 14) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(RamanTheme.laserCyan)
                    Text("Inspeccionando el interior de ~/Library/Application Support, versiones antiguas y dotfiles ocultos...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if scanner.surgicalItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(RamanTheme.emeraldSafe)
                    Text("Cirugía al día")
                        .font(.title3.bold())
                    Text("No se detectaron residuos internos ni instalaciones fantasmas pendientes.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    // Action Banner
                    HStack(spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(RamanTheme.laserCyan.opacity(0.16))
                                .frame(width: 40, height: 40)
                            Image(systemName: "scissors")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(RamanTheme.laserCyan)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Detectados \(ByteFormatter.string(from: totalFoundBytes)) ocultos dentro de carpetas del sistema y usuario")
                                .font(.headline)
                            Text("A diferencia de un explorador pasivo, aquí puedes extraer solo la basura interna (Crashpad, GPUCache, Service Workers, apps ya borradas, instaladores atorados y videos 4K) conservando tus inicios de sesión.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button {
                            Task { await scanner.cleanAllSelectedSurgicalItems() }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "scissors")
                                Text("Ejecutar Cirugía (\(ByteFormatter.string(from: scanner.totalSelectedSurgicalBytes)))")
                                    .fontWeight(.bold)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(RamanTheme.stokesAmber)
                        .foregroundStyle(.black)
                        .disabled(scanner.totalSelectedSurgicalBytes == 0 || scanner.isExecutingOperation)
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 16)
                    .background(Color.black.opacity(0.22))

                    Divider().overlay(RamanTheme.borderSubtle)

                    // 2-Column Split View: Left = 5 Surgical Categories, Right = Items
                    HStack(spacing: 0) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("LENTES DE CIRUGÍA")
                                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.bottom, 4)

                                ForEach(SurgicalCategory.allCases, id: \.self) { cat in
                                    let items = scanner.surgicalItems.filter { $0.category == cat }
                                    if !items.isEmpty {
                                        let catBytes = items.reduce(Int64(0)) { $0 + $1.sizeBytes }
                                        let isCurrent = selectedSurgicalCategory == cat || (!activeSurgicalCategories.contains(selectedSurgicalCategory) && activeSurgicalCategories.first == cat)

                                        Button {
                                            selectedSurgicalCategory = cat
                                        } label: {
                                            HStack(spacing: 12) {
                                                ZStack {
                                                    RoundedRectangle(cornerRadius: 9)
                                                        .fill(cat.color.opacity(isCurrent ? 0.24 : 0.12))
                                                        .frame(width: 34, height: 34)
                                                    Image(systemName: cat.icon)
                                                        .font(.system(size: 14, weight: .semibold))
                                                        .foregroundStyle(cat.color)
                                                }

                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(cat.rawValue)
                                                        .font(.system(size: 12, weight: isCurrent ? .bold : .medium, design: .rounded))
                                                        .foregroundStyle(.white)
                                                        .lineLimit(2)
                                                    Text("\(items.count) objetivos")
                                                        .font(.caption2)
                                                        .foregroundStyle(.secondary)
                                                }

                                                Spacer()

                                                Text(ByteFormatter.string(from: catBytes))
                                                    .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
                                                    .foregroundStyle(isCurrent ? cat.color : .secondary)
                                            }
                                            .padding(11)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(isCurrent ? RamanTheme.panelBg : Color.white.opacity(0.025))
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(isCurrent ? cat.color.opacity(0.45) : RamanTheme.borderSubtle, lineWidth: 1)
                                            )
                                            .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .padding(18)
                        }
                        .frame(width: 315)
                        .background(Color.black.opacity(0.16))

                        Rectangle()
                            .fill(RamanTheme.borderSubtle)
                            .frame(width: 1)

                        ScrollView {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(currentSurgicalItems) { item in
                                    HStack(spacing: 14) {
                                        Toggle("", isOn: Binding(
                                            get: { item.isSelected },
                                            set: { _ in scanner.toggleSurgicalSelection(item) }
                                        ))
                                        .toggleStyle(.checkbox)
                                        .labelsHidden()

                                        Button {
                                            scanner.toggleSurgicalSelection(item)
                                        } label: {
                                            HStack {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    HStack(spacing: 8) {
                                                        Text(item.title)
                                                            .font(.subheadline.weight(.bold))
                                                        SafetyBadgeView(level: item.safety)
                                                    }
                                                    HStack(spacing: 6) {
                                                        Image(systemName: "checkmark.shield.fill")
                                                            .font(.caption2)
                                                            .foregroundStyle(RamanTheme.emeraldSafe)
                                                        Text(item.whatIsPreserved)
                                                            .font(.caption)
                                                            .foregroundStyle(RamanTheme.emeraldSafe.opacity(0.9))
                                                    }
                                                    Text(item.path)
                                                        .font(.system(size: 10, design: .monospaced))
                                                        .foregroundStyle(.secondary.opacity(0.7))
                                                        .lineLimit(1)
                                                }
                                                Spacer()
                                            }
                                            .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)

                                        Text(ByteFormatter.string(from: item.sizeBytes))
                                            .font(.system(.callout, design: .rounded).monospacedDigit().bold())
                                            .foregroundStyle(RamanTheme.laserCyan)

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

                                        Button {
                                            if item.safety == .caution {
                                                surgicalItemPendingDelete = item
                                            } else {
                                                Task { await scanner.cleanSurgicalItem(item) }
                                            }
                                        } label: {
                                            Text("Purgar")
                                                .font(.caption.weight(.bold))
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
                                            .stroke(item.isSelected ? RamanTheme.laserCyan.opacity(0.3) : RamanTheme.borderSubtle, lineWidth: 1)
                                    )
                                }
                            }
                            .padding(24)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Sub-Tab 1: System Data X-Ray (Every item is actionable!)

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
                                Text("Radiografía Accionable de 'Datos del Sistema'")
                                    .font(.headline)
                                Text("Ninguna fila es un callejón sin salida: puedes liberar directamente los cachés/instaladores o hacer clic en 'Inspeccionar Interior' para entrar a cualquier carpeta protegida y borrar subcarpetas específicas.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text(ByteFormatter.string(from: totalExplained))
                                    .font(.system(.title2, design: .rounded).monospacedDigit().bold())
                                    .foregroundStyle(RamanTheme.laserCyan)
                                Text("Liberable directo: \(ByteFormatter.string(from: totalCleanable))")
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
                                    // Instead of a dead-end lock icon, let the user drill into this folder in the Explorer!
                                    Button {
                                        selectedMode = 2
                                        Task { await scanner.scanDirectory(path: item.path) }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "folder.badge.gearshape")
                                            Text("Abrir Interior")
                                        }
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 5)
                                    }
                                    .buttonStyle(.bordered)
                                    .help("Entrar a esta carpeta para elegir qué subcarpetas eliminar")
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

    // MARK: - Sub-Tab 2: Unlocked Folder Explorer

    private var folderExplorerSubView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Navigation Shortcuts + Breadcrumbs
            HStack(spacing: 10) {
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
                        Label("Inicio", systemImage: "house")
                            .font(.caption.weight(.medium))
                    }

                    Button {
                        let appSupp = "\(FileManager.default.homeDirectoryForCurrentUser.path)/Library/Application Support"
                        Task { await scanner.scanDirectory(path: appSupp) }
                    } label: {
                        Label("App Support", systemImage: "folder.badge.gearshape")
                            .font(.caption.weight(.medium))
                    }

                    Button {
                        let containers = "\(FileManager.default.homeDirectoryForCurrentUser.path)/Library/Containers"
                        Task { await scanner.scanDirectory(path: containers) }
                    } label: {
                        Label("Containers", systemImage: "shippingbox")
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
                    Text("Sin elementos mayores a 100 KB")
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
                                        if entry.isDirectory {
                                            Button {
                                                Task { await scanner.scanDirectory(path: entry.path) }
                                            } label: {
                                                HStack(spacing: 4) {
                                                    Image(systemName: "arrow.right.circle.fill")
                                                    Text("Entrar")
                                                }
                                                .font(.caption2.bold())
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(RamanTheme.laserCyan.opacity(0.15), in: Capsule())
                                                .foregroundStyle(RamanTheme.laserCyan)
                                            }
                                            .buttonStyle(.plain)
                                            .help(entry.protectionReason ?? "Haz clic para entrar y limpiar subcarpetas específicas")
                                        } else {
                                            Image(systemName: "lock.fill")
                                                .font(.caption)
                                                .foregroundStyle(RamanTheme.infraredRed.opacity(0.8))
                                                .frame(width: 26, height: 26)
                                                .help(entry.protectionReason ?? "Protegido por seguridad")
                                        }
                                    } else {
                                        Button(role: .destructive) {
                                            if entry.safety == .caution || entry.sizeBytes > 250 * 1024 * 1024 {
                                                entryPendingConfirmation = entry
                                            } else {
                                                Task { await scanner.moveToTrash(entry: entry) }
                                            }
                                        } label: {
                                            HStack(spacing: 4) {
                                                Image(systemName: "trash.fill")
                                                Text("Eliminar")
                                            }
                                            .font(.caption2.bold())
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(RamanTheme.infraredRed.opacity(0.85), in: Capsule())
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
}
