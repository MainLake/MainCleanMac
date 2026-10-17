import SwiftUI

struct ContentView: View {
    @EnvironmentObject var scanner: SystemScannerService
    @State private var selectedTab: NavigationTab = .dashboard

    var body: some View {
        NavigationSplitView {
            SidebarView(selectedTab: $selectedTab)
        } detail: {
            ZStack(alignment: .bottom) {
                LinearGradient(
                    colors: [
                        Color(red: 0.07, green: 0.08, blue: 0.12),
                        Color(red: 0.10, green: 0.10, blue: 0.17)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    Group {
                        switch selectedTab {
                        case .dashboard:
                            DashboardView(selectedTab: $selectedTab)
                        case .appleSilicon:
                            AppleSiliconOptimizerView()
                        case .systemDataXRay:
                            SystemDataXRayView()
                        case .smartCaches:
                            SmartCachesView()
                        case .uninstaller:
                            AppUninstallerView()
                        case .spaceLens:
                            SpaceLensView()
                        case .devAndDocker:
                            DevAndDockerHubView()
                        case .automation:
                            AutomationSchedulerView()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if scanner.showLogDrawer {
                        ActivityLogDrawerView()
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }

                // Floating Toast Notification with Log Drawer toggle
                if let status = scanner.lastStatusMessage, !scanner.isExecutingOperation {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text(status)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Spacer()
                        Button {
                            withAnimation(.spring(duration: 0.25)) {
                                scanner.showLogDrawer.toggle()
                            }
                        } label: {
                            Text(scanner.showLogDrawer ? "Ocultar Logs" : "Ver Logs")
                                .font(.caption.bold())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.14), in: Capsule())
                        }
                        .buttonStyle(.plain)

                        Button {
                            withAnimation {
                                scanner.lastStatusMessage = nil
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.caption.bold())
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .padding(.horizontal, 24)
                    .padding(.bottom, scanner.showLogDrawer ? 200 : 18)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // In-Place Live Loader Overlay
                if scanner.isExecutingOperation {
                    ZStack {
                        Color.black.opacity(0.45)
                            .ignoresSafeArea()

                        VStack(spacing: 14) {
                            ProgressView()
                                .scaleEffect(1.3)
                                .tint(.cyan)

                            Text(scanner.currentOperationTitle)
                                .font(.headline)
                                .foregroundStyle(.white)

                            Text(scanner.currentOperationSubtitle)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .frame(maxWidth: 360)

                            Button {
                                withAnimation(.spring(duration: 0.25)) {
                                    scanner.showLogDrawer.toggle()
                                }
                            } label: {
                                Label(scanner.showLogDrawer ? "Ocultar Logs" : "Ver Logs en Vivo", systemImage: "terminal")
                                    .font(.caption.weight(.semibold))
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(26)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color.cyan.opacity(0.35), lineWidth: 1)
                        )
                        .shadow(radius: 20)
                    }
                    .transition(.opacity)
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .preferredColorScheme(.dark)
        .onAppear {
            scanner.refreshAll()
        }
    }
}

// MARK: - Clean Minimalist Sidebar

struct SidebarView: View {
    @EnvironmentObject var scanner: SystemScannerService
    @Binding var selectedTab: NavigationTab

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Brand Header
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [.cyan, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 34, height: 34)
                    Image(systemName: "waveform.path.ecg")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("RamanSweep")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Text("Adventurous M-Series")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.cyan)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)

            // Grouped Navigation Sections
            VStack(alignment: .leading, spacing: 16) {
                ForEach(NavigationSection.allCases, id: \.self) { section in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(section.rawValue)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary.opacity(0.75))
                            .padding(.horizontal, 16)
                            .padding(.bottom, 2)

                        ForEach(NavigationTab.allCases.filter { $0.section == section }) { tab in
                            Button {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    selectedTab = tab
                                }
                            } label: {
                                HStack(spacing: 11) {
                                    Image(systemName: tab.icon)
                                        .font(.system(size: 14, weight: .semibold))
                                        .frame(width: 20)
                                        .foregroundStyle(selectedTab == tab ? tab.accentColor : .secondary)

                                    Text(tab.rawValue)
                                        .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .medium))
                                        .foregroundStyle(selectedTab == tab ? .white : .primary.opacity(0.85))

                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 9)
                                        .fill(selectedTab == tab ? Color.white.opacity(0.11) : Color.clear)
                                )
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 8)
                        }
                    }
                }
            }

            Spacer()

            // Compact Activity Log Button
            Button {
                withAnimation(.spring(duration: 0.25)) {
                    scanner.showLogDrawer.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "terminal")
                        .font(.caption)
                        .foregroundStyle(.cyan)
                    Text("Actividad (\(scanner.activityLogs.count))")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: scanner.showLogDrawer ? "chevron.down" : "chevron.up")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)

            // Minimalist Disk Pill
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text("Macintosh HD")
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Text("\(ByteFormatter.string(from: scanner.diskOverview.freeBytes)) libres")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.green)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.cyan, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(8, geo.size.width * scanner.diskOverview.usedPercentage))
                    }
                }
                .frame(height: 6)
            }
            .padding(12)
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 11))
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .frame(minWidth: 215, maxWidth: 230)
    }
}

// MARK: - Smart Care Unified Dashboard

struct DashboardView: View {
    @EnvironmentObject var scanner: SystemScannerService
    @Binding var selectedTab: NavigationTab

