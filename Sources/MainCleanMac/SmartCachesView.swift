import SwiftUI

struct SmartCachesView: View {
    @EnvironmentObject var scanner: SystemScannerService
    @State private var showCautionAlert = false
    @State private var selectedCategory: CacheCategory = .systemAndGeneral

    var categoriesWithItems: [CacheCategory] {
        CacheCategory.allCases.filter { cat in
            !scanner.cacheItems.filter { $0.category == cat }.isEmpty
        }
    }

    var activeItems: [CleanableItem] {
        let filtered = scanner.cacheItems.filter { $0.category == selectedCategory }
        if !filtered.isEmpty { return filtered }
        if let firstCat = categoriesWithItems.first {
            return scanner.cacheItems.filter { $0.category == firstCat }
        }
        return []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top Lens Header
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 10) {
                        Text(scanner.isAdvancedMode ? "Cachés y Paquetes" : "Archivos Temporales")
                            .font(.system(size: 24, weight: .bold))
                        if scanner.isAdvancedMode {
                            Text("TEMPORALES Y PAQUETES")
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundStyle(MainCleanTheme.accentBlue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(MainCleanTheme.accentBlue.opacity(0.14), in: Capsule())
                        }
                    }
                    Text(
                        scanner.isAdvancedMode
                            ? "Elimina cachés regenerables de navegadores, gestores de paquetes y registros sin cerrar tus sesiones."
                            : "Archivos temporales que tus programas guardan mientras los usas. Puedes borrarlos con total tranquilidad."
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Menu {
                    Button {
                        scanner.selectOnlySafeCaches()
                    } label: {
                        Label("Seleccionar solo Seguros", systemImage: "checkmark.shield")
                    }
                    Divider()
                    Toggle("Enviar al Basurero (Modo Seguro)", isOn: $scanner.safeModeTrashOnly)
                } label: {
                    Label(scanner.safeModeTrashOnly ? "Modo Papelera" : "Borrado Directo", systemImage: "shield.lefthalf.filled")
                        .font(.caption.weight(.semibold))
                }
                .menuStyle(.borderedButton)
                .fixedSize()

                Button {
                    Task { await scanner.scanCaches() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(scanner.isScanningCaches || scanner.isCleaningCaches)
                .help("Reescanear")

                Button {
                    if scanner.selectedCautionItemsCount > 0 {
                        showCautionAlert = true
                    } else {
                        Task { await scanner.cleanSelectedCaches() }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                        Text("Limpiar \(ByteFormatter.string(from: scanner.totalSelectedCacheBytes))")
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                }
                .buttonStyle(.borderedProminent)
                .tint(MainCleanTheme.emeraldSafe)
                .foregroundStyle(Color(red: 0.03, green: 0.12, blue: 0.08))
                .disabled(scanner.totalSelectedCacheBytes == 0 || scanner.isCleaningCaches)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 20)

            Divider().overlay(Color.white.opacity(0.07))

            if scanner.isScanningCaches && scanner.cacheItems.isEmpty {
                VStack(spacing: 14) {
                    ProgressView()
                        .scaleEffect(1.15)
                        .tint(MainCleanTheme.accentBlue)
                    Text("Analizando cachés y archivos temporales en tu Mac...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if scanner.cacheItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(MainCleanTheme.emeraldSafe)
                    Text("Cachés Optimizadas")
                        .font(.title3.bold())
                    Text("No se detectaron archivos temporales pendientes por liberar.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Clean 2-Column Split Layout: Left = Category Selector, Right = Items in Selected Category
                HStack(spacing: 0) {
                    // Left Column: Categories
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("CATEGORÍAS")
                                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.bottom, 4)

                            ForEach(CacheCategory.allCases, id: \.self) { category in
                                let items = scanner.cacheItems.filter { $0.category == category }
                                if !items.isEmpty {
                                    let catBytes = items.reduce(Int64(0)) { $0 + $1.sizeBytes }
                                    let selectedCount = items.filter(\.isSelected).count
                                    let isCurrent = selectedCategory == category || (!categoriesWithItems.contains(selectedCategory) && categoriesWithItems.first == category)

                                    Button {
                                        selectedCategory = category
                                    } label: {
                                        HStack(spacing: 12) {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 9)
                                                    .fill(category.color.opacity(isCurrent ? 0.24 : 0.12))
                                                    .frame(width: 34, height: 34)
                                                Image(systemName: category.icon)
                                                    .font(.system(size: 14, weight: .semibold))
                                                    .foregroundStyle(category.color)
                                            }

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(category.rawValue)
                                                    .font(.system(size: 13, weight: isCurrent ? .bold : .medium, design: .rounded))
                                                    .foregroundStyle(.white)
                                                    .lineLimit(1)
                                                Text("\(selectedCount)/\(items.count) marcados")
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }

                                            Spacer()

                                            Text(ByteFormatter.string(from: catBytes))
                                                .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
                                                .foregroundStyle(isCurrent ? RamanTheme.stokesAmber : .secondary)
                                        }
                                        .padding(11)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(isCurrent ? RamanTheme.panelBg : Color.white.opacity(0.025))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(isCurrent ? category.color.opacity(0.45) : RamanTheme.borderSubtle, lineWidth: 1)
                                        )
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(20)
                    }
                    .frame(width: 285)
                    .background(Color.black.opacity(0.16))

                    Rectangle()
                        .fill(RamanTheme.borderSubtle)
                        .frame(width: 1)

                    // Right Column: Focused Item List for Selected Category
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(selectedCategory.rawValue.uppercased())
                                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                                    .foregroundStyle(selectedCategory.color)
                                Spacer()
                                Text("\(activeItems.count) elementos")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.bottom, 4)

                            ForEach(activeItems) { item in
                                CleanableRowView(item: item)
                            }
                        }
                        .padding(24)
                    }
                }
            }
        }
        .alert("Confirmar elementos marcados para Revisar", isPresented: $showCautionAlert) {
            Button("Cancelar", role: .cancel) {}
            Button("Limpiar solo Seguros") {
                scanner.selectOnlySafeCaches()
                Task { await scanner.cleanSelectedCaches() }
            }
            Button("Continuar con Todo", role: .destructive) {
                Task { await scanner.cleanSelectedCaches() }
            }
        } message: {
            Text("Incluiste \(scanner.selectedCautionItemsCount) elemento(s) con etiqueta 'Revisar' (como la Papelera o paquetes que requerirían volver a descargarse). ¿Deseas continuar?")
        }
    }
}

