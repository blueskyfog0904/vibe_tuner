# T8-2 Icon & Splash Pipeline

## Source Assets
- App icon source: `assets/branding/app_icon.png` (1024x1024)
- Splash logo source: `assets/branding/splash_logo.png` (1024x1024)

## Tooling
- `flutter_launcher_icons` (app icons)
- `flutter_native_splash` (launch/splash screens)

Configured in `pubspec.yaml`:
- `flutter_launcher_icons`
- `flutter_native_splash`

## Generate Commands
Run from repository root:

```bash
flutter pub get
flutter pub run flutter_launcher_icons
flutter pub run flutter_native_splash:create
```

## Output (updated by tooling)
- Android launcher icons: `android/app/src/main/res/mipmap-*/ic_launcher.png`
- iOS app icons: `ios/Runner/Assets.xcassets/AppIcon.appiconset/*`
- Android splash resources:
  - `android/app/src/main/res/drawable/launch_background.xml`
  - `android/app/src/main/res/drawable-v21/launch_background.xml`
  - `android/app/src/main/res/values-v31/styles.xml`
  - `android/app/src/main/res/values-night-v31/styles.xml`
- iOS splash metadata:
  - `ios/Runner/Info.plist`

## Done Criteria
- 아이콘/스플래시 생성 명령이 오류 없이 동작한다.
- `flutter analyze` / `flutter test --no-pub` 통과.
- 앱 실행 시 런처 아이콘/스플래시가 리브랜딩 자산으로 반영된다.
