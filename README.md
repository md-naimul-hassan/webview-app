# Hostinger Panel (Android)

A lightweight Flutter app that loads the real Hostinger hPanel site
(<https://hpanel.hostinger.com/>) in a full-screen Android WebView. It does not
copy or rebuild any part of the website.

## Features

- Opens hPanel at launch. JavaScript and DOM storage are on, and cookies/sessions persist between launches.
- Pages on `hostinger.com` and its subdomains stay in the app. Other sites open in the default browser. `mailto:`, `tel:` and `intent:` links go to the matching app.
- Android back button: goes back in WebView history, and closes the app when there is no earlier page.
- White native splash screen, a loader for the first page, and a thin progress bar for later pages. The bar waits 250 ms before showing, so fast navigations don't flicker.
- Offline/error screen with a **Retry** button. It only appears when the main page fails, not when an image or script fails.
- File uploads (`<input type="file">`) use the system document picker. Downloads use Android's DownloadManager and pass the session cookie along.
- JavaScript `alert` / `confirm` / `prompt` show as Material dialogs. `target=_blank` and `window.open` go through the same domain rules.
- Security:
  - SSL errors are never bypassed.
  - Cleartext HTTP is disabled. Hostinger `http://` links are upgraded to HTTPS.
  - Mixed content is blocked.
  - The WebView can't read local files.
  - `javascript:`, `file:`, `data:` and `blob:` navigations are blocked.
  - `allowBackup` is off, so cookies aren't copied into backups.
  - CAPTCHA and MFA flows run untouched in the WebView.

## Project structure

```
webview/
├── android/
│   ├── app/build.gradle.kts            # app id, release signing, R8
│   └── app/src/main/
│       ├── AndroidManifest.xml          # INTERNET, no cleartext, <queries>
│       ├── kotlin/com/hostingerpanel/app/MainActivity.kt  # file picker + downloads
│       └── res/                         # splash + status/nav bar themes
├── assets/
├── lib/
│   ├── main.dart
│   ├── screens/webview_screen.dart      # WebView, navigation, back, dialogs
│   ├── widgets/loading_widget.dart      # splash loader + progress bar
│   ├── widgets/error_widget.dart        # offline screen + Retry
│   └── services/webview_service.dart    # URL policy, native channel
├── test/widget_test.dart                # navigation-policy unit tests
├── pubspec.yaml
└── README.md
```

Dependencies: `webview_flutter`, `webview_flutter_android` (for file chooser, cookie and mixed-content settings), and `url_launcher`. Nothing else.

## Requirements

- Flutter stable (built with 3.47 / Dart 3.13)
- Android SDK and a JDK 17+ (Android Studio's bundled JDK works)
- Minimum Android version: 7.0 (API 24)

## Setup

```bash
flutter pub get
```

```bash
flutter doctor
```

**Android Studio:**

1. Install the **Flutter** and **Dart** plugins (Settings → Plugins).
2. Open this `webview/` folder (File → Open).
3. If prompted, set the Flutter SDK path (Settings → Languages & Frameworks → Flutter).
4. Start an emulator (Device Manager) or plug in a phone with USB debugging enabled.
5. Choose the device in the toolbar and press **Run**.

**VS Code:** install the Flutter extension, open the folder, then press F5.

## Run

```bash
flutter run
```

## Tests and analysis

```bash
flutter analyze
```

```bash
flutter test
```

## Build

### Debug APK

```bash
flutter build apk --debug
```

Output: `build/app/outputs/flutter-apk/app-debug.apk`

### Release signing (one-time)

Without a keystore, release builds are signed with the debug key. That is fine for local testing but can't be uploaded to Google Play.

1. Create a keystore:

   ```bash
   keytool -genkey -v -keystore ~/hostinger-panel-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

2. Create `android/key.properties`. Git already ignores this file, so it won't be committed.

   ```properties
   storePassword=<your store password>
   keyPassword=<your key password>
   keyAlias=upload
   storeFile=/absolute/path/to/hostinger-panel-upload.jks
   ```

### Release APK

```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

To build smaller APKs, one per CPU type:

```bash
flutter build apk --release --split-per-abi
```

### Android App Bundle (Google Play)

```bash
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`

## Customisation

- **Allowed domains:** `WebViewService.trustedDomains` in `lib/services/webview_service.dart`.
- **Start URL:** `WebViewService.homeUrl`.
- **Application ID:** `com.hostingerpanel.app`. Change `applicationId` in `android/app/build.gradle.kts` before publishing.
- **App icon:** this still uses the default Flutter icon. Replace the `android/app/src/main/res/mipmap-*/ic_launcher.png` files, for example with `flutter_launcher_icons`.

## Known limitations

- **Google / social sign-in:** Google blocks OAuth inside embedded WebViews. Those links open in the browser, so the in-app session won't pick them up. Use email and password (with MFA) in the app.
- **Third-party payment pages** (PayPal, etc.) open in the browser, because only Hostinger domains are allowed in-app. Add a provider's domain to `trustedDomains` if you want it handled in the app.
- **`blob:` / `data:` downloads** are generated inside the page and can't be passed to DownloadManager. The app shows a message for these.
- On Android 9 and below, downloads open in the browser, because saving to Downloads would need a storage permission.
- Uploads use the document picker. Taking a new photo with the camera isn't supported.
# webview-app
