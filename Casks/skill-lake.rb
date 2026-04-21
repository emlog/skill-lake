cask "skill-lake" do
  version "1.1.6"
  sha256 "f5b500ecd05d357b5c369be4e3d32089e5e915493da70587a75b4ac1ae86e790"

  url "https://github.com/emlog/skill-lake/releases/download/1.1.6/SkillLake-1.1.6.dmg"
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
