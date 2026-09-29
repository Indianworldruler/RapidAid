# rapidaid

RapidAid is a Flutter-based emergency assistance application that helps users quickly contact trusted people during an emergency.

## APK

The Android APK is provided with this project for users who want to install RapidAid without setting up Flutter.

### How to Use

1. Install the RapidAid APK on an Android device.
2. Open the application.
3. Create an account or log in.
4. Add a priority emergency number from Settings.
5. Add trusted emergency contacts.
6. Open the SOS section when emergency assistance is required.
7. Optionally describe the situation.
8. Tap the SOS button.
9. RapidAid starts the priority emergency call and the SMS process.
10. The same emergency SMS is sent to the priority number and all saved emergency contacts with the current location.

## Features

* User registration and login using Firebase Authentication.
* Add and manage trusted emergency contacts.
* Priority emergency number.
* Direct phone calling for the priority emergency number.
* Direct SMS sending to the priority number.
* Direct SMS sending to all saved emergency contacts.
* Same emergency message sent to every saved number.
* Current device location included as a Google Maps link in the emergency SMS.
* Automatic SOS message generation.
* Large and high-visibility SOS button.
* SOS alert recording.
* Firebase Realtime Database synchronisation.
* Local SQLite storage for offline access.
* Failed/pending SOS retry support.
* SOS history.
* Material 3 responsive interface.
* Offline availability of important emergency information.
* Runtime SMS permission handling on Android.
* Phone number formatting and validation.
* Call and SMS status tracking for SOS alerts.

## SOS Flow

```text
Login / Sign Up
      ↓
Emergency Contacts
      ↓
Configure Priority Number
      ↓
SOS
      ↓
Priority Emergency Call Starts
      ↓
Current Location Retrieved
      ↓
Emergency SMS Sent
      ↓
Priority Number + Saved Emergency Contacts
      ↓
SOS Record Saved
      ↓
Firebase Realtime Database
````

The priority call and SMS process are started without waiting for the phone call to finish, allowing the SMS process to run while the emergency call is active when supported by the device and mobile network.

## Emergency SMS

The emergency SMS contains:

```text
RAPIDAID EMERGENCY ALERT

I need emergency assistance.

Situation:
[User's situation]

Time:
[Date and time]

Current location:
[Google Maps location link]

Please contact me as soon as possible.
```

The message is automatically prepared using the user's current situation, alert time and current device location.

RapidAid sends the same emergency message to:

* Priority emergency number
* All saved emergency contacts

The application does not use WhatsApp for emergency messaging.

## Technologies Used

* Flutter
* Dart
* Firebase Authentication
* Firebase Realtime Database
* SQLite
* Material 3
* `url_launcher`
* `flutter_phone_direct_caller`
* `send_message`
* `permission_handler`
* `geolocator`
* `sqflite`
* `connectivity_plus`
* `path_provider`

> Firebase Firestore is not used in this project.

## Running RapidAid from GitHub

### Requirements

Install:

* Git
* Flutter SDK
* Android Studio
* Android SDK
* Android Emulator or Android device
* Firebase CLI
* FlutterFire CLI

Check Flutter:

```bash
flutter --version
flutter doctor
```

## Clone the Repository

```bash
git clone YOUR_GITHUB_REPOSITORY_URL
cd rapidaid
```

Replace `YOUR_GITHUB_REPOSITORY_URL` with the GitHub repository URL.

## Install Dependencies

Run:

```bash
flutter pub get
```

All packages listed in `pubspec.yaml` will be installed automatically.

## Firebase CLI

Install Firebase CLI:

```bash
npm install -g firebase-tools
```

Check:

```bash
firebase --version
```

Login:

```bash
firebase login
```

## FlutterFire CLI

Install:

```bash
dart pub global activate flutterfire_cli
```

Check:

```bash
flutterfire --version
```

If `flutterfire` is not recognised on macOS:

```bash
echo 'export PATH="$PATH:$HOME/.pub-cache/bin"' >> ~/.zshrc
source ~/.zshrc
```

## Firebase Configuration

RapidAid uses:

* Firebase Authentication
* Firebase Realtime Database

The project already contains:

```text
lib/firebase_options.dart
```

If Firebase needs to be configured again:

```bash
flutterfire configure
```

## Run the Application

Check available devices:

```bash
flutter devices
```

Run the application:

```bash
flutter run
```

Or run on a specific Android emulator:

```bash
flutter run -d emulator-5554
```

Replace the device ID with the one shown by `flutter devices`.

## Build Release APK

To generate the Android release APK:

```bash
flutter build apk --release
```

The generated APK will be available at:

```text
build/app/outputs/flutter-apk/app-release.apk
```

To generate separate APKs for different Android CPU architectures:

```bash
flutter build apk --split-per-abi
```

## Pull Latest Changes

For an existing cloned repository:

```bash
git pull
flutter pub get
flutter run
```

If you experience build issues:

```bash
flutter clean
flutter pub get
flutter run
```

## Useful Commands

```bash
flutter pub get
flutter run
flutter analyze
flutter devices
flutter clean
flutter pub upgrade
flutter build apk --release
git pull
git status
```

## Project Structure

```text
rapidaid/
├── android/
├── ios/
├── lib/
│   ├── main.dart
│   ├── app_theme.dart
│   ├── app_navigation.dart
│   ├── models.dart
│   ├── firebase_config.dart
│   ├── firebase_options.dart
│   ├── firebase_service.dart
│   ├── auth_service.dart
│   ├── storage_service.dart
│   ├── sos_service.dart
│   ├── communication_service.dart
│   ├── location_service.dart
│   ├── splash_screen.dart
│   ├── login_screen.dart
│   ├── signup_screen.dart
│   ├── emergency_contacts_screen.dart
│   ├── sos_alert_screen.dart
│   ├── alert_result_screen.dart
│   ├── settings_screen.dart
│   ├── profile_screen.dart
│   └── logout_screen.dart
├── pubspec.yaml
└── README.md
```

## Important Notes

* RapidAid is primarily intended for Android.
* Phone calling and direct SMS features should be tested on a physical Android device.
* Direct SMS requires the appropriate Android SMS permission.
* The emergency SMS is sent automatically by the application when supported by the device and mobile network.
* The same emergency SMS is sent to the priority number and all saved emergency contacts.
* The emergency SMS contains the current device location as a Google Maps link when location access is available.
* The priority emergency call and SMS process are started independently, so SMS sending does not intentionally wait for the call to finish.
* Actual SMS delivery depends on the device, SIM card, mobile network and Android permissions.
* Direct calling depends on device support and permissions.
* Firebase Authentication and Realtime Database are required for the cloud features.
* Local SQLite storage allows important SOS information to remain available offline.
* Failed or pending SOS alerts can be retried.
* The APK can be used directly without installing the Flutter development environment.
* WhatsApp is not used for emergency communication.




