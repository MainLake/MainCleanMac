import SwiftUI

struct SystemDataXRayItem: Identifiable, Hashable {
    var id: String { path }
    let title: String
    let category: String
    let explanation: String
    let path: String
    let sizeBytes: Int64
    let safety: SafetyLevel
    let canCleanDirectly: Bool
    var customAction: String? = nil
}

struct SystemDataXRayView: View {
    @EnvironmentObject var scanner: SystemScannerService
    @State private var itemPendingDelete: SystemDataXRayItem?

    var totalExplainedBytes: Int64 {
        scanner.systemDataItems.reduce(0) { $0 + $1.sizeBytes }
    }

    var totalCleanableBytes: Int64 {
        scanner.systemDataItems.filter(\.canCleanDirectly).reduce(0) { $0 + $1.sizeBytes }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 10) {
                        Text("Rayos X: Datos del Sistema")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                        Text("EXCLUSIVO")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(.cyan)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.cyan.opacity(0.15), in: Capsule())
                    }
                    Text("Descubre qué hay realmente dentro de la caja negra de 'Datos del sistema' de macOS y qué puedes liberar sin peligro.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    Task { await scanner.scanSystemDataXRay() }
                } label: {
                    Label("Reescanear Rayos X", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(scanner.isScanningSystemData || scanner.isExecutingOperation)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 20)
            .onAppear {
                scanner.ensureSystemDataLoaded()
            }

            Divider().overlay(Color.white.opacity(0.07))

            if scanner.isScanningSystemData && scanner.systemDataItems.isEmpty {
                VStack(spacing: 14) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Desglosando los 'Datos del sistema' ocultos de macOS...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Explanation Card: Why macOS says 110 GB
                        HStack(spacing: 20) {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(colors: [.cyan, .purple], startPoint: .topLeading, endPoint: .bottomTrailing).opacity(0.2))
                                    .frame(width: 60, height: 60)
                                Image(systemName: "waveform.path.ecg.rectangle.fill")
                                    .font(.system(size: 26))
                                    .foregroundStyle(.cyan)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("¿Por qué macOS muestra más de 100 GB en 'Datos del sistema'?")
                                    .font(.headline)
                                Text("Apple mete en 'Datos del sistema' todo lo que no está en tus carpetas estándar: incluye juegos con actualizador propio (como League of Legends de 38 GB que vive dentro de su paquete .app), Homebrew (/opt/homebrew), contenedores de IA/Docker, cachés de análisis de fotos de Apple y tus carpetas personalizadas fuera de Documents (como ~/main).")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text(ByteFormatter.string(from: totalExplainedBytes))
                                    .font(.system(.title2, design: .rounded).monospacedDigit().bold())
                                    .foregroundStyle(.cyan)
                                Text("Identificados")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(18)
                        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.cyan.opacity(0.25), lineWidth: 1)
                        )

                        // Breakdown List
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Desglose Real de tus 'Datos del Sistema'")
                                    .font(.headline)
                                Spacer()
                                Text("Liberable de forma directa: \(ByteFormatter.string(from: totalCleanableBytes))")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.green)
                            }

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
                                                .foregroundStyle(.cyan)
                                                .padding(.horizontal, 7)
                                                .padding(.vertical, 2)
                                                .background(Color.cyan.opacity(0.12), in: Capsule())
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
                                                itemPendingDelete = item
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
                                        .tint(item.safety == .safe ? .green : .orange)
                                        .disabled(scanner.isExecutingOperation)
                                    } else {
                                        Image(systemName: "lock.fill")
                                            .font(.caption)
                                            .foregroundStyle(.secondary.opacity(0.6))
                                            .frame(width: 64)
                                            .help("Parte activa de macOS o de tus repositorios de código")
                                    }
                                }
                                .padding(14)
                                .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                )
                            }
                        }
                    }
                    .padding(28)
                }
            }
        }
        .alert(
            "¿Liberar '\(itemPendingDelete?.title ?? "")'?",
            isPresented: Binding(
                get: { itemPendingDelete != nil },
                set: { if !$0 { itemPendingDelete = nil } }
            )
        ) {
            Button("Cancelar", role: .cancel) {
                itemPendingDelete = nil
            }
            Button("Sí, Liberar Espacio", role: .destructive) {
                if let item = itemPendingDelete {
                    Task { await scanner.cleanSystemDataItem(item) }
                }
                itemPendingDelete = nil
            }
        } message: {
            if let item = itemPendingDelete {
                Text("\(item.explanation)\n\nEspacio a recuperar: \(ByteFormatter.string(from: item.sizeBytes))")
            }
        }
    }
}
