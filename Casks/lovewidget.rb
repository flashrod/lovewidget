cask "lovewidget" do
  version "1.0.4"
  sha256 "504364362079e8498ffa884426feee2d8614c247ead84abb55b70501c3a405eb"

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
