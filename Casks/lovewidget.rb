cask "lovewidget" do
  version "1.0.5"
  sha256 "0249ee3f7db8c72cc88c62970543175e6b0ff9f8b5b1ee8112f153fdf192e509"

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
