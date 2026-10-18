import SwiftUI

struct ContentView: View {
    @EnvironmentObject var scanner: SystemScannerService
    @State private var selectedTab: NavigationTab = .dashboard

    var body: some View {
        HStack(spacing: 0) {
            // Left Navigation Sidebar
            MainCleanSidebar(selectedTab: $selectedTab)

            // 1px Subtle Vertical Border
            Rectangle()
                .fill(MainCleanTheme.borderSubtle)
                .frame(width: 1)

            // Main Canvas with Global Top Bar (Modo Simple vs Modo Avanzado)
            VStack(spacing: 0) {
                // Global Header Bar with Mode Switcher & Live Hardware Telemetry
                MainCleanTopBar(selectedTab: $selectedTab)

                Rectangle()
                    .fill(MainCleanTheme.borderSubtle)
                    .frame(height: 1)

                // Top Content Area (Operation Overlay only covers this area, never the bottom Log Drawer)
                ZStack(alignment: .bottomTrailing) {
                    MainCleanTheme.canvasBg
                        .ignoresSafeArea()

                    Group {
                        switch selectedTab {
                        case .dashboard:
                            DashboardView(selectedTab: $selectedTab)
                        case .smartCaches:
                            SmartCachesView()
                        case .uninstaller:
                            AppUninstallerView()
                        case .spaceLens:
                            SpaceLensView()
                        case .appleSilicon:
                            AppleSiliconOptimizerView()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // Real-Time Operation Overlay (confined to the main view, leaving the bottom log drawer 100% scrollable & clickable)
                    if scanner.isExecutingOperation {
                        ZStack {
                            Color.black.opacity(0.45)

                            VStack(spacing: 12) {
                                ProgressView()
                                    .scaleEffect(1.15)
                                    .tint(MainCleanTheme.emeraldSafe)

                                Text(scanner.currentOperationTitle)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)

                                Text(scanner.currentOperationSubtitle)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .frame(maxWidth: 420)

                                Button {
                                    withAnimation(.spring(duration: 0.25)) {
                                        scanner.showLogDrawer.toggle()
                                    }
                                } label: {
                                    Label(scanner.showLogDrawer ? "Ocultar Registro Inferior" : "Abrir Registro en Tiempo Real", systemImage: "terminal")
                                        .font(.caption.weight(.medium))
                                }
                                .buttonStyle(.bordered)
                            }
                            .padding(22)
                            .background(MainCleanTheme.panelBg, in: RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(MainCleanTheme.borderStrong, lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.45), radius: 20)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.opacity)
                    }

                    // Timed Toast Notification (4s auto-dismiss with countdown bar)
                    if let status = scanner.lastStatusMessage, !scanner.isExecutingOperation {
                        TimedToastNotificationView(
                            message: status,
                            toastId: scanner.toastId,
                            showLogDrawer: $scanner.showLogDrawer,
                            onDismiss: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    scanner.lastStatusMessage = nil
                                }
                            }
                        )
                        .padding(.trailing, 24)
                        .padding(.bottom, 18)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Bottom Log Drawer: Completely outside the operation overlay so you can always scroll, click, and inspect logs in real time
                if scanner.showLogDrawer {
                    ActivityLogDrawerView()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            scanner.refreshAll()
        }
    }
}

// MARK: - Top Header Bar (Modo Simple vs Modo Avanzado Pro Toggle)

struct MainCleanTopBar: View {
    @EnvironmentObject var scanner: SystemScannerService
    @Binding var selectedTab: NavigationTab

    var body: some View {
        HStack(spacing: 14) {
            // Simple vs Advanced Pill Switcher
            HStack(spacing: 4) {
                Button {
                    withAnimation(.spring(duration: 0.22)) {
                        scanner.isAdvancedMode = false
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Modo Simple")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(!scanner.isAdvancedMode ? .white : .secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(!scanner.isAdvancedMode ? MainCleanTheme.brandBlue : Color.clear)
                    )
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation(.spring(duration: 0.22)) {
                        scanner.isAdvancedMode = true
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Modo Avanzado (Pro)")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(scanner.isAdvancedMode ? .white : .secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(scanner.isAdvancedMode ? MainCleanTheme.brandBlue : Color.clear)
                    )
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(3)
            .background(MainCleanTheme.panelBg, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(MainCleanTheme.borderSubtle, lineWidth: 1)
            )

            if scanner.isAdvancedMode {
                HStack(spacing: 8) {
                    Text("\(scanner.mSeriesStatus.chipName) · \(scanner.mSeriesStatus.physicalRAMGB) GB")
                    if scanner.mSeriesStatus.swapUsedBytes > 0 {
                        Text("· Swap \(ByteFormatter.string(from: scanner.mSeriesStatus.swapUsedBytes))")
                    }
                    if scanner.mSeriesStatus.localSnapshotsCount > 0 {
                        Text("· \(scanner.mSeriesStatus.localSnapshotsCount) Snapshots")
                    }
                }
                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(MainCleanTheme.panelBg, in: Capsule())
                .overlay(Capsule().stroke(MainCleanTheme.borderSubtle, lineWidth: 1))
                .transition(.opacity)
            }

            Spacer()

            if scanner.isAdvancedMode {
                Button {
                    withAnimation(.spring(duration: 0.25)) {
                        scanner.showLogDrawer.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "terminal")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Consola (\(scanner.activityLogs.count))")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(MainCleanTheme.panelBg, in: Capsule())
                    .overlay(Capsule().stroke(MainCleanTheme.borderSubtle, lineWidth: 1))
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            Button {
                scanner.refreshAll()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Actualizar")
                        .font(.system(size: 11.5, weight: .medium))
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .background(MainCleanTheme.panelBg, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(MainCleanTheme.borderSubtle, lineWidth: 1))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(scanner.isExecutingOperation)
        }
        .padding(.horizontal, 28)
        .frame(height: 52)
        .background(MainCleanTheme.canvasBg)
    }
}

// MARK: - Timed Toast Notification with 4-Second Progress Bar

struct TimedToastNotificationView: View {
    let message: String
    let toastId: UUID
    @Binding var showLogDrawer: Bool
    let onDismiss: () -> Void

    @State private var progress: CGFloat = 1.0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(MainCleanTheme.emeraldSafe)

                Text(message)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Button {
                    withAnimation(.spring(duration: 0.25)) {
                        showLogDrawer.toggle()
                    }
                } label: {
                    Text(showLogDrawer ? "Ocultar" : "Registro")
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .padding(5)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            // 4-second visual countdown bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.white.opacity(0.05))
                    Rectangle()
                        .fill(MainCleanTheme.emeraldSafe)
                        .frame(width: max(0, geo.size.width * progress))
                }
            }
            .frame(height: 2)
        }
        .frame(width: 400)
        .background(Color(red: 0.11, green: 0.13, blue: 0.16).opacity(0.97))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(MainCleanTheme.emeraldSafe.opacity(0.32), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.45), radius: 14, y: 5)
        .onAppear {
            progress = 1.0
            withAnimation(.linear(duration: 4.0)) {
                progress = 0.0
            }
        }
        .onChange(of: toastId) { _, _ in
            progress = 1.0
            withAnimation(.linear(duration: 4.0)) {
                progress = 0.0
            }
        }
    }
}

// MARK: - MainCleanMac Sidebar

struct MainCleanSidebar: View {
    @EnvironmentObject var scanner: SystemScannerService
    @Binding var selectedTab: NavigationTab

    var primaryTabs: [NavigationTab] {
        if scanner.isAdvancedMode {
            return [.dashboard, .smartCaches, .uninstaller, .spaceLens, .appleSilicon]
        } else {
            return [.dashboard, .uninstaller, .spaceLens, .smartCaches, .appleSilicon]
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // App Brand Header
            HStack(spacing: 10) {
                MainCleanLogo(size: 32)
                Text("MainCleanMac")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)

            // Navigation Items
            VStack(alignment: .leading, spacing: 4) {
                ForEach(primaryTabs) { tab in
                    let isSelected = selectedTab == tab
                    if tab == .appleSilicon && !scanner.isAdvancedMode {
                        Divider()
                            .overlay(Color.white.opacity(0.06))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 4)
                    }

                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedTab = tab
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(isSelected ? tab.accentColor : .secondary)
                                .frame(width: 20)

                            Text(tab.displayTitle(isAdvanced: scanner.isAdvancedMode))
                                .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                                .foregroundStyle(isSelected ? .white : .primary.opacity(0.82))

                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 9)
                                .fill(isSelected ? MainCleanTheme.hoverBg : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 9)
                                .stroke(isSelected ? MainCleanTheme.borderStrong : Color.clear, lineWidth: 1)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 12)
                }
            }

            Spacer()

            // Activity Log Toggle
            Button {
                withAnimation(.spring(duration: 0.25)) {
                    scanner.showLogDrawer.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "terminal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Registro (\(scanner.activityLogs.count))")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: scanner.showLogDrawer ? "chevron.down" : "chevron.up")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 9))
                .overlay(
                    RoundedRectangle(cornerRadius: 9)
                        .stroke(MainCleanTheme.borderSubtle, lineWidth: 1)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)

            // Live Free Space Widget in Sidebar
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("DISCO")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(ByteFormatter.string(from: scanner.diskOverview.freeBytes)) libres")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(MainCleanTheme.emeraldSafe)
                        .contentTransition(.numericText())
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                        Capsule()
                            .fill(MainCleanTheme.emeraldSafe)
                            .frame(width: max(8, geo.size.width * (1.0 - scanner.diskOverview.usedPercentage)))
                    }
                }
                .frame(height: 6)

                HStack {
                    Text("\(ByteFormatter.string(from: scanner.diskOverview.usedBytes)) / \(ByteFormatter.string(from: scanner.diskOverview.totalBytes))")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if scanner.sessionFreedBytes > 0 {
                        Text("+\(ByteFormatter.string(from: scanner.sessionFreedBytes))")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(MainCleanTheme.emeraldSafe)
                    }
                }
            }
            .padding(14)
            .background(MainCleanTheme.panelBg, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(MainCleanTheme.borderSubtle, lineWidth: 1)
            )
            .padding(.horizontal, 14)
            .padding(.bottom, 16)
        }
        .frame(width: 235)
        .background(MainCleanTheme.sidebarBg)
    }
}

