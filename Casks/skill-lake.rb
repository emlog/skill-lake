cask "skill-lake" do
  version "1.1.3"
  sha256 "cbf90a50bcbaf35e702cf8f9f29d385a60ee96edb57dab514388f828222fa260"

  url "https://github.com/emlog/skill-lake/releases/download/1.1.3/SkillLake-1.1.3.dmg"
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
