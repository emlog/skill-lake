cask "skill-lake" do
  version "1.1.5"
  sha256 "2706e19c95a88a0796d0e7f284d775b20283b6a31f041cee54c36a982b4a7726"

  url "https://github.com/emlog/skill-lake/releases/download/1.1.5/SkillLake-1.1.5.dmg"
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
