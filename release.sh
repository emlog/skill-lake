#!/bin/zsh

export PATH="/opt/homebrew/bin:$PATH"

# Function to display error and exit
error_exit() {
    echo "❌ Error: $1"
    exit 1
}

# 1. Run validation checks
echo "🔍 Running code analysis..."
flutter analyze || error_exit "Code analysis failed"

echo "🔍 Checking code formatting..."
dart format --output=none --set-exit-if-changed . || error_exit "Code formatting check failed. Please run 'dart format .'"

# 2. Version handling
if [ -n "$1" ]; then
    NEW_VERSION=$1
    echo "🆙 Bumping version to $NEW_VERSION in pubspec.yaml..."
    # macOS sed handles -i differently, so we use a temporary file or a simpler approach
    sed -i '' "s/^version: .*/version: $NEW_VERSION/" pubspec.yaml || error_exit "Failed to update version in pubspec.yaml"
fi

# Extract version from pubspec.yaml
VERSION=$(grep '^version: ' pubspec.yaml | awk '{print $2}' | cut -d '+' -f 1)
[ -z "$VERSION" ] && error_exit "Could not extract version from pubspec.yaml"
echo "✅ Version to release: $VERSION"

# 3. Build the app
echo "🏗️ Building Flutter macOS in release mode..."
flutter build macos --release || error_exit "Build failed"

APP_PATH="build/macos/Build/Products/Release/Skill Lake.app"
ARCH=$(uname -m)
DMG_NAME="skill-lake-${VERSION}-${ARCH}.dmg"

if [ ! -d "$APP_PATH" ]; then
    error_exit "App build failed or path not found at $APP_PATH"
fi

# 4. Create DMG
echo "📦 Creating DMG package..."
[ -f "$DMG_NAME" ] && rm "$DMG_NAME"

DMG_STAGING_DIR="build/macos/Build/Products/Release/dmg_staging"
rm -rf "$DMG_STAGING_DIR"
mkdir -p "$DMG_STAGING_DIR"

cp -R "$APP_PATH" "$DMG_STAGING_DIR/"
ln -s /Applications "$DMG_STAGING_DIR/Applications"

hdiutil create -volname "Skill Lake" -srcfolder "$DMG_STAGING_DIR" -ov -format UDZO "$DMG_NAME" || error_exit "DMG creation failed"
rm -rf "$DMG_STAGING_DIR"

# 5. Update Local Homebrew Cask
echo "🏠 Updating Homebrew Cask (local)..."
mkdir -p Casks
SHA=$(shasum -a 256 "$DMG_NAME" | awk '{print $1}')
cat <<EOF > Casks/skill-lake.rb
cask "skill-lake" do
  version "${VERSION}"
  sha256 "${SHA}"

  url "https://github.com/emlog/skill-lake/releases/download/${VERSION}/${DMG_NAME}"
  name "Skill Lake"
  desc "A local AI agent skill manager app for macOS"
  homepage "https://github.com/emlog/skill-lake"

  app "Skill Lake.app"

  zap trash: [
    "~/Library/Application Support/com.emlog.skillLake",
    "~/Library/Preferences/com.emlog.skillLake.plist",
    "~/Library/Saved Application State/com.emlog.skillLake.savedState",
  ]
end
EOF

# 6. Git Operations
echo "🚀 Committing and Tagging in Git..."
git add pubspec.yaml
git add Casks/skill-lake.rb
git diff --cached --quiet || git commit -m "chore: release ${VERSION}"
git tag -f "${VERSION}"
git push origin main
git push origin "${VERSION}" -f

# 7. GitHub Release
echo "🐙 Creating GitHub Release..."
gh release view "${VERSION}" >/dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "Release ${VERSION} already exists. Overwriting asset..."
  gh release edit "${VERSION}" --title "v${VERSION}"
  gh release upload "${VERSION}" "$DMG_NAME" --clobber
else
  gh release create "${VERSION}" "$DMG_NAME" --title "v${VERSION}" --notes "Release version ${VERSION}"
fi

# 8. Update Homebrew Tap
echo "🍺 Updating Homebrew Tap..."
TAP_REPO="emlog/homebrew-skill-lake"
TAP_DIR="homebrew-skill-lake"

gh repo view "$TAP_REPO" >/dev/null 2>&1 || gh repo create "$TAP_REPO" --public --description "Homebrew tap for Skill Lake"

rm -rf "$TAP_DIR"
gh repo clone "$TAP_REPO" "$TAP_DIR"
mkdir -p "$TAP_DIR/Casks"

cat <<EOF > "$TAP_DIR/Casks/skill-lake.rb"
cask "skill-lake" do
  version "${VERSION}"
  sha256 "${SHA}"

  url "https://github.com/emlog/skill-lake/releases/download/${VERSION}/${DMG_NAME}"
  name "Skill Lake"
  desc "A local AI agent skill manager app for macOS"
  homepage "https://github.com/emlog/skill-lake"

  app "Skill Lake.app"

  zap trash: [
    "~/Library/Application Support/com.emlog.skillLake",
    "~/Library/Preferences/com.emlog.skillLake.plist",
    "~/Library/Saved Application State/com.emlog.skillLake.savedState",
  ]
end
EOF

cd "$TAP_DIR"
git add Casks/skill-lake.rb
git diff --cached --quiet || git commit -m "update skill-lake to ${VERSION}"
git push origin main
cd ..
rm -rf "$TAP_DIR"

echo "✨ Release version $VERSION successfully completed!"