struct CleanableRowView: View {
    @EnvironmentObject var scanner: SystemScannerService
    let item: CleanableItem
    @State private var showInfoPopover = false

    var body: some View {
        HStack(spacing: 14) {
            Toggle("", isOn: Binding(
                get: { item.isSelected },
                set: { _ in scanner.toggleCacheSelection(item) }
            ))
            .toggleStyle(.checkbox)
            .labelsHidden()

            Button {
                scanner.toggleCacheSelection(item)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(item.name)
                                .font(.subheadline.weight(.semibold))
                            SafetyBadgeView(level: item.safety)
                        }
                        Text(item.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        if scanner.isAdvancedMode {
                            Text(item.path)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary.opacity(0.65))
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text(ByteFormatter.string(from: item.sizeBytes))
                .font(.system(.callout, design: .rounded).monospacedDigit().bold())
                .foregroundStyle(item.isSelected ? .white : .secondary)

            Button {
                scanner.revealInFinder(path: item.path)
            } label: {
                Image(systemName: "folder")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: 26)
                    .background(Color.white.opacity(0.05), in: Circle())
            }
            .buttonStyle(.plain)
            .help("Ver en Finder")

            Button {
                showInfoPopover.toggle()
            } label: {
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: 26)
                    .background(Color.white.opacity(0.05), in: Circle())
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showInfoPopover, arrowEdge: .trailing) {
                VStack(alignment: .leading, spacing: 8) {
                    SafetyBadgeView(level: item.safety)
                    Text(item.impactNote)
                        .font(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(item.path)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .frame(width: 290)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(RamanTheme.panelBg, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(item.isSelected ? RamanTheme.stokesAmber.opacity(0.28) : RamanTheme.borderSubtle, lineWidth: 1)
        )
    }
}

struct SafetyBadgeView: View {
    let level: SafetyLevel

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(level.color)
                .frame(width: 6, height: 6)
            Text(level.rawValue)
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(level.color)
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .background(level.color.opacity(0.12), in: Capsule())
    }
}
