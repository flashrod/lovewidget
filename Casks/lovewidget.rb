cask "lovewidget" do
  version "1.0.2"
  sha256 "045a761c861570686ff48a997bcd5411b562b8152cc615763c3d993a7bfc6cc3"

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
