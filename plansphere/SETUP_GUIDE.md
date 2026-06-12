# 🚀 PlanSphere – Complete Setup Guide for Antigravity (FlutterFlow / Play Store)

---

## 📦 What's Inside This ZIP

```
plansphere/
├── lib/                   ← All Flutter/Dart source code (81 files)
│   ├── main.dart
│   ├── firebase_options.dart  ← REPLACE with your config
│   ├── core/              ← Constants, theme, navigation, widgets
│   ├── data/              ← Models, Firebase services
│   └── presentation/      ← Screens, providers
├── android/               ← Android platform config
├── ios/                   ← iOS platform config  
├── assets/                ← Images, fonts, animations (add yours)
├── pubspec.yaml           ← All dependencies
├── firestore.rules        ← Security rules (deploy to Firebase)
├── storage.rules          ← Storage rules
├── firestore.indexes.json ← DB indexes
└── README.md              ← Detailed documentation
```

---

## ⚡ STEP 1 – Prerequisites

Install these tools first:

```bash
# 1. Flutter SDK (3.x)
# Download: https://flutter.dev/docs/get-started/install

# 2. Verify Flutter installation
flutter doctor

# 3. Firebase CLI
npm install -g firebase-tools

# 4. FlutterFire CLI
dart pub global activate flutterfire_cli
```

---

## 🔥 STEP 2 – Firebase Setup (REQUIRED)

### 2a. Create Firebase Project
1. Visit https://console.firebase.google.com
2. Click **"Add project"** → Name: `plansphere`
3. Enable Google Analytics → Continue

### 2b. Enable Authentication
- Firebase Console → Authentication → Sign-in method
- Enable: **Email/Password** ✅
- Enable: **Google** ✅

### 2c. Enable Firestore
- Firebase Console → Firestore Database
- Click **"Create database"**
- Choose **Production mode** → Select region → Done

### 2d. Enable Storage
- Firebase Console → Storage → Get started
- Choose **Production mode** → Done

### 2e. Enable Cloud Messaging (FCM)
- Automatically enabled with Firebase project

### 2f. Add Android App
1. Firebase Console → Project Settings → Add app → Android
2. Package name: `com.plansphere.app`
3. Download `google-services.json`
4. **Copy to:** `android/app/google-services.json`

### 2g. Add iOS App
1. Firebase Console → Project Settings → Add app → iOS
2. Bundle ID: `com.plansphere.app`
3. Download `GoogleService-Info.plist`
4. **Copy to:** `ios/Runner/GoogleService-Info.plist`

### 2h. Generate firebase_options.dart
```bash
cd plansphere
firebase login
flutterfire configure --project=YOUR_PROJECT_ID
# This auto-generates lib/firebase_options.dart
```

### 2i. Deploy Firebase Rules
```bash
firebase deploy --only firestore:rules
firebase deploy --only firestore:indexes
firebase deploy --only storage
```

---

## 📱 STEP 3 – Run the App

```bash
# Navigate to project
cd plansphere

# Install Flutter dependencies
flutter pub get

# Check connected devices
flutter devices

# Run on Android
flutter run -d android

# Run on iOS (Mac only)
flutter run -d ios

# Run in release mode
flutter run --release
```

---

## 🏗️ STEP 4 – Build for Production

### Android (Google Play Store)

**Step 4a – Create Signing Keystore:**
```bash
keytool -genkey -v \
  -keystore android/plansphere-release.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias plansphere \
  -dname "CN=PlanSphere, OU=Mobile, O=PlanSphere Inc, L=Mumbai, ST=Maharashtra, C=IN"
```

**Step 4b – Create `android/key.properties`:**
```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=plansphere
storeFile=../plansphere-release.jks
```

**Step 4c – Add signing config to `android/app/build.gradle`:**
```groovy
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
}
```

