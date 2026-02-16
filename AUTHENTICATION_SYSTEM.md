# AtaoQuiz Authentication System (Current State)

## Scope
This document describes the authentication system currently implemented in the codebase.
It focuses on behavior, security rules, Android configuration, and required permissions.

## Architecture

### Core service
- `lib/services/system_auth_service.dart`

Main responsibilities:
- detect available device auth methods
- enable/disable app-level auth
- authenticate with native Android prompt
- detect security configuration changes
- store and validate auth configuration state

### UI flow screens
- `lib/screens/authentication/first_time_setup_screen.dart`
- `lib/screens/authentication/system_auth_screen.dart`
- `lib/screens/authentication/system_auth_manage_screen.dart`
- `lib/screens/splash_screen.dart`

### App lifecycle lock guard
- `lib/main.dart`

## Supported methods
The app supports:
- Biometrics
- Device credential fallback (PIN, pattern, password)

Important limitation:
- The Android API used by `local_auth` does not expose the exact fallback type.
- For this reason, the app displays the generic label:
  - `Verrouillage appareil (PIN/Schéma/Mot de passe)`

## SharedPreferences keys
- `is_first_time_setup` (bool)
- `system_auth_enabled` (bool)
- `device_lock_types` (List<String>)
- `last_security_hash` (String)

## Runtime flow

### First app launch
1. `SplashScreen` checks `is_first_time_setup`.
2. If true, route to `/first-time-setup`.
3. User can enable auth or skip.
4. Setup flag is stored as completed after either action.

### Next launches
1. `SplashScreen` checks `system_auth_enabled`.
2. If enabled, route to `/system-auth`.
3. On success, route to `/home`.

### App resume lock
`main.dart` observes lifecycle events:
- On `inactive/paused/hidden`, it arms lock-on-resume.
- On `resumed`, it redirects to `/system-auth` when needed.

Excluded routes:
- `/`
- `/first-time-setup`
- `/system-auth`

## Security-change handling
On `/system-auth`, the app checks whether device security config changed.

If changed:
1. app auth state is disabled
2. user gets a clear warning
3. app is redirected to `/first-time-setup`

This avoids infinite lock loops and forces clean reconfiguration.

## Security management screen
`SystemAuthManageScreen` supports:
- show enabled/disabled status
- activate security
- disable security

Rules:
- activation requires existing Android lock
- disable action requires re-authentication
- displayed methods are refreshed from current device state
- visual style follows app theme colors

## Android configuration (required)

### 1) Permissions
File: `android/app/src/main/AndroidManifest.xml`
```xml
<uses-permission android:name="android.permission.USE_BIOMETRIC" />
<uses-permission android:name="android.permission.USE_FINGERPRINT" />
```

### 2) Activity type
File: `android/app/src/main/kotlin/com/example/atao_quiz/MainActivity.kt`
```kotlin
class MainActivity : FlutterFragmentActivity()
```

### 3) AppCompat themes for biometric prompt compatibility
Files:
- `android/app/src/main/res/values/styles.xml`
- `android/app/src/main/res/values-night/styles.xml`

Both `LaunchTheme` and `NormalTheme` use:
```xml
@style/Theme.AppCompat.DayNight.NoActionBar
```

### 4) Backup hardening
File: `android/app/src/main/AndroidManifest.xml`
```xml
android:allowBackup="false"
```

### 5) Gradle app module
File: `android/app/build.gradle.kts`
- `minSdk = flutter.minSdkVersion`
- `targetSdk = flutter.targetSdkVersion`
- Java/Kotlin target: 11

## local_auth options in use
File: `lib/services/system_auth_service.dart`
```dart
AuthenticationOptions(
  stickyAuth: true,
  sensitiveTransaction: true,
  biometricOnly: false,
)
```

## Migration and stability
The service includes migration from previous unstable `hashCode` comparison to a stable signature format for security config checks.

## Validation checklist
1. First launch with secure device
2. First launch with no device lock
3. Enable from setup screen
4. Enable from security management screen after skip
5. Disable with re-authentication
6. Re-enable after disable
7. Launch auth flow
8. Resume lock flow
9. Security change detection after Android lock change
10. Responsive behavior on small/large screens

## Last update
- February 16, 2026
