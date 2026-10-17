import SwiftUI

struct AppUninstallerView: View {
    @EnvironmentObject var scanner: SystemScannerService
    @State private var selectedAppForUninstall: InstalledAppInfo?
    @State private var inspectedApp: InstalledAppInfo?
    @State private var searchText = ""
    @State private var mode: Int = 0 // 0 = Aplicaciones, 1 = Residuos Huérfanos

    var filteredApps: [InstalledAppInfo] {
        if searchText.isEmpty { return scanner.installedApps }
        return scanner.installedApps.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.bundleId.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Aplicaciones y Residuos")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                    Text("Desinstala aplicaciones por completo sin dejar carpetas olvidadas en tu Mac.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Picker("", selection: $mode) {
                    Text("Instaladas (\(scanner.installedApps.count))").tag(0)
                    Text("Huérfanos (\(scanner.orphanedLeftovers.count))").tag(1)
                }
                .pickerStyle(.segmented)
                .frame(width: 260)

                if mode == 0 {
                    TextField("Buscar...", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 160)
                }

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
                    Label("Permisos sin Contraseña", systemImage: "lock.open.fill")
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
                    Text("Escaneando aplicaciones instaladas y sus archivos asociados...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if mode == 0 {
                // Installed Apps Mode
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredApps) { app in
                            HStack(spacing: 14) {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: app.bundlePath))
                                    .resizable()
                                    .frame(width: 38, height: 38)

                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 8) {
                                        Text(app.name)
                                            .font(.subheadline.weight(.semibold))
                                        if app.isSystemOrProtected {
                                            SafetyBadgeView(level: .protected)
                                        } else if app.requiresAdminToTrash {
                                            Text("App Store / Admin")
                                                .font(.system(size: 9, weight: .semibold))
                                                .foregroundStyle(.orange)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.orange.opacity(0.14), in: Capsule())
                                        }
                                    }

                                    HStack(spacing: 10) {
                                        Text("App: \(ByteFormatter.string(from: app.appSizeBytes))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        if !app.leftovers.isEmpty {
                                            Button {
                                                inspectedApp = app
                                            } label: {
                                                Text("+ \(app.leftovers.count) residuos (\(ByteFormatter.string(from: app.leftoversSizeBytes)))")
                                                    .font(.caption.weight(.medium))
                                                    .foregroundStyle(.cyan)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }

                                Spacer()

                                Text(ByteFormatter.string(from: app.totalSizeBytes))
                                    .font(.system(.callout, design: .rounded).monospacedDigit().bold())
                                    .foregroundStyle(.primary)

                                if !app.isSystemOrProtected {
                                    Button(role: .destructive) {
                                        selectedAppForUninstall = app
                                    } label: {
                                        Text("Desinstalar")
                                            .font(.caption.weight(.semibold))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.red.opacity(0.85))
                                    .disabled(scanner.isExecutingOperation)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                            )
                        }
                    }
                    .padding(28)
                }
            } else {
                // Orphaned Leftovers Mode
                VStack(alignment: .leading, spacing: 0) {
                    if scanner.orphanedLeftovers.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(.green)
                            Text("Sin residuos huérfanos")
                                .font(.title3.bold())
                            Text("No se encontraron restos de aplicaciones desinstaladas anteriormente.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        HStack {
                            Text("Restos de aplicaciones que ya no están en tu carpeta Aplicaciones")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            let orphanTotal = scanner.orphanedLeftovers.filter(\.isSelected).reduce(Int64(0)) { $0 + $1.sizeBytes }
                            Button {
                                Task { await scanner.cleanSelectedOrphans() }
                            } label: {
                                Text("Limpiar Huérfanos (\(ByteFormatter.string(from: orphanTotal)))")
                                    .fontWeight(.semibold)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                            .disabled(orphanTotal == 0 || scanner.isExecutingOperation)
                        }
                        .padding(.horizontal, 28)
                        .padding(.top, 20)

                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(scanner.orphanedLeftovers) { orphan in
                                    HStack(spacing: 12) {
                                        Image(systemName: "folder.badge.minus")
                                            .foregroundStyle(.orange)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(orphan.name)
                                                .font(.subheadline.weight(.medium))
                                            Text(orphan.locationType)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
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
                                    .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))
                                }
                            }
                            .padding(28)
                        }
                    }
                }
            }
        }
        .sheet(item: $inspectedApp) { app in
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: app.bundlePath))
                        .resizable()
                        .frame(width: 32, height: 32)
                    VStack(alignment: .leading) {
                        Text("Archivos asociados de \(app.name)")
                            .font(.headline)
                        Text(app.bundleId)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Cerrar") { inspectedApp = nil }
                }
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(app.leftovers) { item in
                            HStack {
                                Text(item.kind)
                                    .font(.caption.bold())
                                    .foregroundStyle(.cyan)
                                    .frame(width: 120, alignment: .leading)
                                Text(item.path)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                Spacer()
                                Text(ByteFormatter.string(from: item.sizeBytes))
                                    .font(.caption.monospacedDigit().bold())
                            }
                        }
                    }
                }
            }
            .padding(20)
            .frame(width: 560, height: 320)
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
                if app.requiresAdminToTrash {
                    Text("Se enviará '\(app.name).app' y sus \(app.leftovers.count) residuos (\(ByteFormatter.string(from: app.totalSizeBytes))) al Basurero. macOS solicitará tu contraseña o Touch ID.")
                } else {
                    Text("Se enviará '\(app.name).app' y sus \(app.leftovers.count) carpetas asociadas (\(ByteFormatter.string(from: app.totalSizeBytes))) al Basurero.")
                }
            }
        }
    }
}
