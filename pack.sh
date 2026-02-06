#!/usr/bin/env bash
set -euo pipefail

APP_NAME="BLEControlApp"
BUNDLE_ID="com.gustavosore.blecontrolapp"
VERSION="1.0.0"
BUILD="1"
MIN_MACOS="13.0"

ROOT="$(pwd)"
BUILD_DIR="$ROOT/.build/release"
DIST_DIR="$ROOT/dist"
APP_DIR="$DIST_DIR/${APP_NAME}.app"
CONTENTS="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RES_DIR="$CONTENTS/Resources"

ICON_PNG="$ROOT/icon.png"
ICONSET_DIR="$DIST_DIR/AppIcon.iconset"
ICON_ICNS="$RES_DIR/AppIcon.icns"

echo "==> Build release"
swift build -c release

mkdir -p "$DIST_DIR"

# ------------------------------------------------------------
# 1) Icon.png: use existing or generate fallback
# ------------------------------------------------------------
if [[ ! -f "$ICON_PNG" ]]; then
  echo "==> icon.png não encontrado. Gerando ícone automático..."
  swift - <<'SWIFT'
import AppKit

let size = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

guard let ctx = NSGraphicsContext.current?.cgContext else {
    fputs("Falha ao criar contexto gráfico\n", stderr)
    exit(1)
}

let rect = CGRect(x: 0, y: 0, width: size, height: size)

// Background gradient
let colors = [NSColor(calibratedRed: 0.07, green: 0.10, blue: 0.20, alpha: 1).cgColor,
              NSColor(calibratedRed: 0.12, green: 0.55, blue: 0.95, alpha: 1).cgColor] as CFArray
let locations: [CGFloat] = [0, 1]
if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locations) {
    ctx.drawLinearGradient(grad,
                           start: CGPoint(x: 0, y: 0),
                           end: CGPoint(x: size, y: size),
                           options: [])
}

// Rounded card
let card = CGRect(x: 120, y: 120, width: 784, height: 784)
let path = NSBezierPath(roundedRect: card, xRadius: 180, yRadius: 180)
NSColor(calibratedWhite: 1.0, alpha: 0.12).setFill()
path.fill()

// BLE-ish waves
func strokeArc(_ center: CGPoint, _ radius: CGFloat, _ lw: CGFloat, _ alpha: CGFloat) {
    let p = NSBezierPath()
    p.appendArc(withCenter: center, radius: radius, startAngle: 220, endAngle: 320)
    p.lineWidth = lw
    NSColor(calibratedWhite: 1.0, alpha: alpha).setStroke()
    p.stroke()
}
let c = CGPoint(x: size/2, y: size/2 + 20)
strokeArc(c, 140, 24, 0.95)
strokeArc(c, 220, 20, 0.75)
strokeArc(c, 300, 16, 0.55)

// Center dot
let dot = NSBezierPath(ovalIn: CGRect(x: c.x - 28, y: c.y - 28, width: 56, height: 56))
NSColor.white.setFill()
dot.fill()

image.unlockFocus()

guard
  let tiff = image.tiffRepresentation,
  let rep = NSBitmapImageRep(data: tiff),
  let png = rep.representation(using: .png, properties: [:])
else {
  fputs("Falha ao serializar PNG\n", stderr)
  exit(1)
}

let outURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("icon.png")
do {
    try png.write(to: outURL)
    print("icon.png gerado em \(outURL.path)")
} catch {
    fputs("Erro ao salvar icon.png: \(error)\n", stderr)
    exit(1)
}
SWIFT
else
  echo "==> Usando icon.png existente"
fi

# ------------------------------------------------------------
# 2) Build .icns from icon.png
# ------------------------------------------------------------
echo "==> Gerando AppIcon.icns"
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

# helper
mkicon () {
  local size="$1"
  local name="$2"
  sips -z "$size" "$size" "$ICON_PNG" --out "$ICONSET_DIR/$name" >/dev/null
}

mkicon 16   icon_16x16.png
mkicon 32   icon_16x16@2x.png
mkicon 32   icon_32x32.png
mkicon 64   icon_32x32@2x.png
mkicon 128  icon_128x128.png
mkicon 256  icon_128x128@2x.png
mkicon 256  icon_256x256.png
mkicon 512  icon_256x256@2x.png
mkicon 512  icon_512x512.png
mkicon 1024 icon_512x512@2x.png

iconutil -c icns "$ICONSET_DIR" -o "$DIST_DIR/AppIcon.icns"

# ------------------------------------------------------------
# 3) Recreate .app bundle
# ------------------------------------------------------------
echo "==> Recriando app bundle"
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RES_DIR"

cp "$BUILD_DIR/$APP_NAME" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"
cp "$DIST_DIR/AppIcon.icns" "$ICON_ICNS"

cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>

  <key>CFBundleExecutable</key>
  <string>${APP_NAME}</string>

  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>

  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>

  <key>CFBundleName</key>
  <string>${APP_NAME}</string>

  <key>CFBundleDisplayName</key>
  <string>${APP_NAME}</string>

  <key>CFBundlePackageType</key>
  <string>APPL</string>

  <key>CFBundleShortVersionString</key>
  <string>${VERSION}</string>

  <key>CFBundleVersion</key>
  <string>${BUILD}</string>

  <key>LSMinimumSystemVersion</key>
  <string>${MIN_MACOS}</string>

  <key>NSPrincipalClass</key>
  <string>NSApplication</string>

  <key>NSBluetoothAlwaysUsageDescription</key>
  <string>Este app usa Bluetooth para encontrar e controlar o Arduino via BLE.</string>

  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
</dict>
</plist>
PLIST

echo "==> Assinando (ad-hoc)"
codesign --force --deep --sign - "$APP_DIR"

echo "==> Verificando"
codesign --verify --deep --strict "$APP_DIR" || true
spctl --assess --type execute "$APP_DIR" || true

echo "==> Pronto"
echo "App: $APP_DIR"
echo "Abrir: open \"$APP_DIR\""