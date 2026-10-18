import SwiftUI
import AppKit

struct AppUninstallerView: View {
    @EnvironmentObject var scanner: SystemScannerService
    @State private var selectedApp: InstalledAppInfo?
    @State private var selectedAppForUninstall: InstalledAppInfo?
    @State private var searchText = ""
    @State private var mode: Int = 0 // 0 = Aplicaciones Instaladas, 1 = Residuos Huérfanos

    var filteredApps: [InstalledAppInfo] {
        if searchText.isEmpty { return scanner.installedApps }
        return scanner.installedApps.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.bundleId.localizedCaseInsensitiveContains(searchText)
        }
    }

    var activeInspectedApp: InstalledAppInfo? {
        if let sel = selectedApp, filteredApps.contains(where: { $0.id == sel.id }) {
            return sel
        }
        return filteredApps.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top Lens Header
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 10) {
                        Text("Desinstalador")
                            .font(.system(size: 24, weight: .bold))
                        Text("APPS Y RESTOS DE DESINSTALACIÓN")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(MainCleanTheme.crimsonDanger)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(MainCleanTheme.crimsonDanger.opacity(0.14), in: Capsule())
                    }
                    Text("Desinstala aplicaciones junto con sus carpetas ocultas o elimina restos de programas que ya borraste antes.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Picker("", selection: $mode) {
                    Text("Apps Instaladas (\(scanner.installedApps.count))").tag(0)
                    Text("Restos Huérfanos (\(scanner.orphanedLeftovers.count))").tag(1)
                }
                .pickerStyle(.segmented)
                .frame(width: 300)

                Menu {
                    Button {
                        scanner.openAppManagementSettings()
                    } label: {
                        Label("Abrir 'Administración de aplicaciones'", systemImage: "app.badge.checkmark")
                    }
                    Button {
                        scanner.openFullDiskAccessSettings()
                    } label: {
                        Label("Abrir 'Acceso total al disco'", systemImage: "externaldrive.badge.checkmark")
                    }
                } label: {
                    Label("Permisos TCC", systemImage: "lock.open.fill")
                        .font(.caption.weight(.semibold))
                }
                .menuStyle(.borderedButton)
                .fixedSize()
                .help("Activa Administración de aplicaciones y Acceso total al disco (como Pearcleaner) para borrar apps de App Store sin pedir contraseña.")

                Button {
                    Task { await scanner.scanInstalledApps() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(scanner.isScanningApps || scanner.isExecutingOperation)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 20)
            .onAppear {
                scanner.ensureAppsLoaded()
            }

            Divider().overlay(Color.white.opacity(0.07))

            if scanner.isScanningApps && scanner.installedApps.isEmpty {
                VStack(spacing: 14) {
                    ProgressView()
                        .scaleEffect(1.15)
                        .tint(RamanTheme.laserCyan)
                    Text("Rastreando aplicaciones en /Applications y sus residuos en ~/Library...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if mode == 0 {
                // Master-Detail Split Layout for Applications
                HStack(spacing: 0) {
                    // Left Column: Search + App List
                    VStack(spacing: 0) {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                            TextField("Filtrar aplicación...", text: $searchText)
                                .textFieldStyle(.plain)
                                .font(.subheadline)
                            if !searchText.isEmpty {
                                Button {
                                    searchText = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(10)
                        .background(RamanTheme.panelBg, in: RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(RamanTheme.borderSubtle, lineWidth: 1)
                        )
                        .padding(14)

                        Divider().overlay(RamanTheme.borderSubtle)

                        ScrollView {
                            LazyVStack(spacing: 6) {
                                ForEach(filteredApps) { app in
                                    let isSelected = activeInspectedApp?.id == app.id
                                    Button {
                                        selectedApp = app
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image(nsImage: NSWorkspace.shared.icon(forFile: app.bundlePath))
                                                .resizable()
                                                .frame(width: 34, height: 34)

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(app.name)
                                                    .font(.system(size: 13, weight: isSelected ? .bold : .medium, design: .rounded))
                                                    .foregroundStyle(.white)
                                                    .lineLimit(1)

                                                Text("\(app.leftovers.count) residuos · \(ByteFormatter.string(from: app.leftoversSizeBytes))")
                                                    .font(.caption2)
                                                    .foregroundStyle(app.leftovers.isEmpty ? .secondary : RamanTheme.laserCyan)
                                            }

                                            Spacer()

                                            Text(ByteFormatter.string(from: app.totalSizeBytes))
                                                .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
                                                .foregroundStyle(isSelected ? .white : .secondary)
                                        }
                                        .padding(10)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(
                                            RoundedRectangle(cornerRadius: 11)
                                                .fill(isSelected ? RamanTheme.panelBg : Color.clear)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 11)
                                                .stroke(isSelected ? RamanTheme.laserCyan.opacity(0.45) : Color.clear, lineWidth: 1)
                                        )
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(12)
                        }
                    }
                    .frame(width: 320)
                    .background(Color.black.opacity(0.16))

                    Rectangle()
                        .fill(RamanTheme.borderSubtle)
                        .frame(width: 1)

                    // Right Column: Full App Inspector & Leftover Breakdown
                    if let app = activeInspectedApp {
                        VStack(alignment: .leading, spacing: 20) {
                            // App Hero Card
                            HStack(spacing: 18) {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: app.bundlePath))
                                    .resizable()
                                    .frame(width: 64, height: 64)

                                VStack(alignment: .leading, spacing: 5) {
                                    HStack(spacing: 8) {
                                        Text(app.name)
                                            .font(.system(size: 22, weight: .bold, design: .rounded))
                                        if app.isSystemOrProtected {
                                            SafetyBadgeView(level: .protected)
                                        } else if app.requiresAdminToTrash {
                                            Text("App Store / Root")
                                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                                .foregroundStyle(RamanTheme.stokesAmber)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 2)
                                                .background(RamanTheme.stokesAmber.opacity(0.15), in: Capsule())
                                        }
                                    }

                                    Text(app.bundleId)
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)

                                    HStack(spacing: 16) {
                                        Label("Paquete .app: \(ByteFormatter.string(from: app.appSizeBytes))", systemImage: "app.fill")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Label("Residuos en ~/Library: \(ByteFormatter.string(from: app.leftoversSizeBytes))", systemImage: "folder.fill.badge.gearshape")
                                            .font(.caption)
                                            .foregroundStyle(RamanTheme.laserCyan)
                                    }
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 8) {
                                    Text(ByteFormatter.string(from: app.totalSizeBytes))
                                        .font(.system(size: 24, weight: .black, design: .rounded).monospacedDigit())
                                        .foregroundStyle(.white)

                                    if !app.isSystemOrProtected {
                                        Button(role: .destructive) {
                                            selectedAppForUninstall = app
                                        } label: {
                                            HStack(spacing: 6) {
                                                Image(systemName: "trash.fill")
                                                Text("Desinstalar Completo")
                                                    .fontWeight(.bold)
                                            }
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 7)
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .tint(RamanTheme.infraredRed)
                                        .disabled(scanner.isExecutingOperation)
                                    }
                                }
                            }
                            .padding(20)
                            .background(RamanTheme.panelBg, in: RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(RamanTheme.borderSubtle, lineWidth: 1)
                            )

                            // Associated Files & Leftovers List
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("MAPA DE ARCHIVOS QUE SE ELIMINARÁN (\(app.leftovers.count + 1) RUTAS)")
                                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Button("Ver .app en Finder") {
                                        scanner.revealInFinder(path: app.bundlePath)
                                    }
                                    .font(.caption)
                                    .buttonStyle(.link)
                                }

                                ScrollView {
                                    VStack(spacing: 8) {
                                        // Main Bundle Row
                                        HStack(spacing: 12) {
                                            Text("EJECUTABLE")
                                                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                                .foregroundStyle(RamanTheme.emeraldSafe)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 3)
                                                .background(RamanTheme.emeraldSafe.opacity(0.14), in: Capsule())
                                                .frame(width: 115, alignment: .leading)

                                            Text(app.bundlePath)
                                                .font(.caption.monospaced())
                                                .foregroundStyle(.white)
                                                .lineLimit(1)

                                            Spacer()

                                            Text(ByteFormatter.string(from: app.appSizeBytes))
                                                .font(.caption.monospacedDigit().bold())
                                        }
                                        .padding(12)
                                        .background(RamanTheme.panelBg, in: RoundedRectangle(cornerRadius: 10))

                                        ForEach(app.leftovers) { item in
                                            HStack(spacing: 12) {
                                                Text(item.kind.uppercased())
                                                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                                    .foregroundStyle(RamanTheme.laserCyan)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 3)
                                                    .background(RamanTheme.laserCyan.opacity(0.14), in: Capsule())
                                                    .frame(width: 115, alignment: .leading)

                                                Text(item.path)
                                                    .font(.caption.monospaced())
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(1)

                                                Spacer()

                                                Text(ByteFormatter.string(from: item.sizeBytes))
                                                    .font(.caption.monospacedDigit().bold())
                                                    .foregroundStyle(.secondary)

                                                Button {
                                                    scanner.revealInFinder(path: item.path)
                                                } label: {
                                                    Image(systemName: "folder")
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                }
                                                .buttonStyle(.plain)
                                            }
                                            .padding(12)
                                            .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 10))
                                        }
                                    }
                                }
                            }
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    } else {
                        VStack {
                            Text("Selecciona una aplicación")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            } else {
                // Orphaned Leftovers Mode
                VStack(alignment: .leading, spacing: 0) {
                    if scanner.orphanedLeftovers.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(RamanTheme.emeraldSafe)
                            Text("Sin residuos huérfanos")
                                .font(.title3.bold())
                            Text("No se encontraron restos de aplicaciones desinstaladas anteriormente.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        HStack {
                            Text("Restos en ~/Library de aplicaciones que ya no existen en /Applications")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            let orphanTotal = scanner.orphanedLeftovers.filter(\.isSelected).reduce(Int64(0)) { $0 + $1.sizeBytes }
                            Button {
                                Task { await scanner.cleanSelectedOrphans() }
                            } label: {
                                Text("Limpiar Huérfanos (\(ByteFormatter.string(from: orphanTotal)))")
                                    .fontWeight(.bold)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(RamanTheme.stokesAmber)
                            .foregroundStyle(.black)
                            .disabled(orphanTotal == 0 || scanner.isExecutingOperation)
                        }
                        .padding(.horizontal, 28)
                        .padding(.top, 20)

                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(scanner.orphanedLeftovers) { orphan in
                                    HStack(spacing: 12) {
                                        Image(systemName: "folder.badge.minus")
                                            .foregroundStyle(RamanTheme.stokesAmber)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(orphan.name)
                                                .font(.subheadline.weight(.medium))
                                            Text("\(orphan.locationType) · \(orphan.path)")
                                                .font(.caption.monospaced())
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                        Text(ByteFormatter.string(from: orphan.sizeBytes))
                                            .font(.subheadline.monospacedDigit().weight(.semibold))
                                        Button {
                                            scanner.revealInFinder(path: orphan.path)
                                        } label: {
                                            Image(systemName: "folder")
                                                .foregroundStyle(.secondary)
                                        }
                                        .buttonStyle(.plain)
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
        .alert(
            "Desinstalar \(selectedAppForUninstall?.name ?? "")",
            isPresented: Binding(
                get: { selectedAppForUninstall != nil },
                set: { if !$0 { selectedAppForUninstall = nil } }
            )
        ) {
            Button("Cancelar", role: .cancel) {
                selectedAppForUninstall = nil
            }
            Button("Mover al Basurero", role: .destructive) {
                if let app = selectedAppForUninstall {
                    Task { await scanner.uninstallAppCompletely(app) }
                }
                selectedAppForUninstall = nil
            }
        } message: {
            if let app = selectedAppForUninstall {
                Text("Se enviará '\(app.name).app' y sus \(app.leftovers.count) carpetas asociadas (\(ByteFormatter.string(from: app.totalSizeBytes))) al Basurero.")
            }
        }
    }
}