    var totalSafeCleanableBytes: Int64 {
        let safeCaches = scanner.cacheItems.filter { $0.safety == .safe }.reduce(Int64(0)) { $0 + $1.sizeBytes }
        let orphans = scanner.orphanedLeftovers.reduce(Int64(0)) { $0 + $1.sizeBytes }
        return safeCaches + orphans
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                // Top Bar
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Smart Care")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        Text("Resumen del estado de tu Mac y acciones recomendadas en un solo lugar.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()

                    Button {
                        scanner.refreshAll()
                    } label: {
                        Label("Analizar de Nuevo", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .disabled(scanner.isExecutingOperation)
                }

                // Hero Banner Card (Clean, Focused, Uncluttered)
                HStack(spacing: 28) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.08), lineWidth: 14)
                            .frame(width: 124, height: 124)

                        Circle()
                            .trim(from: 0, to: scanner.diskOverview.usedPercentage)
                            .stroke(
                                AngularGradient(
                                    colors: [.cyan, .purple, .pink, .cyan],
                                    center: .center
                                ),
                                style: StrokeStyle(lineWidth: 14, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: 124, height: 124)

                        VStack(spacing: 1) {
                            Text(ByteFormatter.string(from: scanner.diskOverview.freeBytes))
                                .font(.system(.title3, design: .rounded).bold())
                                .foregroundStyle(.green)
                            Text("Libres")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 28) {
                            StatBlock(label: "Usado", value: ByteFormatter.string(from: scanner.diskOverview.usedBytes))
                            StatBlock(label: "Capacidad", value: ByteFormatter.string(from: scanner.diskOverview.totalBytes))
                            StatBlock(label: "Basura Segura", value: ByteFormatter.string(from: totalSafeCleanableBytes), highlight: .cyan)
                        }

                        HStack(spacing: 12) {
                            Button {
                                Task {
                                    scanner.selectOnlySafeCaches()
                                    await scanner.cleanSelectedCaches()
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "sparkles")
                                    Text("Limpieza Rápida Segura (\(ByteFormatter.string(from: scanner.totalSelectedCacheBytes)))")
                                        .fontWeight(.semibold)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.cyan)
                            .disabled(scanner.totalSelectedCacheBytes == 0 || scanner.isExecutingOperation)

                            Button {
                                selectedTab = .smartCaches
                            } label: {
                                Text("Personalizar")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    Spacer()
                }
                .padding(24)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.09), lineWidth: 1)
                )

                // Guided Recommendations Section (Integrated directly into Smart Care)
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Sugerencias para tu Mac")
                            .font(.headline)
                        Spacer()
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.shield.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                            Text("Protección activa de datos personales")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if scanner.recommendations.isEmpty {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.title2)
                                .foregroundStyle(.green)
                            Text("Todo está optimizado. No hay acciones urgentes recomendadas.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(18)
                        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))
                    } else {
                        VStack(spacing: 10) {
                            ForEach(scanner.recommendations) { rec in
                                HStack(spacing: 16) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(rec.safety.color.opacity(0.15))
                                            .frame(width: 40, height: 40)
                                        Image(systemName: rec.icon)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(rec.safety.color)
                                    }

                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack(spacing: 8) {
                                            Text(rec.title)
                                                .font(.subheadline.weight(.semibold))
                                            SafetyBadgeView(level: rec.safety)
                                        }
                                        Text(rec.reason)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }

                                    Spacer()

                                    if rec.potentialSavingsBytes > 0 {
                                        Text(ByteFormatter.string(from: rec.potentialSavingsBytes))
                                            .font(.system(.callout, design: .rounded).monospacedDigit().bold())
                                            .foregroundStyle(.cyan)
                                    }

                                    if rec.safety == .safe {
                                        Button {
                                            Task { await scanner.executeRecommendationInPlace(rec) }
                                        } label: {
                                            Text(rec.actionLabel)
                                                .font(.caption.weight(.semibold))
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 5)
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .tint(.purple)
                                        .disabled(scanner.isExecutingOperation)
                                    } else {
                                        Button {
                                            selectedTab = rec.targetTab
                                        } label: {
                                            Text(rec.actionLabel)
                                                .font(.caption.weight(.semibold))
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                }
                                .padding(14)
                                .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                )
                            }
                        }
                    }
                }
            }
            .padding(28)
        }
    }
}

struct StatBlock: View {
    let label: String
    let value: String
    var highlight: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.title3, design: .rounded).bold())
                .foregroundStyle(highlight)
        }
    }
}

// MARK: - Activity Log Drawer

struct ActivityLogDrawerView: View {
    @EnvironmentObject var scanner: SystemScannerService

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "terminal.fill")
                    .foregroundStyle(.cyan)
                Text("Consola de Actividad (\(scanner.activityLogs.count))")
                    .font(.caption.bold())
                Spacer()
                Button("Limpiar") {
                    scanner.clearLogs()
                }
                .font(.caption2)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .padding(.trailing, 8)

                Button {
                    withAnimation(.spring(duration: 0.25)) {
                        scanner.showLogDrawer = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.4))

            Divider().overlay(Color.white.opacity(0.08))

            if scanner.activityLogs.isEmpty {
                HStack {
                    Spacer()
                    Text("Sin eventos recientes en esta sesión.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(height: 150)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 5) {
                        ForEach(scanner.activityLogs) { entry in
                            HStack(alignment: .top, spacing: 8) {
                                Text(entry.timeString)
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.secondary)

                                Image(systemName: entry.level.icon)
                                    .font(.caption2)
                                    .foregroundStyle(entry.level.color)

                                Text(entry.message)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.9))

                                if let detail = entry.detail, !detail.isEmpty {
                                    Text("· \(detail)")
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 2)
                        }
                    }
                    .padding(.vertical, 6)
                }
                .frame(height: 150)
            }
        }
        .background(Color(red: 0.05, green: 0.06, blue: 0.09))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 1)
        }
    }
}