// MARK: - Screen 1: Inicio

struct DashboardView: View {
    @EnvironmentObject var scanner: SystemScannerService
    @Binding var selectedTab: NavigationTab
    @State private var showQuickTechDetails = false
    @State private var showDeepTechDetails = false

    var totalReclaimableBytes: Int64 {
        scanner.quickSafeCleanableBytes + scanner.deepSystemCleanableBytes
    }

    var totalAppsBytes: Int64 {
        let apps = scanner.installedApps.reduce(Int64(0)) { $0 + $1.totalSizeBytes }
        return apps > 0 ? apps : 18_000_000_000
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                // 1. Storage Card
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .center, spacing: 20) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Text(ByteFormatter.string(from: scanner.diskOverview.freeBytes))
                                        .font(.system(size: 40, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                        .contentTransition(.numericText())
                                    Text("disponibles")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundStyle(.secondary)
                                }

                                if scanner.sessionFreedBytes > 0 {
                                    Text("+\(ByteFormatter.string(from: scanner.sessionFreedBytes)) liberados")
                                        .font(.system(size: 11.5, weight: .bold))
                                        .foregroundStyle(MainCleanTheme.emeraldSafe)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(MainCleanTheme.emeraldSafe.opacity(0.14), in: Capsule())
                                }
                            }

