import XCTest
@testable import MainCleanMac

final class MainCleanMacTests: XCTestCase {

    // MARK: - 1. ByteFormatter & Disk Overview Calculation Tests
    func testByteFormatterFormatting() {
        // Formatter uses localized file count style
        let zeroStr = ByteFormatter.string(from: 0)
        XCTAssertFalse(zeroStr.isEmpty)

        let mbStr = ByteFormatter.string(from: 50 * 1024 * 1024)
        XCTAssertTrue(mbStr.contains("50") || mbStr.contains("MB") || mbStr.contains("M"))

        let gbStr = ByteFormatter.string(from: 500 * 1024 * 1024 * 1024)
        XCTAssertTrue(gbStr.contains("500") || gbStr.contains("GB") || gbStr.contains("G"))
    }

    func testDiskOverviewCalculations() {
        var overview = DiskOverview()
        XCTAssertEqual(overview.usedBytes, 0)
        XCTAssertEqual(overview.usedPercentage, 0)

        // 500 GB total, 200 GB free -> 300 GB used (60%)
        overview.totalBytes = 500 * 1024 * 1024 * 1024
        overview.freeBytes = 200 * 1024 * 1024 * 1024
        XCTAssertEqual(overview.usedBytes, 300 * 1024 * 1024 * 1024)
        XCTAssertEqual(overview.usedPercentage, 0.6, accuracy: 0.001)

        // Edge case: freeBytes >= totalBytes
        overview.freeBytes = 600 * 1024 * 1024 * 1024
        XCTAssertEqual(overview.usedBytes, 0)
    }

    // MARK: - 2. Critical SafetyGuard Tests (Security against accidental deletion)
    func testSafetyGuardSystemProtection() {
        let fakeHome = "/Users/testuser"

        // Critical OS and system paths MUST ALWAYS be .protected
        let criticalPaths = [
            "/",
            "/System",
            "/System/Library",
            "/bin",
            "/sbin",
            "/usr/bin",
            "/usr/lib",
            "/private/var/db",
            "/Applications/Safari.app"
        ]

        for path in criticalPaths {
            let (level, reason) = SafetyGuard.evaluate(path: path, home: fakeHome)
            XCTAssertEqual(level, .protected, "Ruta del sistema debe estar protegida: \(path)")
            XCTAssertNotNil(reason)
        }
    }

    func testSafetyGuardUserCriticalPaths() {
        let fakeHome = "/Users/testuser"

        // Sensitive user credentials and data MUST be .protected
        let userProtected = [
            "\(fakeHome)/.ssh",
            "\(fakeHome)/.ssh/id_rsa",
            "\(fakeHome)/.gnupg",
            "\(fakeHome)/Library/Keychains",
            "\(fakeHome)/Library/Keychains/login.keychain-db",
            "\(fakeHome)/Library/Mail",
            "\(fakeHome)/Library/Messages",
            "\(fakeHome)/Pictures/Photos Library.photoslibrary"
        ]

        for path in userProtected {
            let (level, _) = SafetyGuard.evaluate(path: path, home: fakeHome)
            XCTAssertEqual(level, .protected, "Ruta sensible del usuario debe estar protegida: \(path)")
        }
    }

    func testSafetyGuardCleanablePaths() {
        let fakeHome = "/Users/testuser"

        // User personal directories must be .caution so confirmation is required
        let (docLevel, _) = SafetyGuard.evaluate(path: "\(fakeHome)/Documents/report.pdf", home: fakeHome)
        XCTAssertEqual(docLevel, .caution)

        let (desktopLevel, _) = SafetyGuard.evaluate(path: "\(fakeHome)/Desktop/file.txt", home: fakeHome)
        XCTAssertEqual(desktopLevel, .caution)

        // General cache paths outside structural roots should be .safe
        let (cacheLevel, _) = SafetyGuard.evaluate(path: "\(fakeHome)/Library/Caches/Google/Chrome/Default", home: fakeHome)
        XCTAssertEqual(cacheLevel, .safe)
    }

    // MARK: - 3. Dual-Mode Navigation Titles & Labels
    func testNavigationTabDualModeTitles() {
        // In Simple Mode: Human, friendly labels
        XCTAssertEqual(NavigationTab.dashboard.displayTitle(isAdvanced: false), "Inicio")
        XCTAssertEqual(NavigationTab.smartCaches.displayTitle(isAdvanced: false), "Archivos Temporales")
        XCTAssertEqual(NavigationTab.uninstaller.displayTitle(isAdvanced: false), "Mis Aplicaciones")
        XCTAssertEqual(NavigationTab.spaceLens.displayTitle(isAdvanced: false), "Explorar mi Disco")

        // In Advanced (Pro) Mode: Technical titles
        XCTAssertEqual(NavigationTab.dashboard.displayTitle(isAdvanced: true), "Resumen General")
        XCTAssertEqual(NavigationTab.smartCaches.displayTitle(isAdvanced: true), "Cachés y Paquetes")
        XCTAssertEqual(NavigationTab.uninstaller.displayTitle(isAdvanced: true), "Desinstalador Completo")
        XCTAssertEqual(NavigationTab.spaceLens.displayTitle(isAdvanced: true), "Explorador y Datos del Sistema")
    }

