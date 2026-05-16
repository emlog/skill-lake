cask "skill-lake" do
  version "1.2.9"
  sha256 "8b2b575deadcf4cf4cb20489024830fc1cd73b694112dad75158984f4dc800d3"

  url "https://github.com/emlog/skill-lake/releases/download/v1.2.9/skill-lake-1.2.9-arm64.dmg"
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
