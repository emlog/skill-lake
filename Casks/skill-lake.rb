cask "skill-lake" do
  version "1.2.7"
  sha256 "aee866b8aecd2d245096f80c653f59c2caaee111d2544ff8d297f307476deb32"

  url "https://github.com/emlog/skill-lake/releases/download/v1.2.7/skill-lake-1.2.7-arm64.dmg"
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
