#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_CONFIG="${1:-debug}"
APP_DIR="$ROOT_DIR/.build/Pi Agent.app"
LEGACY_APP_DIR="$ROOT_DIR/.build/PiAgentNative.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
SWIFTPM_BUILD_ROOT="${PI_AGENT_NATIVE_SWIFTPM_BUILD_ROOT:-$ROOT_DIR/.build}"

localizable_strings_path() {
  local bundle_dir="$1"
  local locale="$2"
  local expected_lproj

  expected_lproj="$(printf '%s.lproj' "$locale" | tr '[:upper:]' '[:lower:]')"

  while IFS= read -r strings_file; do
    local lproj_name
    lproj_name="$(basename "$(dirname "$strings_file")" | tr '[:upper:]' '[:lower:]')"

    if [[ "$lproj_name" == "$expected_lproj" ]]; then
      printf '%s\n' "$strings_file"
      return 0
    fi
  done < <(find "$bundle_dir" -maxdepth 2 -type f -name "Localizable.strings" | sort)

  return 1
}

bundle_contains_localizations() {
  local bundle_dir="$1"

  [[ -f "$bundle_dir/Info.plist" ]] \
    && localizable_strings_path "$bundle_dir" "en" >/dev/null \
    && localizable_strings_path "$bundle_dir" "pt-BR" >/dev/null
}

find_localization_resource_bundle() {
  local build_products_dir="$1"
  local candidate

  while IFS= read -r candidate; do
    if bundle_contains_localizations "$candidate"; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done < <(find "$build_products_dir" -maxdepth 2 -type d -name "*.bundle" | sort)

  return 1
}

copy_localization_resource_bundle() {
  local source_bundle="$1"
  local resources_dir="$2"
  local destination_bundle

  destination_bundle="$resources_dir/$(basename "$source_bundle")"
  rm -rf "$destination_bundle"
  cp -R "$source_bundle" "$destination_bundle"
  printf '%s\n' "$destination_bundle"
}

verify_packaged_localization_resources() {
  local packaged_bundle="$1"

  if [[ ! -d "$packaged_bundle" ]]; then
    echo "error: missing packaged localization bundle: $packaged_bundle" >&2
    return 1
  fi

  if ! localizable_strings_path "$packaged_bundle" "en" >/dev/null; then
    echo "error: missing packaged en Localizable.strings in $packaged_bundle" >&2
    return 1
  fi

  if ! localizable_strings_path "$packaged_bundle" "pt-BR" >/dev/null; then
    echo "error: missing packaged pt-BR Localizable.strings in $packaged_bundle" >&2
    return 1
  fi
}

main() {
  cd "$ROOT_DIR"
  swift build -c "$BUILD_CONFIG" --build-path "$SWIFTPM_BUILD_ROOT"

  local build_products_dir
  build_products_dir="$(swift build -c "$BUILD_CONFIG" --build-path "$SWIFTPM_BUILD_ROOT" --show-bin-path)"

  local resource_bundle
  if ! resource_bundle="$(find_localization_resource_bundle "$build_products_dir")"; then
    echo "error: SwiftPM localization resource bundle not found in $build_products_dir" >&2
    exit 1
  fi

  rm -rf "$APP_DIR" "$LEGACY_APP_DIR"
  mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

  cp "$build_products_dir/PiAgentNative" "$MACOS_DIR/PiAgentNative"
  cp "$ROOT_DIR/Assets/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"

  local packaged_resource_bundle
  packaged_resource_bundle="$(copy_localization_resource_bundle "$resource_bundle" "$RESOURCES_DIR")"

  cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>PiAgentNative</string>
  <key>CFBundleIdentifier</key>
  <string>dev.pi.agent.native</string>
  <key>CFBundleName</key>
  <string>Pi Agent</string>
  <key>CFBundleDisplayName</key>
  <string>Pi Agent</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleLocalizations</key>
  <array>
    <string>en</string>
    <string>pt-BR</string>
  </array>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

  verify_packaged_localization_resources "$packaged_resource_bundle"

  echo "$APP_DIR"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
