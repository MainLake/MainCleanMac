import SwiftUI

struct SmartCachesView: View {
    @EnvironmentObject var scanner: SystemScannerService
    @State private var showCautionAlert = false
    @State private var collapsedCategories: Set<CacheCategory> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Clean Header
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Limpieza Inteligente")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                    Text("Selecciona qué archivos temporales deseas enviar al Basurero.")
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
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .disabled(scanner.totalSelectedCacheBytes == 0 || scanner.isCleaningCaches)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 20)

            Divider().overlay(Color.white.opacity(0.07))

            if scanner.isScanningCaches && scanner.cacheItems.isEmpty {
                VStack(spacing: 14) {
                    ProgressView()
                        .scaleEffect(1.15)
                    Text("Buscando cachés y archivos temporales...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if scanner.cacheItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)
                    Text("Tu sistema está limpio")
                        .font(.title3.bold())
                    Text("No se detectaron archivos temporales pendientes por liberar.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 14) {
                        ForEach(CacheCategory.allCases, id: \.self) { category in
                            let items = scanner.cacheItems.filter { $0.category == category }
                            if !items.isEmpty {
                                CategoryAccordionCard(
                                    category: category,
                                    items: items,
                                    isExpanded: !collapsedCategories.contains(category)
                                ) {
                                    withAnimation(.spring(duration: 0.25)) {
                                        if collapsedCategories.contains(category) {
                                            collapsedCategories.remove(category)
                                        } else {
                                            collapsedCategories.insert(category)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(28)
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

struct CategoryAccordionCard: View {
    @EnvironmentObject var scanner: SystemScannerService
    let category: CacheCategory
    let items: [CleanableItem]
    let isExpanded: Bool
    let onToggleExpand: () -> Void

    var categoryTotalBytes: Int64 {
        items.reduce(0) { $0 + $1.sizeBytes }
    }

    var selectedCount: Int {
        items.filter(\.isSelected).count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Category Summary Header
            Button(action: onToggleExpand) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(category.color.opacity(0.18))
                            .frame(width: 38, height: 38)
                        Image(systemName: category.icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(category.color)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.rawValue)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("\(selectedCount) de \(items.count) seleccionados")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(ByteFormatter.string(from: categoryTotalBytes))
                        .font(.system(.callout, design: .rounded).monospacedDigit().bold())
                        .foregroundStyle(.primary)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                }
                .padding(16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expandable Items List
            if isExpanded {
                Divider().overlay(Color.white.opacity(0.06))

                VStack(spacing: 0) {
                    ForEach(items) { item in
                        CleanableRowView(item: item)
                        if item.id != items.last?.id {
                            Divider()
                                .padding(.leading, 48)
                                .overlay(Color.white.opacity(0.04))
                        }
                    }
                }
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.15))
            }
        }
        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

struct CleanableRowView: View {
    @EnvironmentObject var scanner: SystemScannerService
    let item: CleanableItem
    @State private var showInfoPopover = false

    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: Binding(
                get: { item.isSelected },
                set: { _ in scanner.toggleCacheSelection(item) }
            ))
            .toggleStyle(.checkbox)
            .labelsHidden()

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(item.name)
                        .font(.subheadline.weight(.medium))
                    SafetyBadgeView(level: item.safety)
                }
                Text(item.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(ByteFormatter.string(from: item.sizeBytes))
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(.secondary)

            Button {
                showInfoPopover.toggle()
            } label: {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showInfoPopover, arrowEdge: .trailing) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        SafetyBadgeView(level: item.safety)
                        Spacer()
                        Button("Ver en Finder") {
                            scanner.revealInFinder(path: item.path)
                        }
                        .font(.caption)
                    }
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
        .padding(.vertical, 10)
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
