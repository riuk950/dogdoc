# Integrations

<!--
Notes on third-party integrations (Firebase, analytics, push, payments,
etc.) and their project-specific configuration quirks.
-->

# Firebase (iOS / Android)

## Setup Summary

* **GoogleService-Info.plist** for iOS (in `ios/Runner/`)
* **GoogleService-Info.plist** for Android (in `android/app/`)
* **google-services.json** for Android (in `android/app/`)
* **Firebase CLI** for Web publishing

## Firebase Project Creation

1. Go to [Firebase Console](https://console.firebase.google.com/).
2. Create a new project.
3. Register iOS app:
   - Bundle ID: `com.drapplab.dogdoc`
   - Download `GoogleService-Info.plist`.
4. Register Android app:
   - Package Name: `com.drapplab.dogdoc`
   - SHA-1 fingerprint: run `keytool -genkey -v -keystore ~/.android/debug.keystore -alias androiddebugkey -keyalg RSA -keysize 2048 -validity 10000` (then use the SHA1 fingerprint it prints).
   - Download `google-services.json`.
5. Enable Firestore, Storage, Authentication (optional) services.
6. Enable **Google Analytics** (required for Firebase Dynamic Links).

## iOS Configuration

1. Add `GoogleService-Info.plist` to Xcode project:
   - Open Xcode → Runner project → "Add Files to Runner".
   - Ensure "Copy items if needed" is checked.
   - Ensure "Add to targets" → "Runner" is checked.
2. Update **Info.plist**:
   ```xml
   <key>CFBundleURLTypes</key>
   <array>
     <dict>
       <key>CFBundleTypeRole</key>
       <string>Editor</string>
       <key>CFBundleURLSchemes</key>
       <array>
         <!-- GoogleService-Info.plist contains this → com.drapplab.dogdoc -->
         <string>com.googleusercontent.apps.YOUR_REVERSED_CLIENT_ID</string>
       </array>
     </dict>
   </array>
   ```
   (Your actual reversed client ID will be in GoogleService-Info.plist).
3. Add Firebase pod dependencies:
   ```ruby
   # Podfile (in ios/ directory)
   target 'Runner' do
     use_frameworks!
     # Add your Flutter plugins here...

     # Firebase
     pod 'Firebase/Core'
     pod 'Firebase/Analytics'
     pod 'Firebase/Firestore'
     pod 'Firebase/Storage'
   end
   ```
   Then run `pod install`.

## Android Configuration

1. Copy `google-services.json` to `android/app/`:
   ```bash
   cp /path/to/google-services.json android/app/
   ```
2. Add Firebase SDK to `android/build.gradle`:
   ```gradle
   buildscript {
       repositories {
           // ...
           google()
           mavenCentral()
       }
       dependencies {
           // ...
           classpath 'com.google.gms:google-services:4.4.4'  // check for latest
       }
   }
   ```
3. Apply the plugin in `android/app/build.gradle`:
   ```gradle
   apply plugin: 'com.android.application'
   apply plugin: 'com.google.gms.google-services'
   ```

## iOS Dynamic Links (Migration Plan)

### Current: Firebase Short Dynamic Links

- ✅ Already working in production (from original setup)
- ⚠️ Deprecation risk: [Dynamic Links are deprecated](https://firebase.google.com/docs/dynamic-links/ios/create#update-your-setup), will be sunset in August 2025.
- ❌ Manual management (short links copied from Firebase console)

### New: Firebase Dynamic Links (Google-hosted)

- ✅ Google-hosted (no custom domain needed)
- ✅ Still supported after legacy deprecation
- ℹ️ Requires Firebase Console configuration per link

## Web Configuration

1. Add Firebase to web app:
   ```bash
   # This initializes a Firebase configuration object
   flutterfire configure --platforms=web --out=lib/firebase_options.dart
   ```
2. Enable hosting in Firebase Console:
   ```bash
   firebase init hosting
   # Select your web app, public directory = 'build/web',
   # configure as single-page app if desired.
   ```
3. Deploy:
   ```bash
   flutter build web
   firebase deploy
   ```

# Firebase Dynamic Links (Short Links)

## Firebase Console Setup

1. Go to Firebase Console → Dynamic Links.
2. Create a new short domain:
   - Select domain: `*.page.link` (e.g., `yourclinic.page.link`).
   - Custom suffix (optional): `dogdoc://` (if you want to override default behavior, but default should work).
3. Create short links:
   - Link name: e.g., `Referral - Diego`.
   - Destination URL: `https://yourdomain.com` or `app://home`.
   - Configure iOS/Android behavior:
     - iOS: `https://yourdomain.com`
     - Android: `https://yourdomain.com`
4. Copy the generated short link (e.g., `https://yourclinic.page.link/referral-diego`).