                            Text("\(ByteFormatter.string(from: scanner.diskOverview.usedBytes)) en uso de \(ByteFormatter.string(from: scanner.diskOverview.totalBytes)) · \(ByteFormatter.string(from: totalReclaimableBytes)) por liberar")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if !scanner.isAdvancedMode {
                            VStack(alignment: .leading, spacing: 6) {
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule()
                                            .fill(MainCleanTheme.canvasBg)
                                        Capsule()
                                            .fill(MainCleanTheme.brandBlue)
                                            .frame(width: max(12, geo.size.width * scanner.diskOverview.usedPercentage))
                                    }
                                    .overlay(Capsule().stroke(MainCleanTheme.borderSubtle, lineWidth: 1))
                                }
                                .frame(width: 220, height: 10)

                                HStack {
                                    Text("Usado \(Int(scanner.diskOverview.usedPercentage * 100))%")
                                    Spacer()
                                    Text("Libre \(Int((1.0 - scanner.diskOverview.usedPercentage) * 100))%")
                                        .foregroundStyle(MainCleanTheme.emeraldSafe)
                                }
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundStyle(.secondary)
                                .frame(width: 220)
                            }
                        }
                    }

                    if scanner.isAdvancedMode {
                        Divider().overlay(MainCleanTheme.borderSubtle)
                        MainCleanStorageBar(
                            totalBytes: scanner.diskOverview.totalBytes,
                            usedBytes: scanner.diskOverview.usedBytes,
                            reclaimableBytes: totalReclaimableBytes,
                            appsBytes: totalAppsBytes
                        )
                    }
                }
                .padding(24)
                .background(MainCleanTheme.panelBg, in: RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(MainCleanTheme.borderSubtle, lineWidth: 1)
                )

                // 2. Two Action Cards
                HStack(alignment: .top, spacing: 18) {
                    // Card 1: Limpieza Rápida
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .center, spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 11)
                                    .fill(MainCleanTheme.emeraldSafe.opacity(0.12))
                                    .frame(width: 40, height: 40)
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(MainCleanTheme.emeraldSafe)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Limpieza Rápida")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(.white)
                                Text("Cachés, archivos temporales y registros")
                                    .font(.system(size: 12.5))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Button {
                                withAnimation(.spring(duration: 0.2)) {
                                    showQuickTechDetails.toggle()
                                }
                            } label: {
                                HStack(spacing: 5) {
                                    Text(scanner.isAdvancedMode || showQuickTechDetails ? "Ocultar detalle" : "Ver detalle")
                                        .font(.system(size: 12, weight: .medium))
                                    Image(systemName: (scanner.isAdvancedMode || showQuickTechDetails) ? "chevron.up" : "chevron.down")
                                        .font(.system(size: 9.5, weight: .bold))
                                }
                                .foregroundStyle(MainCleanTheme.emeraldSafe)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if scanner.isAdvancedMode || showQuickTechDetails {
                                VStack(alignment: .leading, spacing: 6) {
                                    QuickBreakdownRow(
                                        label: "Cachés de navegadores y sistema",
                                        bytes: scanner.cacheItems.filter { $0.safety == .safe && ($0.category == .systemAndGeneral || $0.category == .browsersAndApps || $0.category == .xcodeAndSimulators) }.reduce(0) { $0 + $1.sizeBytes }
                                    )
                                    QuickBreakdownRow(
                                        label: "Temporales de apps (GoogleUpdater, GPUCache, Crashpad)",
                                        bytes: scanner.surgicalItems.filter { $0.safety == .safe && $0.category == .appSupportSurgery && !$0.path.contains("com.docker.install") }.reduce(0) { $0 + $1.sizeBytes }
                                    )
                                    QuickBreakdownRow(
                                        label: "Bases SQLite y vistas previas",
                                        bytes: scanner.mSeriesItems.filter { $0.safety == .safe && ($0.kind == .sqliteVacuum || $0.kind == .binaryArchitecture || $0.actionCode == "QL_RESET") }.reduce(0) { $0 + $1.sizeBytes }
                                    )

                                    Button {
                                        selectedTab = .smartCaches
                                    } label: {
                                        Text("Elegir elementos →")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(MainCleanTheme.brandBlue)
                                            .padding(.top, 2)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(12)
                                .background(MainCleanTheme.canvasBg.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(MainCleanTheme.borderSubtle, lineWidth: 1))
                            }
                        }

                        Spacer(minLength: 2)

                        Button {
                            Task {
                                await scanner.runQuickSafeCleanup()
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: scanner.quickSafeCleanableBytes > 0 ? "sparkles" : "checkmark.circle.fill")
                                Text(scanner.quickSafeCleanableBytes > 0
                                     ? "Limpiar \(ByteFormatter.string(from: scanner.quickSafeCleanableBytes))"
                                     : "Cachés Seguras Limpias")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(MainCleanTheme.emeraldSafe)
                        .foregroundStyle(Color(red: 0.03, green: 0.12, blue: 0.08))
                        .disabled(scanner.isExecutingOperation || scanner.quickSafeCleanableBytes <= 0)
                    }
                    .padding(22)
                    .frame(maxWidth: .infinity)
                    .background(MainCleanTheme.panelBg, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(MainCleanTheme.emeraldSafe.opacity(0.22), lineWidth: 1)
                    )

                    // Card 2: Limpieza Profunda
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .center, spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 11)
                                    .fill(MainCleanTheme.amberCaution.opacity(0.12))
                                    .frame(width: 40, height: 40)
                                Image(systemName: "internaldrive.fill")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(MainCleanTheme.amberCaution)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Limpieza Profunda")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(.white)
                                Text("Instaladores antiguos, paquetes y restos de apps")
                                    .font(.system(size: 12.5))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 14) {
                                Button {
                                    withAnimation(.spring(duration: 0.2)) {
                                        showDeepTechDetails.toggle()
                                    }
                                } label: {
                                    HStack(spacing: 5) {
                                        Text(scanner.isAdvancedMode || showDeepTechDetails ? "Ocultar detalle" : "Ver detalle")
                                            .font(.system(size: 12, weight: .medium))
                                        Image(systemName: (scanner.isAdvancedMode || showDeepTechDetails) ? "chevron.up" : "chevron.down")
                                            .font(.system(size: 9.5, weight: .bold))
                                    }
                                    .foregroundStyle(MainCleanTheme.amberCaution)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)

                                Button {
                                    selectedTab = .spaceLens
                                } label: {
                                    Text("Revisar uno por uno →")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.secondary)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }

                            if scanner.isAdvancedMode || showDeepTechDetails {
                                VStack(alignment: .leading, spacing: 6) {
                                    QuickBreakdownRow(
                                        label: "Instaladores y apps desinstaladas",
                                        bytes: scanner.surgicalItems.filter { $0.safety == .safe && ($0.path.contains("com.docker.install") || $0.category == .orphanedAppsData) }.reduce(0) { $0 + $1.sizeBytes }
                                    )
                                    QuickBreakdownRow(
                                        label: "Paquetes (Homebrew, npm, pnpm, uv, Cargo)",
                                        bytes: scanner.cacheItems.filter { $0.safety == .safe && ($0.category == .packageManagers || $0.category == .aiAndDevTools) }.reduce(0) { $0 + $1.sizeBytes }
                                    )
                                    QuickBreakdownRow(
                                        label: "Videos 4K de macOS y carpetas ocultas",
                                        bytes: scanner.surgicalItems.filter { $0.safety == .safe && ($0.category == .macOSWallpaperAndMedia || $0.category == .hiddenDotfileBloat) }.reduce(0) { $0 + $1.sizeBytes }
                                    )
                                }
                                .padding(12)
                                .background(MainCleanTheme.canvasBg.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(MainCleanTheme.borderSubtle, lineWidth: 1))
                            }
                        }

                        Spacer(minLength: 2)

                        Button {
                            Task {
                                await scanner.runDeepSystemCleanup()
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: scanner.deepSystemCleanableBytes > 0 ? "flame.fill" : "checkmark.circle.fill")
                                Text(scanner.deepSystemCleanableBytes > 0
                                     ? "Liberar \(ByteFormatter.string(from: scanner.deepSystemCleanableBytes))"
                                     : "Datos del Sistema Optimizados")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(MainCleanTheme.amberCaution)
                        .foregroundStyle(Color(red: 0.12, green: 0.07, blue: 0.01))
                        .disabled(scanner.isExecutingOperation || scanner.deepSystemCleanableBytes <= 0)
                    }
                    .padding(22)
                    .frame(maxWidth: .infinity)
                    .background(MainCleanTheme.panelBg, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(MainCleanTheme.amberCaution.opacity(0.22), lineWidth: 1)
                    )
                }

                // 3. Pro Quick Cards
                if scanner.isAdvancedMode {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ], spacing: 12) {
                        ModuleSummaryCard(
                            title: "Cachés",
                            subtitle: "",
                            metric: ByteFormatter.string(from: scanner.totalSelectedCacheBytes),
                            detail: "\(scanner.cacheItems.count) elementos",
                            icon: "sparkles.rectangle.stack.fill",
                            accent: MainCleanTheme.accentBlue
                        ) {
                            selectedTab = .smartCaches
                        }

                        ModuleSummaryCard(
                            title: "Aplicaciones",
                            subtitle: "",
                            metric: "\(scanner.installedApps.count) Apps",
                            detail: "\(scanner.orphanedLeftovers.count) restos",
                            icon: "trash",
                            accent: MainCleanTheme.crimsonDanger
                        ) {
                            selectedTab = .uninstaller
                        }

                        ModuleSummaryCard(
                            title: "Disco",
                            subtitle: "",
                            metric: ByteFormatter.string(from: scanner.totalSelectedSurgicalBytes),
                            detail: "\(scanner.surgicalItems.count) objetivos",
                            icon: "folder",
                            accent: MainCleanTheme.accentIndigo
                        ) {
                            selectedTab = .spaceLens
                        }

                        ModuleSummaryCard(
                            title: "Desarrollo",
                            subtitle: "",
                            metric: ByteFormatter.string(from: scanner.projectArtifacts.reduce(0) { $0 + $1.sizeBytes }),
                            detail: "\(scanner.projectArtifacts.count) proyectos",
                            icon: "terminal.fill",
                            accent: MainCleanTheme.emeraldSafe
                        ) {
                            selectedTab = .appleSilicon
                        }
                    }
                    .transition(.opacity)
                }

                // 4. Automatic Schedule Row
                HStack(spacing: 14) {
                    Image(systemName: "clock.arrow.2.circlepath")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(scanner.isScheduleInstalled ? MainCleanTheme.emeraldSafe : .secondary)

                    Text("Limpieza automática")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(.white)

                    if scanner.isAdvancedMode {
                        Text(scanner.launchAgentPath)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    if scanner.isAdvancedMode {
                        Picker("", selection: $scanner.selectedFrequency) {
                            ForEach(ScheduleFrequency.allCases) { freq in
                                Text(freq.rawValue).tag(freq)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 190)
                        .onChange(of: scanner.selectedFrequency) { _, _ in
                            if scanner.isScheduleInstalled {
                                scanner.installOrUpdateSchedule()
                            }
                        }
                    }

                    Toggle("", isOn: Binding(
                        get: { scanner.isScheduleInstalled },
                        set: { newValue in
                            if newValue {
                                scanner.installOrUpdateSchedule()
                            } else {
                                scanner.removeSchedule()
                            }
                        }
                    ))
                    .toggleStyle(.switch)
                    .tint(MainCleanTheme.brandBlue)
                    .labelsHidden()
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(MainCleanTheme.panelBg, in: RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(MainCleanTheme.borderSubtle, lineWidth: 1)
                )
            }
            .padding(28)
        }
    }
}

