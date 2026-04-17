#!/bin/zsh

export PATH="/opt/homebrew/bin:$PATH"

echo "Building Flutter macOS in release mode..."
flutter build macos --release

# Extract version from pubspec.yaml
VERSION=$(grep '^version: ' pubspec.yaml | awk '{print $2}' | cut -d '+' -f 1)
if [ -z "$VERSION" ]; then
    echo "Error: Could not extract version from pubspec.yaml"
    exit 1
fi
echo "Extracted version: $VERSION"

APP_PATH="build/macos/Build/Products/Release/Skill Lake.app"
DMG_NAME="SkillLake-${VERSION}.dmg"

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
rm -rf "$DMG_STAGING_DIR"
mkdir -p "$DMG_STAGING_DIR"

cp -R "$APP_PATH" "$DMG_STAGING_DIR/"
ln -s /Applications "$DMG_STAGING_DIR/Applications"

hdiutil create -volname "Skill Lake" -srcfolder "$DMG_STAGING_DIR" -ov -format UDZO "$DMG_NAME"

# Clean up staging directory
rm -rf "$DMG_STAGING_DIR"

echo "Updating Homebrew Cask (local)..."
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

echo "Committing and Tagging in Git..."
git add -u
git add Casks/skill-lake.rb
git diff --cached --quiet || git commit -m "chore: release ${VERSION}"
git tag -f "${VERSION}"
git push origin main
git push origin "${VERSION}" -f

echo "Creating GitHub Release..."
# Make sure to handle if the release already exists
gh release view "${VERSION}" >/dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "Release ${VERSION} already exists. Overwriting asset..."
  gh release upload "${VERSION}" "$DMG_NAME" --clobber
else
  gh release create "${VERSION}" "$DMG_NAME" --title "Skill Lake ${VERSION}" --notes "Release version ${VERSION}"
fi

echo "Release successfully completed!"

echo "Updating Homebrew Tap..."
TAP_REPO="emlog/homebrew-skill-lake"
TAP_DIR="homebrew-skill-lake"
SHA=$(shasum -a 256 "$DMG_NAME" | awk '{print $1}')

gh repo view "$TAP_REPO" >/dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "Creating tap repository $TAP_REPO..."
  gh repo create "$TAP_REPO" --public --description "Homebrew tap for Skill Lake"
fi

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

echo "Homebrew tap updated!"
