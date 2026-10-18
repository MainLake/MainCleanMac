import SwiftUI

struct DockerManagerView: View {
    @EnvironmentObject var scanner: SystemScannerService

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Contenedores, volúmenes, imágenes y caché de compilación")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()

                Button {
                    Task { await scanner.refreshDocker() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(scanner.isScanningDocker || scanner.isCleaningDocker)

                Button {
                    Task { await scanner.pruneAllDocker() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trash.fill")
                        Text("Purgar Todo Docker")
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(!scanner.dockerStats.isDockerRunning || scanner.isCleaningDocker || scanner.isExecutingOperation)
            }
            .padding(.horizontal, 28)
            .padding(.top, 18)
            .padding(.bottom, 10)

            if scanner.isScanningDocker {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Consultando el demonio de Docker...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !scanner.dockerStats.isDockerRunning {
                VStack(spacing: 14) {
                    Image(systemName: "shippingbox.and.arrow.backward.fill")
                        .font(.system(size: 46))
                        .foregroundStyle(.orange)
                    Text("Docker no está en ejecución")
                        .font(.title3.bold())
                    Text("Abre Docker Desktop para administrar contenedores, volúmenes e imágenes.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Reintentar") {
                        Task { await scanner.refreshDocker() }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack(spacing: 14) {
                            DockerMetricBox(title: "Imágenes", value: scanner.dockerStats.imagesSize, icon: "square.stack.3d.up.fill", color: .cyan)
                            DockerMetricBox(title: "Contenedores", value: scanner.dockerStats.containersSize, icon: "cube.box.fill", color: .green)
                            DockerMetricBox(title: "Volúmenes", value: scanner.dockerStats.volumesSize, icon: "externaldrive.fill", color: .orange)
                            DockerMetricBox(title: "Build Cache", value: scanner.dockerStats.buildCacheSize, icon: "hammer.fill", color: .purple)
                        }

                        // Containers
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Contenedores (\(scanner.dockerContainers.count))")
                                .font(.headline)

                            if scanner.dockerContainers.isEmpty {
                                EmptyDockerRow(text: "Sin contenedores activos ni detenidos.")
                            } else {
                                ForEach(scanner.dockerContainers) { c in
                                    HStack {
                                        Circle()
                                            .fill(c.isRunning ? Color.green : Color.gray)
                                            .frame(width: 8, height: 8)
                                        Text(c.name)
                                            .font(.subheadline.weight(.medium))
                                        Text(c.image)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Text(c.status)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        Button(role: .destructive) {
                                            Task { await scanner.removeDockerContainer(c.id) }
                                        } label: {
                                            Image(systemName: "trash")
                                                .foregroundStyle(.red)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(12)
                                    .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }

                        // Volumes
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Volúmenes (\(scanner.dockerVolumes.count))")
                                .font(.headline)

                            if scanner.dockerVolumes.isEmpty {
                                EmptyDockerRow(text: "Sin volúmenes locales.")
                            } else {
                                ForEach(scanner.dockerVolumes) { v in
                                    HStack {
                                        Image(systemName: "internaldrive")
                                            .foregroundStyle(.orange)
                                        Text(v.name)
                                            .font(.subheadline.weight(.medium))
                                            .lineLimit(1)
                                        Spacer()
                                        Button(role: .destructive) {
                                            Task { await scanner.removeDockerVolume(v.name) }
                                        } label: {
                                            Image(systemName: "trash")
                                                .foregroundStyle(.red)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(12)
                                    .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }

                        // Images
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Imágenes (\(scanner.dockerImages.count))")
                                .font(.headline)

                            if scanner.dockerImages.isEmpty {
                                EmptyDockerRow(text: "Sin imágenes descargadas.")
                            } else {
                                ForEach(scanner.dockerImages) { img in
                                    HStack {
                                        Image(systemName: "square.stack.3d.up")
                                            .foregroundStyle(.cyan)
                                        Text("\(img.repository):\(img.tag)")
                                            .font(.subheadline.weight(.medium))
                                        Spacer()
                                        Text(img.size)
                                            .font(.subheadline.monospacedDigit().weight(.semibold))
                                        Button(role: .destructive) {
                                            Task { await scanner.removeDockerImage(img.id) }
                                        } label: {
                                            Image(systemName: "trash")
                                                .foregroundStyle(.red)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(12)
                                    .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 10)
                }
            }
        }
    }
}

struct DockerMetricBox: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.system(.title3, design: .rounded).bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct EmptyDockerRow: View {
    let text: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(12)
        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 10))
    }
}
