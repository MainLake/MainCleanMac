import SwiftUI

struct ContentView: View {
    @EnvironmentObject var scanner: SystemScannerService
    @State private var selectedTab: NavigationTab = .dashboard

    var body: some View {
        HStack(spacing: 0) {
            // Left Optical Navigation Rail
            RamanRailSidebar(selectedTab: $selectedTab)

            // Vertical Optical Separator
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            RamanTheme.laserCyan.opacity(0.25),
                            RamanTheme.antiStokesViolet.opacity(0.25),
                            Color.white.opacity(0.06)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 1)

            // Main Lens Canvas
            ZStack(alignment: .bottom) {
                RamanTheme.canvasBg
                    .ignoresSafeArea()

                VStack(spacing: 0) {
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

                    if scanner.showLogDrawer {
                        ActivityLogDrawerView()
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }

                // Floating Toast Notification with Log Drawer toggle
                if let status = scanner.lastStatusMessage, !scanner.isExecutingOperation {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(RamanTheme.emeraldSafe)
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
                            Text(scanner.showLogDrawer ? "Ocultar Consola" : "Ver Consola")
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
                    .background(RamanTheme.panelBg.opacity(0.95), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(RamanTheme.laserCyan.opacity(0.3), lineWidth: 1)
                    )
                    .padding(.horizontal, 24)
                    .padding(.bottom, scanner.showLogDrawer ? 200 : 18)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // In-Place Live Loader Overlay
                if scanner.isExecutingOperation {
                    ZStack {
                        Color.black.opacity(0.55)
                            .ignoresSafeArea()

                        VStack(spacing: 14) {
                            ProgressView()
                                .scaleEffect(1.3)
                                .tint(RamanTheme.laserCyan)

                            Text(scanner.currentOperationTitle)
                                .font(.headline)
                                .foregroundStyle(.white)

                            Text(scanner.currentOperationSubtitle)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .frame(maxWidth: 380)

                            Button {
                                withAnimation(.spring(duration: 0.25)) {
                                    scanner.showLogDrawer.toggle()
                                }
                            } label: {
                                Label(scanner.showLogDrawer ? "Ocultar Consola" : "Ver Consola en Vivo", systemImage: "terminal")
                                    .font(.caption.weight(.semibold))
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(26)
                        .background(RamanTheme.panelBg, in: RoundedRectangle(cornerRadius: 18))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(RamanTheme.laserCyan.opacity(0.45), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.6), radius: 24)
                    }
                    .transition(.opacity)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            scanner.refreshAll()
        }
    }
}

// MARK: - Distinctive Raman Optical Rail Sidebar

struct RamanRailSidebar: View {
    @EnvironmentObject var scanner: SystemScannerService
    @Binding var selectedTab: NavigationTab

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Identity Header
            HStack(spacing: 12) {
                RamanPrismLogo(size: 38)

                VStack(alignment: .leading, spacing: 2) {
                    Text("RAMAN SWEEP")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(.white)
                    HStack(spacing: 5) {
                        Circle()
                            .fill(RamanTheme.emeraldSafe)
                            .frame(width: 6, height: 6)
                        Text(scanner.mSeriesStatus.chipName.uppercased())
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(RamanTheme.laserCyan)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 20)

            // 5 Focused Optical Lenses
            VStack(alignment: .leading, spacing: 6) {
                Text("LENTES DE INSPECCIÓN")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(1.1)
                    .foregroundStyle(.secondary.opacity(0.7))
                    .padding(.horizontal, 18)
                    .padding(.bottom, 4)

                ForEach(NavigationTab.allCases) { tab in
                    let isSelected = selectedTab == tab
                    Button {
                        withAnimation(.spring(duration: 0.2)) {
                            selectedTab = tab
                        }
                    } label: {
                        HStack(spacing: 12) {
                            // Wavelength Indicator Bar
                            RoundedRectangle(cornerRadius: 2)
                                .fill(isSelected ? tab.accentColor : Color.clear)
                                .frame(width: 3, height: 26)

                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isSelected ? tab.accentColor.opacity(0.18) : Color.white.opacity(0.03))
                                    .frame(width: 30, height: 30)
                                Image(systemName: tab.icon)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(isSelected ? tab.accentColor : .secondary)
                            }

                            VStack(alignment: .leading, spacing: 1) {
                                Text(tab.rawValue)
                                    .font(.system(size: 13, weight: isSelected ? .bold : .medium, design: .rounded))
                                    .foregroundStyle(isSelected ? .white : .primary.opacity(0.8))
                                Text(tab.tagline)
                                    .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(isSelected ? tab.accentColor.opacity(0.9) : .secondary.opacity(0.6))
                                    .lineLimit(1)
                            }

                            Spacer()
                        }
                        .padding(.trailing, 12)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 11)
                                .fill(isSelected ? Color.white.opacity(0.07) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 11)
                                .stroke(isSelected ? tab.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 10)
                }
            }

            Spacer()

            // Console Toggle Pill
            Button {
                withAnimation(.spring(duration: 0.25)) {
                    scanner.showLogDrawer.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "terminal.fill")
                        .font(.caption2)
                        .foregroundStyle(RamanTheme.laserCyan)
                    Text("Consola Óptica (\(scanner.activityLogs.count))")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: scanner.showLogDrawer ? "chevron.down" : "chevron.up")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 9))
                .overlay(
                    RoundedRectangle(cornerRadius: 9)
                        .stroke(RamanTheme.borderSubtle, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)

            // SSD Wavelength Mini-Card
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("DISCO INTERNO APFS")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(ByteFormatter.string(from: scanner.diskOverview.freeBytes)) LIBRES")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundStyle(RamanTheme.emeraldSafe)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                        Capsule()
                            .fill(RamanTheme.spectrumGradient)
                            .frame(width: max(8, geo.size.width * scanner.diskOverview.usedPercentage))
                    }
                }
                .frame(height: 6)

                HStack {
                    Text("Usado: \(ByteFormatter.string(from: scanner.diskOverview.usedBytes))")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Total: \(ByteFormatter.string(from: scanner.diskOverview.totalBytes))")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .background(RamanTheme.panelBg, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(RamanTheme.borderSubtle, lineWidth: 1)
            )
            .padding(.horizontal, 14)
            .padding(.bottom, 16)
        }
        .frame(width: 242)
        .background(RamanTheme.verticalRailGradient)
    }
}

