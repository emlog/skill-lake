cask "skill-lake" do
  version "1.2.8"
  sha256 "a800bafea7aeca70473ef3b8565af0a5e9e60b2866ae846738b03997f7893d1a"

  url "https://github.com/emlog/skill-lake/releases/download/v1.2.8/skill-lake-1.2.8-arm64.dmg"
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
