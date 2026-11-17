#!/bin/zsh
set -eu
cd "${0:A:h:h}"
mkdir -p build/ios
touch build/.gdignore
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --editor --quit
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release iOS build/ios/HuangtianRacing.xcodeproj
# iOS 启动屏：用纯奶油底，避免 storyboard 图片被系统按 1x 放大露边；品牌图改在游戏内整屏铺满
cp tools/ios/LaunchScreen.storyboard "build/ios/HuangtianRacing/Launch Screen.storyboard"
build_no=$(date +%y%m%d%H%M)
xcodebuild -project build/ios/HuangtianRacing.xcodeproj -scheme HuangtianRacing -configuration Release -destination 'generic/platform=iOS' -derivedDataPath build/ios-derived CURRENT_PROJECT_VERSION=$build_no DEVELOPMENT_TEAM=83Q33JCJ4Y CODE_SIGN_STYLE=Automatic CODE_SIGN_IDENTITY='Apple Development' -allowProvisioningUpdates -allowProvisioningDeviceRegistration build
app=build/ios-derived/Build/Products/Release-iphoneos/HuangtianRacing.app
codesign --verify --deep --strict "$app"
if [[ -n "${1:-}" ]]; then
  xcrun devicectl device uninstall app --device "$1" com.lizifa.huangtianmancang >/dev/null 2>&1 || true
  xcrun devicectl device install app --device "$1" "$app"
fi
