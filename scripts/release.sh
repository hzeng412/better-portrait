#!/bin/bash
# BetterPortrait release script
# Usage: ./scripts/release.sh <version> <build_number> "Release notes line 1" "Release notes line 2" ...
# Example: ./scripts/release.sh 1.3 4 "Added dark mode" "Fixed export bug"

set -e

NEW_VERSION=$1
BUILD_NUMBER=$2
shift 2
RELEASE_NOTES=("$@")

if [ -z "$NEW_VERSION" ] || [ -z "$BUILD_NUMBER" ]; then
    echo "Usage: $0 <version> <build_number> \"note 1\" \"note 2\" ..."
    echo "Example: $0 1.3 4 \"Added dark mode\" \"Fixed export bug\""
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PBXPROJ="$PROJECT_ROOT/BetterPortrait/BetterPortrait.xcodeproj/project.pbxproj"
APPCAST="$PROJECT_ROOT/appcast.xml"
DMG_NAME="BetterPortrait-$NEW_VERSION.dmg"
DMG_PATH="/tmp/$DMG_NAME"
ARCHIVE_PATH="/tmp/BetterPortrait.xcarchive"
EXPORT_PATH="/tmp/BetterPortraitExport"
TODAY=$(date -u "+%a, %d %b %Y 00:00:00 +0000")

echo "==> Releasing BetterPortrait v$NEW_VERSION (build $BUILD_NUMBER)"

# ── 1. Bump version ──────────────────────────────────────────────────────────
CURRENT_VERSION=$(grep "MARKETING_VERSION" "$PBXPROJ" | head -1 | sed 's/.*= //;s/;//')
CURRENT_BUILD=$(grep "CURRENT_PROJECT_VERSION" "$PBXPROJ" | head -1 | sed 's/.*= //;s/;//')
echo "==> Bumping $CURRENT_VERSION (build $CURRENT_BUILD) -> $NEW_VERSION (build $BUILD_NUMBER)"
sed -i '' "s/MARKETING_VERSION = $CURRENT_VERSION;/MARKETING_VERSION = $NEW_VERSION;/g" "$PBXPROJ"
sed -i '' "s/CURRENT_PROJECT_VERSION = $CURRENT_BUILD;/CURRENT_PROJECT_VERSION = $BUILD_NUMBER;/g" "$PBXPROJ"

# ── 2. Archive ────────────────────────────────────────────────────────────────
echo "==> Archiving..."
rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH"
cd "$PROJECT_ROOT/BetterPortrait"
xcodebuild -scheme BetterPortrait -configuration Release archive \
    -archivePath "$ARCHIVE_PATH" 2>&1 | grep -E "error:|ARCHIVE (SUCCEEDED|FAILED)"

# ── 3. Export .app ────────────────────────────────────────────────────────────
echo "==> Exporting..."
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist /dev/stdin <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>mac-application</string>
    <key>destination</key>
    <string>export</string>
</dict>
</plist>
PLIST

# ── 4. Create DMG ─────────────────────────────────────────────────────────────
echo "==> Creating DMG..."
rm -f "$DMG_PATH"
hdiutil create -volname "BetterPortrait" \
    -srcfolder "$EXPORT_PATH/BetterPortrait.app" \
    -ov -format UDZO -o "$DMG_PATH"

# ── 5. Commit version bump + push ─────────────────────────────────────────────
echo "==> Committing version bump..."
cd "$PROJECT_ROOT"
git add BetterPortrait/BetterPortrait.xcodeproj/project.pbxproj
# Stage any other changed source files (models, views, viewmodels, services)
git add BetterPortrait/BetterPortrait/ 2>/dev/null || true
git commit -m "Bump version to $NEW_VERSION"
git push origin main

# ── 6. Build release notes ────────────────────────────────────────────────────
GH_NOTES=""
APPCAST_NOTES=""
for note in "${RELEASE_NOTES[@]}"; do
    GH_NOTES+="- $note"$'\n'
    APPCAST_NOTES+="          <li>$note</li>"$'\n'
done

# ── 7. Create GitHub release + upload DMG ────────────────────────────────────
echo "==> Creating GitHub release v$NEW_VERSION..."
gh release create "v$NEW_VERSION" "$DMG_PATH" \
    --title "v$NEW_VERSION" \
    --notes "$GH_NOTES"

# ── 8. Sign DMG with Sparkle ──────────────────────────────────────────────────
echo "==> Signing DMG..."
SIGN_UPDATE=$(find ~/Library/Developer/Xcode/DerivedData -name "sign_update" \
    -path "*/artifacts/sparkle/*" 2>/dev/null | head -1)
if [ -z "$SIGN_UPDATE" ]; then
    echo "ERROR: Could not find Sparkle sign_update. Build the project in Xcode first."
    exit 1
fi

SIGNATURE_LINE=$("$SIGN_UPDATE" "$DMG_PATH")
ED_SIG=$(echo "$SIGNATURE_LINE" | grep -o 'sparkle:edSignature="[^"]*"' | sed 's/sparkle:edSignature="//;s/"//')
DMG_LENGTH=$(echo "$SIGNATURE_LINE" | grep -o 'length="[0-9]*"' | sed 's/length="//;s/"//')
echo "    edSignature: $ED_SIG"
echo "    length:      $DMG_LENGTH"

# ── 9. Prepend new item to appcast.xml ───────────────────────────────────────
echo "==> Updating appcast.xml..."
python3 - "$APPCAST" "$NEW_VERSION" "$BUILD_NUMBER" "$TODAY" \
    "$ED_SIG" "$DMG_LENGTH" "$DMG_NAME" "$APPCAST_NOTES" <<'PYEOF'
import sys, re

appcast_path, version, build, pub_date, ed_sig, length, dmg_name, notes_html = sys.argv[1:]

download_url = f"https://github.com/hzeng412/better-portrait/releases/download/v{version}/{dmg_name}"

new_item = f"""    <item>
      <title>Version {version}</title>
      <sparkle:version>{build}</sparkle:version>
      <sparkle:shortVersionString>{version}</sparkle:shortVersionString>
      <description><![CDATA[
        <ul>
{notes_html}        </ul>
      ]]></description>
      <pubDate>{pub_date}</pubDate>
      <sparkle:minimumSystemVersion>15.0</sparkle:minimumSystemVersion>
      <enclosure url="{download_url}"
                 sparkle:edSignature="{ed_sig}"
                 length="{length}"
                 type="application/octet-stream" />
    </item>"""

with open(appcast_path, "r") as f:
    content = f.read()

# Insert after <language>en</language>
content = re.sub(
    r'(<language>en</language>\s*)',
    r'\1\n' + new_item + '\n',
    content
)

with open(appcast_path, "w") as f:
    f.write(content)

print("    appcast.xml updated.")
PYEOF

# ── 10. Commit + push appcast ─────────────────────────────────────────────────
echo "==> Committing appcast.xml..."
git add appcast.xml
git commit -m "Update appcast.xml for v$NEW_VERSION"
git push origin main

echo ""
echo "==> Done! BetterPortrait v$NEW_VERSION released."
echo "    https://github.com/hzeng412/better-portrait/releases/tag/v$NEW_VERSION"
echo ""
echo "    Existing users will be notified via Sparkle on their next update check."
