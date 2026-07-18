cask "lovewidget" do
  version "1.0.3"
  sha256 "6ed91a62e5e7026653992216a6e732bad1ba5684ff1413383b8ad6aecd9c77d4"

  url "https://github.com/flashrod/lovewidget/releases/download/v#{version}/LoveWidget-#{version}.dmg"
  name "LoveWidget"
  desc "Share a drawing canvas with your partner in your menu bar"
  homepage "https://github.com/flashrod/lovewidget"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates false

  app "LoveWidget.app"

  uninstall quit: "com.lovewidget.app"

  zap trash: [
    "~/Library/Preferences/com.lovewidget.app.plist",
    "~/Library/Application Support/lovewidget",
  ]
end