**Step 4d – Build App Bundle:**
```bash
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

**Step 4e – Upload to Play Console:**
1. Go to https://play.google.com/console
2. Create app → Upload AAB
3. Fill store listing → Submit for review

---

### iOS (Apple App Store)

**Step 4a – Open in Xcode:**
```bash
open ios/Runner.xcworkspace
```

**Step 4b – Configure in Xcode:**
- Select Runner target → Signing & Capabilities
- Set Team (Apple Developer account required)
- Bundle Identifier: `com.plansphere.app`

**Step 4c – Build:**
```bash
flutter build ios --release
```

**Step 4d – Archive & Upload:**
- Xcode → Product → Archive
- Click **"Distribute App"** → App Store Connect
- Upload to https://appstoreconnect.apple.com

---

## 🔧 STEP 5 – Add Fonts (Optional but Recommended)

Download Outfit font from Google Fonts:
https://fonts.google.com/specimen/Outfit

Place TTF files in `assets/fonts/`:
- `Outfit-Regular.ttf`
- `Outfit-Medium.ttf`
- `Outfit-SemiBold.ttf`
- `Outfit-Bold.ttf`

*(Already declared in pubspec.yaml)*

---

## 🎨 STEP 6 – Add App Icons

Use `flutter_launcher_icons` package or Android Studio:

```bash
# Add to pubspec.yaml dev_dependencies:
# flutter_launcher_icons: ^0.13.1

# Then:
flutter pub run flutter_launcher_icons
```

Place your icon as `assets/images/icon.png` (1024×1024 PNG, no transparency)

---

## 🔔 STEP 7 – Push Notifications (FCM)

### Android
- Works automatically with `google-services.json`

### iOS  
1. Xcode → Runner → Signing & Capabilities → Add capability
2. Add: **Push Notifications** + **Background Modes**
3. Enable: Remote notifications, Background fetch

### Upload APN Key to Firebase
1. Apple Developer → Keys → Create key → Apple Push Notifications service
2. Firebase Console → Project Settings → Cloud Messaging
3. Upload the `.p8` key file

---

## ✅ STEP 8 – Checklist Before Publishing

- [ ] `google-services.json` placed in `android/app/`
- [ ] `GoogleService-Info.plist` placed in `ios/Runner/`
- [ ] `lib/firebase_options.dart` generated by FlutterFire CLI
- [ ] Firestore rules deployed
- [ ] Storage rules deployed
- [ ] App signing configured (Android keystore)
- [ ] App icons added
- [ ] Splash screen customized
- [ ] App name correct in `pubspec.yaml` (plansphere)
- [ ] Bundle ID correct (`com.plansphere.app`)
- [ ] Privacy policy URL added
- [ ] Terms of service URL added
- [ ] Push notifications working
- [ ] Biometric tested on real device
- [ ] OCR scanner tested with real receipts

---

## 🆘 Common Issues & Fixes

| Issue | Solution |
|-------|----------|
| `MissingPluginException` | Run `flutter clean && flutter pub get` |
| `google-services.json` error | Ensure it's in `android/app/` not `android/` |
| Biometric not working | Use `FlutterFragmentActivity` in MainActivity (already done) |
| OCR slow on first run | ML Kit downloads model on first use, needs internet |
| Build failed: `coreLibraryDesugaringEnabled` | Already configured in build.gradle |
| iOS build failed: pods | Run `cd ios && pod install && cd ..` |
| `PERMISSION_DENIED` Firestore | Deploy `firestore.rules` to Firebase |
| Google Sign-In fails Android | Add SHA-1 fingerprint to Firebase Console |
| Google Sign-In fails iOS | Add `REVERSED_CLIENT_ID` to iOS URL schemes |

---

## 📞 Support

- Documentation: README.md
- Firebase Help: https://firebase.google.com/support
- Flutter Help: https://flutter.dev/community

---

**PlanSphere v1.0.0** – Built with Flutter & Firebase 🚀
