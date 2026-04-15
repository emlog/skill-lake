#!/bin/zsh

export PATH="/opt/homebrew/bin:$PATH"

echo "Building Flutter macOS in release mode..."
flutter build macos --release

APP_PATH="build/macos/Build/Products/Release/Skill Lake.app"
DMG_NAME="SkillLake-1.0.0.dmg"

if [ ! -d "$APP_PATH" ]; then
    echo "Error: App build failed or path not found at $APP_PATH"
    exit 1
fi

echo "Creating DMG package..."
if [ -f "$DMG_NAME" ]; then
    rm "$DMG_NAME"
fi
hdiutil create -volname "Skill Lake" -srcfolder "$APP_PATH" -ov -format UDZO "$DMG_NAME"

echo "Committing and Tagging in Git..."
git add README.md
git diff --cached --quiet || git commit -m "chore: optimize README and prepare for 1.0.0 release"
git tag -f 1.0.0
git push origin main
git push origin 1.0.0 -f

echo "Creating GitHub Release..."
# Make sure to handle if the release already exists
gh release view 1.0.0 >/dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "Release 1.0.0 already exists. Overwriting asset..."
  gh release upload 1.0.0 "$DMG_NAME" --clobber
else
  gh release create 1.0.0 "$DMG_NAME" --title "Skill Lake 1.0.0" --notes "第一版 macOS 桌面应用正式发布！"
fi

echo "Release successfully completed!"
