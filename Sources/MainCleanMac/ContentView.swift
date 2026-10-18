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

            // Main Canvas
            ZStack(alignment: .bottomTrailing) {
                MainCleanTheme.canvasBg
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Top Content Area (Operation Overlay only covers this area, never the bottom Log Drawer)
                    ZStack(alignment: .bottomTrailing) {
                        Group {
                            switch selectedTab {
                            case .dashboard:
                                DashboardView(selectedTab: $selectedTab)
                            case .smartCaches:
                                SmartCachesView()
                            case .uninstaller:
                                AppUninstallerView()
                            case .appleSilicon:
                                AppleSiliconOptimizerView()
                            case .spaceLens:
                                SpaceLensView()
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
        }
        .preferredColorScheme(.dark)
        .onAppear {
            scanner.refreshAll()
        }
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
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(MainCleanTheme.emeraldSafe.opacity(0.15))
                        .frame(width: 30, height: 30)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(MainCleanTheme.emeraldSafe)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(message)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text("El espacio libre del disco se actualizó en tiempo real · Se oculta en 4s")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                }

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
                }
                .buttonStyle(.plain)

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .padding(5)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)

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
            .frame(height: 2.5)
        }
        .frame(width: 460)
        .background(Color(red: 0.11, green: 0.13, blue: 0.16).opacity(0.97))
        .clipShape(RoundedRectangle(cornerRadius: 11))
        .overlay(
            RoundedRectangle(cornerRadius: 11)
                .stroke(MainCleanTheme.emeraldSafe.opacity(0.32), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.45), radius: 16, y: 6)
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

// MARK: - MainCleanMac Sidebar (Restrained & Self-Explanatory)

struct MainCleanSidebar: View {
    @EnvironmentObject var scanner: SystemScannerService
    @Binding var selectedTab: NavigationTab

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // App Brand Header
            HStack(spacing: 11) {
                MainCleanLogo(size: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text("MainCleanMac")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                    HStack(spacing: 5) {
                        Circle()
                            .fill(MainCleanTheme.emeraldSafe)
                            .frame(width: 6, height: 6)
                        Text(scanner.mSeriesStatus.chipName)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)

            // 5 Self-Explanatory Sections
            VStack(alignment: .leading, spacing: 4) {
                Text("SECCIONES")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(.secondary.opacity(0.75))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)

                ForEach(NavigationTab.allCases) { tab in
                    let isSelected = selectedTab == tab
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedTab = tab
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(isSelected ? tab.accentColor : .secondary)
                                .frame(width: 22)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(tab.rawValue)
                                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                                    .foregroundStyle(isSelected ? .white : .primary.opacity(0.82))
                                Text(tab.tagline)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isSelected ? Color.white.opacity(0.065) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isSelected ? MainCleanTheme.borderStrong : Color.clear, lineWidth: 1)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 10)
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
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: scanner.showLogDrawer ? "chevron.down" : "chevron.up")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(MainCleanTheme.borderSubtle, lineWidth: 1)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)

            // Live Free Space Card in Sidebar
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("DISCO INTERNO")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
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
                            .fill(MainCleanTheme.accentBlue)
                            .frame(width: max(8, geo.size.width * scanner.diskOverview.usedPercentage))
                    }
                }
                .frame(height: 5)

                HStack {
                    Text("Usado: \(ByteFormatter.string(from: scanner.diskOverview.usedBytes))")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if scanner.sessionFreedBytes > 0 {
                        Text("+\(ByteFormatter.string(from: scanner.sessionFreedBytes))")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(MainCleanTheme.emeraldSafe)
                    } else {
                        Text("Total: \(ByteFormatter.string(from: scanner.diskOverview.totalBytes))")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .background(MainCleanTheme.panelBg, in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(MainCleanTheme.borderSubtle, lineWidth: 1)
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 14)
        }
        .frame(width: 238)
        .background(MainCleanTheme.railBg)
    }
}

// MARK: - Section 1: Resumen General (Live Free Space + 2-Level One-Click Cleaning)

struct DashboardView: View {
    @EnvironmentObject var scanner: SystemScannerService
    @Binding var selectedTab: NavigationTab

    var totalReclaimableBytes: Int64 {
        scanner.quickSafeCleanableBytes + scanner.deepSystemCleanableBytes
    }