// MARK: - Lens 1: Pulso Raman (Strictly Overview, Spectrum & Auto-Pilot)

struct DashboardView: View {
    @EnvironmentObject var scanner: SystemScannerService
    @Binding var selectedTab: NavigationTab

    var totalSafeCleanableBytes: Int64 {
        let safeCaches = scanner.cacheItems.filter { $0.safety == .safe }.reduce(Int64(0)) { $0 + $1.sizeBytes }
        let orphans = scanner.orphanedLeftovers.reduce(Int64(0)) { $0 + $1.sizeBytes }
        let surgical = scanner.surgicalItems.filter(\.isSelected).reduce(Int64(0)) { $0 + $1.sizeBytes }
        return safeCaches + orphans + surgical
    }

    var totalAppsBytes: Int64 {
        let apps = scanner.installedApps.reduce(Int64(0)) { $0 + $1.totalSizeBytes }
        return apps > 0 ? apps : 18_000_000_000
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                // Header
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 10) {
                            Text("Pulso Raman")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                            Text("ESPECTROMETRÍA DE DISCO")
                                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                .foregroundStyle(RamanTheme.laserCyan)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(RamanTheme.laserCyan.opacity(0.14), in: Capsule())
                        }
                        Text("Vista panorámica del almacenamiento de tu Mac, sin listas mezcladas.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        scanner.refreshAll()
                    } label: {
                        Label("Calibrar Espectro", systemImage: "waveform.path.ecg")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .disabled(scanner.isExecutingOperation)
                }

                // 1. Optical Storage Spectrum Card
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ESPECTRO ÓPTICO DEL VOLUMEN APFS")
                                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                .tracking(1.0)
                                .foregroundStyle(RamanTheme.laserCyan)
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text(ByteFormatter.string(from: scanner.diskOverview.freeBytes))
                                    .font(.system(size: 38, weight: .black, design: .rounded))
                                    .foregroundStyle(RamanTheme.emeraldSafe)
                                Text("disponibles de \(ByteFormatter.string(from: scanner.diskOverview.totalBytes))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        // Quick Laser Action
                        HStack(spacing: 10) {
                            Button {
                                Task {
                                    scanner.selectOnlySafeCaches()
                                    await scanner.cleanSelectedCaches()
                                    await scanner.cleanAllSelectedSurgicalItems()
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "laser.burst")
                                    Text("Barrido + Cirugía Segura (\(ByteFormatter.string(from: scanner.totalSelectedCacheBytes + scanner.totalSelectedSurgicalBytes)))")
                                        .fontWeight(.bold)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 9)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(RamanTheme.stokesAmber)
                            .foregroundStyle(.black)
                            .disabled((scanner.totalSelectedCacheBytes + scanner.totalSelectedSurgicalBytes) == 0 || scanner.isExecutingOperation)
                        }
                    }

