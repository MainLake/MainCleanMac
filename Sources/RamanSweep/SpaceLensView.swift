import SwiftUI

struct SpaceLensView: View {
    @EnvironmentObject var scanner: SystemScannerService
    @State private var entryPendingConfirmation: SpaceEntry?

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
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 10) {
                        Text("Explorador de Espacio")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                        if scanner.isScanningSpace {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Calculando pesos...")
                                    .font(.caption)
                                    .foregroundStyle(.cyan)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.cyan.opacity(0.12), in: Capsule())
                        }
                    }
                    Text("Navegación instantánea en memoria. Los archivos críticos tienen candado de seguridad.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 8) {
                    Button {
                        Task { await scanner.scanDirectory(path: "/") }
                    } label: {
                        Label("Disco (/)", systemImage: "internaldrive")
                    }

                    Button {
                        let home = FileManager.default.homeDirectoryForCurrentUser.path
                        Task { await scanner.scanDirectory(path: home) }
                    } label: {
                        Label("Inicio", systemImage: "house")
                    }

                    Button {
                        Task { await scanner.scanDirectory(path: "/Applications") }
                    } label: {
                        Label("Apps", systemImage: "square.grid.2x2")
                    }

                    Button {
                        let parent = (scanner.currentSpacePath as NSString).deletingLastPathComponent
                        if !parent.isEmpty {
                            Task { await scanner.scanDirectory(path: parent) }
                        }
                    } label: {
                        Label("Subir", systemImage: "arrow.up")
                    }
                    .disabled(scanner.currentSpacePath == "/")

                    Button {
                        Task { await scanner.scanDirectory(path: scanner.currentSpacePath, forceRefresh: true) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("Recalcular tamaños de esta carpeta")
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 20)
            .onAppear {
                scanner.ensureSpaceLensLoaded()
            }

            // Interactive Breadcrumb Bar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(pathComponents.enumerated()), id: \.offset) { idx, comp in
                        Button {
                            Task { await scanner.scanDirectory(path: comp.fullPath) }
                        } label: {
                            HStack(spacing: 4) {
                                if idx == 0 {
                                    Image(systemName: "internaldrive.fill")
                                        .foregroundStyle(.cyan)
                                }
                                Text(comp.name == "/" ? "Macintosh HD" : comp.name)
                                    .font(.caption.weight(idx == pathComponents.count - 1 ? .bold : .medium))
                                    .foregroundStyle(idx == pathComponents.count - 1 ? .white : .secondary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(idx == pathComponents.count - 1 ? 0.12 : 0.04), in: Capsule())
                        }
                        .buttonStyle(.plain)

                        if idx < pathComponents.count - 1 {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.secondary.opacity(0.6))
                        }
                    }
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 8)
            }
            .background(Color.black.opacity(0.18))

            Divider().overlay(Color.white.opacity(0.07))

            if scanner.spaceEntries.isEmpty && scanner.isScanningSpace {
                VStack(spacing: 14) {
                    ProgressView()
                        .scaleEffect(1.15)
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
                                            .foregroundStyle(entry.isDirectory ? .cyan : .purple)
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
                                                            LinearGradient(
                                                                colors: entry.safety == .protected ? [.red, .orange] : [.cyan, .purple],
                                                                startPoint: .leading,
                                                                endPoint: .trailing
                                                            )
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
                                            .foregroundStyle(.red.opacity(0.75))
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
                                                .foregroundStyle(.red.opacity(0.85))
                                                .frame(width: 26, height: 26)
                                                .background(Color.red.opacity(0.1), in: Circle())
                                        }
                                        .buttonStyle(.plain)
                                        .help("Mover al Basurero")
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(28)
                }
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
    }
}
