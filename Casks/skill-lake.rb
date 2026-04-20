cask "skill-lake" do
  version "1.1.4"
  sha256 "2fa2d4f3b462a2fc76e620b144b130c3e697b353ccbd92423e8b245060c57795"

  url "https://github.com/emlog/skill-lake/releases/download/1.1.4/SkillLake-1.1.4.dmg"
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
