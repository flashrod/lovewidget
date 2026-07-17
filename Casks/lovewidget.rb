cask "lovewidget" do
  version "1.0.0"
  sha256 "9a296b62dcfa37d23a621e4fc3fa4943e91ae8f5d81d47c595d2d55ba338dc02"

  url "https://github.com/flashrod/LoveWidget/releases/download/v#{version}/LoveWidget-#{version}.dmg"
  name "LoveWidget"
  desc "Share a drawing canvas with your partner — in your menu bar"
  homepage "https://github.com/flashrod/LoveWidget"

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
