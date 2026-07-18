cask "lovewidget" do
  version "1.0.5"
  sha256 "504b01ae8000bc37433de8113afbfb1b9b36f46f112fbe44be1d4b09b1ad6e06"

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
