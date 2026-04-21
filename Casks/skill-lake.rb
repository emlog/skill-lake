cask "skill-lake" do
  version "1.1.8"
  sha256 "3f03f8500abea1ab6852d433f0c1343caf316cdbfdca7805f7deb95f6c3842fc"

  url "https://github.com/emlog/skill-lake/releases/download/1.1.8/SkillLake-1.1.8.dmg"
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
