import SwiftUI

enum MainCleanTheme {
    // Superdesign Linear/Raycast Restrained Slate Palette
    static let canvasBg = Color(red: 0.051, green: 0.059, blue: 0.071)   // #0D0F12
    static let sidebarBg = Color(red: 0.071, green: 0.082, blue: 0.102)  // #12151A
    static let railBg = sidebarBg
    static let panelBg = Color(red: 0.086, green: 0.102, blue: 0.125)    // #161A20
    static let hoverBg = Color(red: 0.110, green: 0.129, blue: 0.161)    // #1C2129
    static let borderSubtle = Color.white.opacity(0.07)
    static let borderStrong = Color.white.opacity(0.14)

    // Restrained Functional Accents
    static let brandBlue = Color(red: 0.231, green: 0.510, blue: 0.965)  // #3B82F6
    static let accentBlue = brandBlue
    static let accentIndigo = Color(red: 0.388, green: 0.400, blue: 0.945) // #6366F1
    static let safeGreen = Color(red: 0.063, green: 0.725, blue: 0.506)  // #10B981
    static let emeraldSafe = safeGreen
    static let deepAmber = Color(red: 0.961, green: 0.620, blue: 0.043)  // #F59E0B
    static let amberCaution = deepAmber
    static let dangerRed = Color(red: 0.937, green: 0.267, blue: 0.267)  // #EF4444
    static let crimsonDanger = dangerRed

    // Backward-compatible property aliases for sub-views
    static let laserCyan = brandBlue
    static let stokesAmber = deepAmber
    static let antiStokesViolet = accentIndigo
    static let infraredRed = dangerRed

    static let spectrumGradient = LinearGradient(
        colors: [brandBlue, safeGreen],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let verticalRailGradient = LinearGradient(
        colors: [sidebarBg, canvasBg],
        startPoint: .top,
        endPoint: .bottom
    )
}

// Backward-compatible alias so sub-views compile cleanly
typealias RamanTheme = MainCleanTheme
typealias RamanPrismLogo = MainCleanLogo

/// Clean, restrained 4-segment storage bar matching the Superdesign draft
struct MainCleanStorageBar: View {
    let totalBytes: Int64
    let usedBytes: Int64
    let reclaimableBytes: Int64
    let appsBytes: Int64

    var freeBytes: Int64 {
        max(0, totalBytes - usedBytes)
    }

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
        VStack(alignment: .leading, spacing: 12) {
            GeometryReader { geo in
                HStack(spacing: 2) {
                    // System & Data (#3B82F6)
                    Rectangle()
                        .fill(MainCleanTheme.brandBlue)
                        .frame(width: max(12, geo.size.width * systemAndDataRatio))

                    // Applications (white/25)
                    Rectangle()
                        .fill(Color.white.opacity(0.24))
                        .frame(width: max(12, geo.size.width * appsRatio))

                    // Reclaimable Safe + Deep (#F59E0B)
                    Rectangle()
                        .fill(MainCleanTheme.deepAmber)
                        .frame(width: max(8, geo.size.width * reclaimRatio))

                    // Free Space
                    Rectangle()
                        .fill(MainCleanTheme.canvasBg)
                        .frame(maxWidth: .infinity)
                }
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(MainCleanTheme.borderSubtle, lineWidth: 1)
                )
            }
            .frame(height: 14)

            HStack(spacing: 24) {
                StorageLegendDot(
                    color: MainCleanTheme.brandBlue,
                    label: "Sistema y Datos",
                    value: ByteFormatter.string(from: max(0, usedBytes - appsBytes - reclaimableBytes))
                )
                StorageLegendDot(
                    color: Color.white.opacity(0.35),
                    label: "Aplicaciones",
                    value: ByteFormatter.string(from: appsBytes)
                )
                StorageLegendDot(
                    color: MainCleanTheme.deepAmber,
                    label: "Recuperable",
                    value: ByteFormatter.string(from: reclaimableBytes)
                )
                Spacer()
                StorageLegendDot(
                    color: MainCleanTheme.safeGreen,
                    label: "Espacio Libre",
                    value: ByteFormatter.string(from: freeBytes),
                    highlightValue: true
                )
            }
        }
    }
}

struct StorageLegendDot: View {
    let color: Color
    let label: String
    let value: String
    var highlightValue: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(highlightValue ? MainCleanTheme.safeGreen : .white)
        }
    }
}

struct MainCleanLogo: View {
    var size: CGFloat = 34

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.25)
                .fill(MainCleanTheme.brandBlue)
                .frame(width: size, height: size)

            Image(systemName: "cpu")
                .font(.system(size: size * 0.5, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}
