cask "skill-lake" do
  version "1.3.0"
  sha256 "e2636e45a6264ddcc8c465f32f68fbd43a0505a2ce6bfd1fec236b0e0af6b3e8"

  url "https://github.com/emlog/skill-lake/releases/download/v1.3.0/skill-lake-1.3.0-arm64.dmg"
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