struct QuickBreakdownRow: View {
    let label: String
    let bytes: Int64

    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 11))
                .foregroundStyle(MainCleanTheme.emeraldSafe)
            Text(label)
                .font(.system(size: 11.5))
                .foregroundStyle(.white.opacity(0.88))
                .lineLimit(1)
            Spacer()
            Text(ByteFormatter.string(from: bytes))
                .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }
}

struct ModuleSummaryCard: View {
    let title: String
    let subtitle: String
    let metric: String
    let detail: String
    let icon: String
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(accent)
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

                Text(metric)
                    .font(.system(size: 17, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MainCleanTheme.panelBg, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(MainCleanTheme.borderSubtle, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Activity Log Drawer (100% Interactive & Auto-Scrolling in Real Time)

struct ActivityLogDrawerView: View {
    @EnvironmentObject var scanner: SystemScannerService
    @State private var autoFollowLatest: Bool = true
    @State private var isExpandedHeight: Bool = false

    // Chronological order (oldest at top, newest at bottom) so terminal streaming feels natural
    var chronologicalLogs: [ActivityLogEntry] {
        scanner.activityLogs.reversed()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Drawer Header Bar
            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(scanner.isExecutingOperation ? MainCleanTheme.emeraldSafe : MainCleanTheme.accentBlue)
                        .frame(width: 7, height: 7)
                    Image(systemName: "terminal")
                        .font(.caption)
                        .foregroundStyle(MainCleanTheme.accentBlue)
                    Text("REGISTRO DE ACTIVIDAD EN TIEMPO REAL (\(scanner.activityLogs.count))")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                }

                if scanner.isExecutingOperation {
                    Text("· EJECUTANDO EN VIVO")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(MainCleanTheme.emeraldSafe)
                }

                Spacer()

                // Auto-Follow Toggle Button
                Button {
                    autoFollowLatest.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: autoFollowLatest ? "arrow.down.to.line.compact" : "hand.raised.fill")
                            .font(.system(size: 9, weight: .bold))
                        Text(autoFollowLatest ? "Auto-Scroll Activo" : "Scroll Libre")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(autoFollowLatest ? MainCleanTheme.emeraldSafe : .secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.06), in: Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Activa o pausa el seguimiento automático cuando haces scroll manual")

                // Expand / Compact Drawer Height
                Button {
                    withAnimation(.spring(duration: 0.2)) {
                        isExpandedHeight.toggle()
                    }
                } label: {
                    Image(systemName: isExpandedHeight ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(isExpandedHeight ? "Reducir altura del registro" : "Ampliar altura del registro")

                Button("Limpiar") {
                    scanner.clearLogs()
                }
                .font(.caption2)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

                Button {
                    withAnimation(.spring(duration: 0.25)) {
                        scanner.showLogDrawer = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .padding(2)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.4))

            Divider().overlay(MainCleanTheme.borderSubtle)

            if chronologicalLogs.isEmpty {
                HStack {
                    Spacer()
                    Text("Sin eventos registrados en esta sesión.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(height: isExpandedHeight ? 260 : 160)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 5) {
                            ForEach(chronologicalLogs) { entry in
                                HStack(alignment: .top, spacing: 8) {
                                    Text(entry.timeString)
                                        .font(.system(size: 10.5, design: .monospaced))
                                        .foregroundStyle(.secondary)

                                    Image(systemName: entry.level.icon)
                                        .font(.system(size: 10.5))
                                        .foregroundStyle(entry.level.color)

                                    Text(entry.message)
                                        .font(.system(size: 11.5, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.92))
                                        .textSelection(.enabled)

                                    if let detail = entry.detail, !detail.isEmpty {
                                        Text("· \(detail)")
                                            .font(.system(size: 10.5, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                            .textSelection(.enabled)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 2)
                                .id(entry.id)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .frame(height: isExpandedHeight ? 260 : 160)
                    .onAppear {
                        if let lastId = chronologicalLogs.last?.id {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                    .onChange(of: scanner.activityLogs.first?.id) { _, _ in
                        guard autoFollowLatest, let lastId = chronologicalLogs.last?.id else { return }
                        withAnimation(.easeOut(duration: 0.15)) {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .background(MainCleanTheme.panelBg)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(MainCleanTheme.borderStrong)
                .frame(height: 1)
        }
    }
}
