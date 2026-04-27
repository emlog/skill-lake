cask "skill-lake" do
  version "1.2.6"
  sha256 "c43279238f9633a0123c34667fd144eec3c7d6a7cee68e6b3e95bbcbe9a9afe4"

  url "https://github.com/emlog/skill-lake/releases/download/v1.2.6/skill-lake-1.2.6-arm64.dmg"
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