    // MARK: - 4. Scanner Logic and In-Memory Calculations
    @MainActor
    func testSystemScannerFreedSpaceRecording() {
        let scanner = SystemScannerService()
        XCTAssertEqual(scanner.sessionFreedBytes, 0)
        XCTAssertEqual(scanner.lastFreedDeltaBytes, 0)

        scanner.recordFreedSpace(1024 * 1024 * 50) // 50 MB
        XCTAssertEqual(scanner.sessionFreedBytes, 50 * 1024 * 1024)
        XCTAssertEqual(scanner.lastFreedDeltaBytes, 50 * 1024 * 1024)

        scanner.recordFreedSpace(1024 * 1024 * 25) // +25 MB
        XCTAssertEqual(scanner.sessionFreedBytes, 75 * 1024 * 1024)
        XCTAssertEqual(scanner.lastFreedDeltaBytes, 25 * 1024 * 1024)

        // Non-positive bytes must not alter freed counter
        scanner.recordFreedSpace(0)
        scanner.recordFreedSpace(-500)
        XCTAssertEqual(scanner.sessionFreedBytes, 75 * 1024 * 1024)
    }

    @MainActor
    func testActivityLogManagement() {
        let scanner = SystemScannerService()
        XCTAssertTrue(scanner.activityLogs.isEmpty)

        scanner.appendLog("Iniciando escaneo", detail: "Ruta /", level: .info)
        scanner.appendLog("Archivo eliminado", detail: "cache.tmp", level: .success)
        XCTAssertEqual(scanner.activityLogs.count, 2)
        XCTAssertEqual(scanner.activityLogs.first?.message, "Archivo eliminado")

        scanner.clearLogs()
        XCTAssertTrue(scanner.activityLogs.isEmpty)
    }

    @MainActor
    func testCacheItemSelectionToggles() {
        let scanner = SystemScannerService()
        let item1 = CleanableItem(
            name: "Chrome Cache",
            description: "Caché",
            impactNote: "Nota",
            path: "/tmp/chrome",
            category: .browsersAndApps,
            safety: .safe,
            sizeBytes: 1000,
            isSelected: true
        )
        let item2 = CleanableItem(
            name: "Papelera",
            description: "Papelera",
            impactNote: "Nota",
            path: "/tmp/trash",
            category: .systemAndGeneral,
            safety: .caution,
            sizeBytes: 5000,
            isSelected: false
        )
        scanner.cacheItems = [item1, item2]

        XCTAssertEqual(scanner.totalCacheBytes, 6000)
        XCTAssertEqual(scanner.totalSelectedCacheBytes, 1000)
        XCTAssertEqual(scanner.selectedCautionItemsCount, 0)

        // Select item2
        scanner.toggleCacheSelection(item2)
        XCTAssertEqual(scanner.totalSelectedCacheBytes, 6000)
        XCTAssertEqual(scanner.selectedCautionItemsCount, 1)

        // selectOnlySafeCaches should reset caution items
        scanner.selectOnlySafeCaches()
        XCTAssertEqual(scanner.selectedCautionItemsCount, 0)
        XCTAssertEqual(scanner.totalSelectedCacheBytes, 1000)
    }

    // MARK: - 5. InstalledAppInfo & Orphan Calculations
    func testInstalledAppInfoSizeCalculation() {
        let leftover1 = AppLeftoverFile(path: "/Library/Caches/com.test", kind: "Caché", sizeBytes: 200)
        let leftover2 = AppLeftoverFile(path: "/Library/Logs/com.test", kind: "Logs", sizeBytes: 300)

        let app = InstalledAppInfo(
            name: "TestApp",
            bundleId: "com.example.test",
            bundlePath: "/Applications/TestApp.app",
            appSizeBytes: 1000,
            leftovers: [leftover1, leftover2],
            lastUsedDate: nil,
            isSystemOrProtected: false,
            requiresAdminToTrash: false
        )

        XCTAssertEqual(app.leftoversSizeBytes, 500)
        XCTAssertEqual(app.totalSizeBytes, 1500)
    }
}
