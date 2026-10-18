import SwiftUI

struct DevAndDockerHubView: View {
    @EnvironmentObject var scanner: SystemScannerService
    @State private var selectedSegment: Int = 0 // 0 = Proyectos (node_modules/.venv), 1 = Docker

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Zona Desarrollador & Docker")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                    Text("Libera gigabytes en dependencias de proyectos regenerables y contenedores Docker.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Picker("", selection: $selectedSegment) {
                    Text("Artefactos de Código").tag(0)
                    Text("Docker").tag(1)
                }
                .pickerStyle(.segmented)
                .frame(width: 280)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 20)
            .onAppear {
                scanner.ensureDevAndDockerLoaded()
            }

            Divider().overlay(Color.white.opacity(0.07))

            if selectedSegment == 0 {
                ProjectArtifactsSubView()
            } else {
                DockerManagerView()
            }
        }
    }
}

struct ProjectArtifactsSubView: View {
    @EnvironmentObject var scanner: SystemScannerService

    var totalSelectedBytes: Int64 {
        scanner.projectArtifacts.filter(\.isSelected).reduce(0) { $0 + $1.sizeBytes }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Carpetas node_modules, .venv, target y .next detectadas (tu código fuente no se toca)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()

                Button {
                    Task { await scanner.scanProjectArtifacts() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(scanner.isScanningArtifacts || scanner.isExecutingOperation)

                Button {
                    Task { await scanner.cleanSelectedProjectArtifacts() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                        Text("Limpiar \(ByteFormatter.string(from: totalSelectedBytes))")
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .disabled(totalSelectedBytes == 0 || scanner.isScanningArtifacts || scanner.isExecutingOperation)
            }
            .padding(.horizontal, 28)
            .padding(.top, 18)
            .padding(.bottom, 10)

            if scanner.isScanningArtifacts && scanner.projectArtifacts.isEmpty {
                VStack(spacing: 14) {
                    ProgressView()
                    Text("Buscando carpetas de compilación y entornos virtuales...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if scanner.projectArtifacts.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)
                    Text("Sin artefactos pesados pendientes")
                        .font(.title3.bold())
                    Text("No se encontraron carpetas node_modules, .venv o target pesadas.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(scanner.projectArtifacts.indices, id: \.self) { idx in
                            let item = scanner.projectArtifacts[idx]
                            HStack(spacing: 14) {
                                Toggle("", isOn: Binding(
                                    get: { scanner.projectArtifacts[idx].isSelected },
                                    set: { scanner.projectArtifacts[idx].isSelected = $0 }
                                ))
                                .toggleStyle(.checkbox)
                                .labelsHidden()

                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 8) {
                                        Text(item.projectName)
                                            .font(.subheadline.weight(.semibold))
                                        Text(item.artifactType)
                                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                                            .foregroundStyle(.cyan)
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 2)
                                            .background(Color.cyan.opacity(0.14), in: Capsule())
                                        if item.daysSinceModified >= 7 {
                                            Text("Sin uso hace \(item.daysSinceModified)d")
                                                .font(.caption2)
                                                .foregroundStyle(.orange)
                                        }
                                    }
                                    Text(item.path)
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }

                                Spacer()

                                Text(ByteFormatter.string(from: item.sizeBytes))
                                    .font(.system(.callout, design: .rounded).monospacedDigit().bold())

                                Button {
                                    scanner.revealInFinder(path: item.path)
                                } label: {
                                    Image(systemName: "folder")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 10)
                }
            }
        }
    }
}

struct AutomationSchedulerView: View {
    @EnvironmentObject var scanner: SystemScannerService

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Automatización y Alertas")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                    Text("Mantén tu Mac limpia de forma silenciosa usando el agente nativo launchd de macOS.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Main Toggle Card
                HStack(spacing: 18) {
                    ZStack {
                        Circle()
                            .fill((scanner.isScheduleInstalled ? Color.green : Color.orange).opacity(0.16))
                            .frame(width: 52, height: 52)
                        Image(systemName: scanner.isScheduleInstalled ? "checkmark.circle.fill" : "clock.badge.exclamationmark")
                            .font(.system(size: 26))
                            .foregroundStyle(scanner.isScheduleInstalled ? .green : .orange)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(scanner.isScheduleInstalled ? "Mantenimiento Periódico Activo" : "Mantenimiento Periódico Inactivo")
                            .font(.headline)
                        Text("Limpia únicamente cachés 100% seguras (navegadores, gestores de paquetes y logs) sin tocar tus archivos personales.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if scanner.isScheduleInstalled {
                        Button(role: .destructive) {
                            scanner.removeSchedule()
                        } label: {
                            Text("Desactivar")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(20)
                .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )

                // Frequency Selector Card
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Frecuencia de Limpieza")
                            .font(.headline)
                        Spacer()
                        Picker("", selection: $scanner.selectedFrequency) {
                            ForEach(ScheduleFrequency.allCases) { freq in
                                Text(freq.rawValue).tag(freq)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 260)
                    }

                    HStack {
                        Text("Agente: ~/Library/LaunchAgents/com.mainlake.ramansweep.periodic.plist")
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            scanner.installOrUpdateSchedule()
                        } label: {
                            Text(scanner.isScheduleInstalled ? "Guardar Frecuencia" : "Activar Programación")
                                .fontWeight(.semibold)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.cyan)
                    }
                }
                .padding(20)
                .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )

                // Low Space Alert Threshold Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "bell.badge.fill")
                            .foregroundStyle(.purple)
                        Text("Umbral de Alerta de Espacio Libre")
                            .font(.headline)
                        Spacer()
                        Text("\(Int(scanner.lowSpaceAlertThresholdGB)) GB")
                            .font(.system(.headline, design: .rounded).monospacedDigit())
                            .foregroundStyle(.cyan)
                    }

                    Slider(value: $scanner.lowSpaceAlertThresholdGB, in: 10...80, step: 5)
                        .tint(.purple)

                    let currentFreeGB = Double(scanner.diskOverview.freeBytes) / 1_000_000_000
                    HStack(spacing: 6) {
                        Image(systemName: currentFreeGB < scanner.lowSpaceAlertThresholdGB ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                            .foregroundStyle(currentFreeGB < scanner.lowSpaceAlertThresholdGB ? .orange : .green)
                        Text(
                            currentFreeGB < scanner.lowSpaceAlertThresholdGB
                                ? "Tienes \(String(format: "%.1f", currentFreeGB)) GB libres (por debajo de tu meta de \(Int(scanner.lowSpaceAlertThresholdGB)) GB)."
                                : "Tienes \(String(format: "%.1f", currentFreeGB)) GB libres, superando tu umbral saludable."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(20)
                .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
            }
            .padding(28)
        }
    }
}
