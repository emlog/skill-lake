cask "skill-lake" do
  version "1.2.0"
  sha256 "a579a84961b90426e121c2f7114f51cb7df94b83056e274f4f8e26b1f6527e0d"

  url "https://github.com/emlog/skill-lake/releases/download/1.2.0/SkillLake-1.2.0.dmg"
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
