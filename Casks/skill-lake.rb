cask "skill-lake" do
  version "1.1.9"
  sha256 "4cdc04780cdda3c1e7a496ceee9616ddfd6a6092bfd6857bff1b37b539bd8704"

  url "https://github.com/emlog/skill-lake/releases/download/1.1.9/SkillLake-1.1.9.dmg"
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
