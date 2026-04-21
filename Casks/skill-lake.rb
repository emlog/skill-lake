cask "skill-lake" do
  version "1.1.7"
  sha256 "418652742ff5fff58e4bcb6dde0a89d53a1f2d9e2d72bd9a51c204194f952ca5"

  url "https://github.com/emlog/skill-lake/releases/download/1.1.7/SkillLake-1.1.7.dmg"
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
