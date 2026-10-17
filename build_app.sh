#!/bin/zsh
set -e

APP_NAME="RamanSweep"
BUNDLE_DIR="${APP_NAME}.app"
CONTENTS_DIR="${BUNDLE_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "🔨 Compilando ${APP_NAME} (Adventurous Raman Edition) en modo Release..."
swift build -c release

echo "📦 Empaquetando ${BUNDLE_DIR}..."
rm -rf "${BUNDLE_DIR}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

cp ".build/release/${APP_NAME}" "${MACOS_DIR}/${APP_NAME}"

cat > "${CONTENTS_DIR}/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.mainlake.ramansweep</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>2.0.0</string>
    <key>CFBundleVersion</key>
    <string>3</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>RamanSweep usa Finder para enviar aplicaciones al Basurero sin requerir contraseña.</string>
    <key>NSSystemAdministrationUsageDescription</key>
    <string>RamanSweep administra aplicaciones instaladas en tu Mac para desinstalarlas sin dejar residuos.</string>
</dict>
</plist>
EOF

echo "🔏 Firmando ${BUNDLE_DIR} con identificador com.mainlake.ramansweep..."
codesign --force --deep --sign - --identifier "com.mainlake.ramansweep" "${BUNDLE_DIR}"

echo "✅ ${BUNDLE_DIR} creado y firmado exitosamente."