                    RamanSpectrumBar(
                        totalBytes: scanner.diskOverview.totalBytes,
                        usedBytes: scanner.diskOverview.usedBytes,
                        reclaimableBytes: max(scanner.totalSelectedCacheBytes + scanner.totalSelectedSurgicalBytes, totalSafeCleanableBytes),
                        appsBytes: totalAppsBytes
                    )
                }
                .padding(24)
                .background(RamanTheme.panelBg, in: RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(RamanTheme.laserCyan.opacity(0.25), lineWidth: 1)
                )

                // 2. Four Specialized Lens Portals (Direct Jump Cards without clutter)
                VStack(alignment: .leading, spacing: 10) {
                    Text("MÓDULOS ESPECIALIZADOS")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .tracking(1.0)
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                        LensPortalCard(
                            title: "Barrido Láser",
                            subtitle: "Cachés de navegadores, logs y paquetes",
                            metric: ByteFormatter.string(from: scanner.totalSelectedCacheBytes),
                            metricLabel: "Listo para purgar",
                            icon: "laser.burst",
                            accent: RamanTheme.stokesAmber
                        ) {
                            selectedTab = .smartCaches
                        }

                        LensPortalCard(
                            title: "Aplicaciones & Huérfanos",
                            subtitle: "Desinstalador completo estilo Pearcleaner",
                            metric: "\(scanner.installedApps.count) Apps",
                            metricLabel: "\(scanner.orphanedLeftovers.count) residuos huérfanos",
                            icon: "square.stack.3d.up.fill",
                            accent: Color(red: 0.96, green: 0.36, blue: 0.62)
                        ) {
                            selectedTab = .uninstaller
                        }

                        LensPortalCard(
                            title: "Núcleo Chip M",
                            subtitle: "Binarios arm64, SQLite, Proyectos y Docker",
                            metric: scanner.mSeriesStatus.chipName,
                            metricLabel: "\(scanner.projectArtifacts.count) artefactos de código",
                            icon: "cpu.fill",
                            accent: RamanTheme.emeraldSafe
                        ) {
                            selectedTab = .appleSilicon
                        }

                        LensPortalCard(
                            title: "Espectro Disco & Cirugía",
                            subtitle: "Limpia dentro de Application Support y Datos del Sistema",
                            metric: ByteFormatter.string(from: scanner.surgicalItems.reduce(0) { $0 + $1.sizeBytes }),
                            metricLabel: "\(scanner.surgicalItems.count) objetivos quirúrgicos ocultos",
                            icon: "scissors",
                            accent: RamanTheme.antiStokesViolet
                        ) {
                            selectedTab = .spaceLens
                        }
                    }
                }

                // 3. Integrated Auto-Pilot Bar (LaunchAgent Daemon)
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill((scanner.isScheduleInstalled ? RamanTheme.emeraldSafe : RamanTheme.laserCyan).opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: scanner.isScheduleInstalled ? "bolt.shield.fill" : "clock.badge.checkmark")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(scanner.isScheduleInstalled ? RamanTheme.emeraldSafe : RamanTheme.laserCyan)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text("Piloto Automático Raman (LaunchAgent)")
                                .font(.headline)
                            Text(scanner.isScheduleInstalled ? "ACTIVO" : "INACTIVO")
                                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                .foregroundStyle(scanner.isScheduleInstalled ? RamanTheme.emeraldSafe : .secondary)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background((scanner.isScheduleInstalled ? RamanTheme.emeraldSafe : Color.white).opacity(0.12), in: Capsule())
                        }
                        Text("Ejecuta un barrido silencioso de cachés 100% seguras en segundo plano sin tocar tus documentos ni sesiones.")
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
                    .frame(width: 210)

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
                        .help("Desactivar Piloto Automático")
                    } else {
                        Button("Activar Piloto") {
                            scanner.installOrUpdateSchedule()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(RamanTheme.laserCyan)
                        .foregroundStyle(.black)
                    }
                }
                .padding(18)
                .background(RamanTheme.panelBg, in: RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(RamanTheme.borderSubtle, lineWidth: 1)
                )
            }
            .padding(28)
        }
    }
}

struct LensPortalCard: View {
    let title: String
    let subtitle: String
    let metric: String
    let metricLabel: String
    let icon: String
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(accent.opacity(0.16))
                            .frame(width: 38, height: 38)
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(accent)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Divider().overlay(Color.white.opacity(0.06))

                HStack(alignment: .firstTextBaseline) {
                    Text(metric)
                        .font(.system(size: 18, weight: .heavy, design: .rounded).monospacedDigit())
                        .foregroundStyle(accent)
                    Spacer()
                    Text(metricLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(18)
            .background(RamanTheme.panelBg, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(accent.opacity(0.22), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Activity Log Drawer

struct ActivityLogDrawerView: View {
    @EnvironmentObject var scanner: SystemScannerService

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "terminal.fill")
                    .foregroundStyle(RamanTheme.laserCyan)
                Text("CONSOLA ÓPTICA DE ACTIVIDAD (\(scanner.activityLogs.count))")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
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
            .background(Color.black.opacity(0.45))

            Divider().overlay(Color.white.opacity(0.08))

            if scanner.activityLogs.isEmpty {
                HStack {
                    Spacer()
                    Text("Sin eventos registrados en esta sesión.")
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
        .background(RamanTheme.panelBg)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(RamanTheme.laserCyan.opacity(0.25))
                .frame(height: 1)
        }
    }
}
