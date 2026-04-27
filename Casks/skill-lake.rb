cask "skill-lake" do
  version "1.2.0"
  sha256 "73ee32516672dd2c0216140ce51c1fbed42bf3a214df6120af133c7e0ab9c677"

  url "https://github.com/emlog/skill-lake/releases/download/1.2.0/skill-lake-1.2.0-arm64.dmg"
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
