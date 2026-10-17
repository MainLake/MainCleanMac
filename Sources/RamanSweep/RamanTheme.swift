import SwiftUI

enum RamanTheme {
    // Deep Obsidian Optical Backgrounds
    static let canvasBg = Color(red: 0.04, green: 0.045, blue: 0.065)
    static let panelBg = Color(red: 0.075, green: 0.082, blue: 0.115)
    static let cardBg = Color.white.opacity(0.038)
    static let cardHover = Color.white.opacity(0.065)
    static let borderSubtle = Color.white.opacity(0.08)

    // Spectral Wavelength Accents (C.V. Raman Light Scattering Identity)
    static let laserCyan = Color(red: 0.0, green: 0.88, blue: 0.96)
    static let stokesAmber = Color(red: 1.0, green: 0.68, blue: 0.18)
    static let antiStokesViolet = Color(red: 0.56, green: 0.36, blue: 0.98)
    static let emeraldSafe = Color(red: 0.16, green: 0.86, blue: 0.56)
    static let infraredRed = Color(red: 0.96, green: 0.28, blue: 0.38)

    static let spectrumGradient = LinearGradient(
        colors: [laserCyan, antiStokesViolet, stokesAmber],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let verticalRailGradient = LinearGradient(
        colors: [
            Color(red: 0.05, green: 0.055, blue: 0.08),
            Color(red: 0.035, green: 0.04, blue: 0.06)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}

/// Interactive multi-segment wavelength bar showing the optical spectrum of the Mac's SSD
struct RamanSpectrumBar: View {
    let totalBytes: Int64
    let usedBytes: Int64
    let reclaimableBytes: Int64
    let appsBytes: Int64

    var reclaimRatio: Double {
        guard totalBytes > 0 else { return 0 }
        return min(0.35, max(0.02, Double(reclaimableBytes) / Double(totalBytes)))
    }

    var appsRatio: Double {
        guard totalBytes > 0 else { return 0 }
        return min(0.45, max(0.05, Double(appsBytes) / Double(totalBytes)))
    }

    var systemAndDataRatio: Double {
        guard totalBytes > 0 else { return 0 }
        let totalUsedRatio = Double(usedBytes) / Double(totalBytes)
        return max(0.05, totalUsedRatio - reclaimRatio - appsRatio)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GeometryReader { geo in
                HStack(spacing: 3) {
                    // System & User Core Data (Violet/Blue)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(RamanTheme.antiStokesViolet)
                        .frame(width: max(12, geo.size.width * systemAndDataRatio))

                    // Installed Applications (Laser Cyan)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(RamanTheme.laserCyan)
                        .frame(width: max(12, geo.size.width * appsRatio))

                    // Reclaimable Raman Scattering / Caches (Stokes Amber)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(RamanTheme.stokesAmber)
                        .frame(width: max(8, geo.size.width * reclaimRatio))

                    // Free Available Space
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.07))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 14)

            // Legend
            HStack(spacing: 20) {
                SpectrumLegendDot(color: RamanTheme.antiStokesViolet, label: "Sistema y Datos")
                SpectrumLegendDot(color: RamanTheme.laserCyan, label: "Aplicaciones (\(ByteFormatter.string(from: appsBytes)))")
                SpectrumLegendDot(color: RamanTheme.stokesAmber, label: "Purgable Hoy (\(ByteFormatter.string(from: reclaimableBytes)))")
                Spacer()
                SpectrumLegendDot(color: RamanTheme.emeraldSafe, label: "Disponible (\(ByteFormatter.string(from: max(0, totalBytes - usedBytes))))")
            }
        }
    }
}

struct SpectrumLegendDot: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }
}

/// Custom optical prism emblem for RamanSweep
struct RamanPrismLogo: View {
    var size: CGFloat = 34

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28)
                .fill(RamanTheme.panelBg)
                .frame(width: size, height: size)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.28)
                        .stroke(
                            LinearGradient(
                                colors: [RamanTheme.laserCyan, RamanTheme.antiStokesViolet, RamanTheme.stokesAmber],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )

            Image(systemName: "prism.fill")
                .font(.system(size: size * 0.46, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [RamanTheme.laserCyan, .white, RamanTheme.stokesAmber],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }
}