    var totalAppsBytes: Int64 {
        let apps = scanner.installedApps.reduce(Int64(0)) { $0 + $1.totalSizeBytes }
        return apps > 0 ? apps : 18_000_000_000
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 10) {
                            Text("Resumen General")
                                .font(.system(size: 24, weight: .bold))
                            Text("\(scanner.mSeriesStatus.chipName) · \(scanner.mSeriesStatus.physicalRAMGB) GB RAM")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 3)
                                .background(MainCleanTheme.panelBg, in: Capsule())
                                .overlay(Capsule().stroke(MainCleanTheme.borderSubtle, lineWidth: 1))
                        }
                        Text("Estado del disco en tiempo real y acciones directas de limpieza.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        scanner.refreshAll()
                    } label: {
                        Label("Actualizar Análisis", systemImage: "arrow.clockwise")
                            .font(.caption.weight(.medium))
                    }
                    .buttonStyle(.bordered)
                    .disabled(scanner.isExecutingOperation)
                }

                // 1. Live Storage Status Card (Immediate Reflection of Freed Space)
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("ESPACIO DISPONIBLE EN DISCO (TIEMPO REAL)")
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .tracking(0.6)
                                .foregroundStyle(.secondary)

                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text(ByteFormatter.string(from: scanner.diskOverview.freeBytes))
                                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white)
                                    .contentTransition(.numericText())

                                Text("libres de \(ByteFormatter.string(from: scanner.diskOverview.totalBytes))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                if scanner.sessionFreedBytes > 0 {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.up.right")
                                            .font(.system(size: 10, weight: .bold))
                                        Text("+\(ByteFormatter.string(from: scanner.sessionFreedBytes)) liberados en esta sesión")
                                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    }
                                    .foregroundStyle(MainCleanTheme.emeraldSafe)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 4)
                                    .background(MainCleanTheme.emeraldSafe.opacity(0.12), in: Capsule())
                                    .overlay(Capsule().stroke(MainCleanTheme.emeraldSafe.opacity(0.3), lineWidth: 1))
                                }
                            }
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Recuperable detectado")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(ByteFormatter.string(from: totalReclaimableBytes))
                                .font(.system(size: 20, weight: .bold, design: .monospaced))
                                .foregroundStyle(MainCleanTheme.amberCaution)
                                .contentTransition(.numericText())
                        }
                    }

                    MainCleanStorageBar(
                        totalBytes: scanner.diskOverview.totalBytes,
                        usedBytes: scanner.diskOverview.usedBytes,
                        reclaimableBytes: totalReclaimableBytes,
                        appsBytes: totalAppsBytes
                    )
                }
                .padding(20)
                .background(MainCleanTheme.panelBg, in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(MainCleanTheme.borderSubtle, lineWidth: 1)
                )

                // 2. Two-Level Primary Action Cards (Quick Safe vs Deep System Data)
                HStack(spacing: 14) {
                    // Level 1: Quick Safe Cleanup (1 Click, No Prompt)
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .top) {
                            HStack(spacing: 10) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 9)
                                        .fill(MainCleanTheme.emeraldSafe.opacity(0.14))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: "bolt.shield.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(MainCleanTheme.emeraldSafe)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Limpieza Rápida Segura")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(.white)
                                    Text("1 CLIC · SIN PREGUNTAR")
                                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(MainCleanTheme.emeraldSafe)
                                }
                            }
                            Spacer()
                            Text(ByteFormatter.string(from: scanner.quickSafeCleanableBytes))
                                .font(.system(size: 19, weight: .bold, design: .monospaced))
                                .foregroundStyle(MainCleanTheme.emeraldSafe)
                                .contentTransition(.numericText())
                        }

                        Text("Elimina cachés de navegadores, registros de fallos, GPUCache, Service Workers y compacta bases SQLite sin cerrar tus sesiones ni tocar tus cuentas.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)

                        HStack(spacing: 6) {
                            CleanTagPill(text: "Cachés Web")
                            CleanTagPill(text: "Logs y Crashpad")
                            CleanTagPill(text: "GPUCache")
                            CleanTagPill(text: "SQLite VACUUM")
                        }

                        Button {
                            Task {
                                await scanner.runQuickSafeCleanup()
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                Text("Ejecutar Limpieza Rápida (\(ByteFormatter.string(from: scanner.quickSafeCleanableBytes)))")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(MainCleanTheme.emeraldSafe)
                        .foregroundStyle(Color(red: 0.03, green: 0.12, blue: 0.08))
                        .disabled(scanner.isExecutingOperation)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity)
                    .background(MainCleanTheme.panelBg, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(MainCleanTheme.emeraldSafe.opacity(0.28), lineWidth: 1)
                    )

                    // Level 2: Deep System Data Cleanup
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .top) {
                            HStack(spacing: 10) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 9)
                                        .fill(MainCleanTheme.amberCaution.opacity(0.14))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: "internaldrive.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(MainCleanTheme.amberCaution)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Limpieza Profunda del Sistema")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(.white)
                                    Text("DATOS DEL SISTEMA & APPS HUÉRFANAS")
                                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(MainCleanTheme.amberCaution)
                                }
                            }
                            Spacer()
                            Text(ByteFormatter.string(from: scanner.deepSystemCleanableBytes))
                                .font(.system(size: 19, weight: .bold, design: .monospaced))
                                .foregroundStyle(MainCleanTheme.amberCaution)
                                .contentTransition(.numericText())
                        }

                        Text("Purga instaladores atorados en Application Support (Docker 2.26 GB), restos de apps ya desinstaladas, cachés de Homebrew/npm/uv y videos 4K de macOS.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)

                        HStack(spacing: 6) {
                            CleanTagPill(text: "Docker Residual")
                            CleanTagPill(text: "Apps Fantasma")
                            CleanTagPill(text: "Homebrew & npm")
                            CleanTagPill(text: "Videos 4K")
                        }

                        HStack(spacing: 8) {
                            Button {
                                Task {
                                    await scanner.runDeepSystemCleanup()
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "flame.fill")
                                    Text("Limpiar Datos del Sistema (\(ByteFormatter.string(from: scanner.deepSystemCleanableBytes)))")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 7)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(MainCleanTheme.amberCaution)
                            .foregroundStyle(Color(red: 0.12, green: 0.07, blue: 0.01))
                            .disabled(scanner.isExecutingOperation)

                            Button {
                                selectedTab = .smartCaches
                            } label: {
                                Text("Revisar")
                                    .font(.caption.weight(.medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity)
                    .background(MainCleanTheme.panelBg, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(MainCleanTheme.amberCaution.opacity(0.28), lineWidth: 1)
                    )
                }

                // 3. Direct Section Modules
                VStack(alignment: .leading, spacing: 10) {
                    Text("HERRAMIENTAS DETALLADAS")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .tracking(0.6)
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ], spacing: 12) {
                        ModuleSummaryCard(
                            title: "Cachés y Datos",
                            subtitle: "Cachés y cirugía interna",
                            metric: ByteFormatter.string(from: scanner.totalSelectedCacheBytes + scanner.totalSelectedSurgicalBytes),
                            detail: "\(scanner.cacheItems.count + scanner.surgicalItems.count) objetivos detectados",
                            icon: "internaldrive",
                            accent: MainCleanTheme.accentBlue
                        ) {
                            selectedTab = .smartCaches
                        }

                        ModuleSummaryCard(
                            title: "Desinstalador",
                            subtitle: "Apps y restos huérfanos",
                            metric: "\(scanner.installedApps.count) Apps",
                            detail: "\(scanner.orphanedLeftovers.count) restos de apps borradas",
                            icon: "trash",
                            accent: MainCleanTheme.crimsonDanger
                        ) {
                            selectedTab = .uninstaller
                        }

                        ModuleSummaryCard(
                            title: "Desarrollo y Chip M",
                            subtitle: "node_modules, Docker y SQLite",
                            metric: ByteFormatter.string(from: scanner.projectArtifacts.reduce(0) { $0 + $1.sizeBytes }),
                            detail: "\(scanner.projectArtifacts.count) carpetas de proyectos",
                            icon: "cpu",
                            accent: MainCleanTheme.emeraldSafe
                        ) {
                            selectedTab = .appleSilicon
                        }

                        ModuleSummaryCard(
                            title: "Explorador de Disco",
                            subtitle: "Navegar carpetas por peso",
                            metric: ByteFormatter.string(from: scanner.systemDataItems.reduce(0) { $0 + $1.sizeBytes }),
                            detail: "Incluye Rayos X de Datos del Sistema",
                            icon: "folder",
                            accent: MainCleanTheme.accentIndigo
                        ) {
                            selectedTab = .spaceLens
                        }
                    }
                }

                // 4. Background Scheduled Cleanup Bar (LaunchAgent)
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 9)
                            .fill((scanner.isScheduleInstalled ? MainCleanTheme.emeraldSafe : MainCleanTheme.accentBlue).opacity(0.12))
                            .frame(width: 38, height: 38)
                        Image(systemName: "clock.arrow.2.circlepath")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(scanner.isScheduleInstalled ? MainCleanTheme.emeraldSafe : MainCleanTheme.accentBlue)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            Text("Limpieza Automática Programada (LaunchAgent)")
                                .font(.system(size: 13.5, weight: .semibold))
                            Text(scanner.isScheduleInstalled ? "ACTIVA" : "INACTIVA")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(scanner.isScheduleInstalled ? MainCleanTheme.emeraldSafe : .secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background((scanner.isScheduleInstalled ? MainCleanTheme.emeraldSafe : Color.white).opacity(0.1), in: Capsule())
                        }
                        Text("Limpia silenciosamente cachés temporales seguras en segundo plano sin cerrar tus programas.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Picker("", selection: $scanner.selectedFrequency) {
                        ForEach(ScheduleFrequency.allCases) { freq in
                            Text(freq.rawValue).tag(freq)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)

                    if scanner.isScheduleInstalled {
                        Button("Actualizar") {
                            scanner.installOrUpdateSchedule()
                        }
                        .buttonStyle(.bordered)

                        Button(role: .destructive) {
                            scanner.removeSchedule()
                        } label: {
                            Image(systemName: "power")
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Button("Activar") {
                            scanner.installOrUpdateSchedule()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(MainCleanTheme.accentBlue)
                    }
                }
                .padding(16)
                .background(MainCleanTheme.panelBg, in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(MainCleanTheme.borderSubtle, lineWidth: 1)
                )
            }
            .padding(24)
        }
    }
}

struct CleanTagPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 5))
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(MainCleanTheme.borderSubtle, lineWidth: 1)
            )
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
            .background(MainCleanTheme.panelBg, in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
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
