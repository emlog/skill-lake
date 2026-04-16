#!/bin/zsh

export PATH="/opt/homebrew/bin:$PATH"

echo "Building Flutter macOS in release mode..."
flutter build macos --release

APP_PATH="build/macos/Build/Products/Release/Skill Lake.app"
DMG_NAME="SkillLake-1.1.0.dmg"

if [ ! -d "$APP_PATH" ]; then
    echo "Error: App build failed or path not found at $APP_PATH"
    exit 1
fi

echo "Creating DMG package..."
if [ -f "$DMG_NAME" ]; then
    rm "$DMG_NAME"
fi

# Create a staging directory to include the the app and the Applications symlink
DMG_STAGING_DIR="build/macos/Build/Products/Release/dmg_staging"
mkdir -p "$DMG_STAGING_DIR"
rm -rf "$DMG_STAGING_DIR"/*

cp -R "$APP_PATH" "$DMG_STAGING_DIR/"
ln -s /Applications "$DMG_STAGING_DIR/Applications"

hdiutil create -volname "Skill Lake" -srcfolder "$DMG_STAGING_DIR" -ov -format UDZO "$DMG_NAME"

# Clean up staging directory
rm -rf "$DMG_STAGING_DIR"

echo "Committing and Tagging in Git..."
git add -u
git diff --cached --quiet || git commit -m "chore: release 1.1.0"
git tag -f 1.1.0
git push origin main
git push origin 1.1.0 -f

echo "Creating GitHub Release..."
# Make sure to handle if the release already exists
gh release view 1.1.0 >/dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "Release 1.1.0 already exists. Overwriting asset..."
  gh release upload 1.1.0 "$DMG_NAME" --clobber
else
  gh release create 1.1.0 "$DMG_NAME" --title "Skill Lake 1.1.0" --notes "UI 全新改版，优化了视觉层级和使用体验。"
fi

echo "Release successfully completed!"
