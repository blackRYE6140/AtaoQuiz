# AtaoQuiz Authentication System (Current Implementation)

## 1. Goal
AtaoQuiz uses native Android device security for app access control.
The app does not manage an internal PIN. It relies on the lock method already configured on the device.

## 2. Main Components

### Authentication service
- `lib/services/system_auth_service.dart`

Responsibilities:
- discover available lock methods
- enable/disable app authentication
- execute runtime authentication
- run Android-native device credential fallback
- detect Android security config changes

### UI flow screens
- `lib/screens/authentication/first_time_setup_screen.dart`
- `lib/screens/authentication/system_auth_screen.dart`
- `lib/screens/authentication/system_auth_manage_screen.dart`
- `lib/screens/splash_screen.dart`

### Lifecycle lock guard
- `lib/main.dart`

### Android native integration
- `android/app/src/main/kotlin/com/example/atao_quiz/MainActivity.kt`
- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/main/res/values/styles.xml`
- `android/app/src/main/res/values-night/styles.xml`
- `android/app/build.gradle.kts`

## 3. Supported Methods and Labels
Detected lock types:
- biometrics
- device credential fallback

Displayed fallback label:
- `Verrouillage appareil (PIN/Schéma/Mot de passe)`

Why generic:
- `local_auth` does not provide a reliable PIN vs pattern vs password distinction.
- biometric listing is often reported as `BiometricType.weak` / `BiometricType.strong`, not always explicit face/fingerprint labels.

## 4. Runtime Flow

### First launch
1. `SplashScreen` checks `is_first_time_setup`.
2. If `true`, route to `/first-time-setup`.
3. User can enable security or skip.
4. Setup is marked complete in both cases.

### Later launches
1. `SplashScreen` checks `system_auth_enabled`.
2. If enabled, route to `/system-auth`.
3. On success, route to `/home`.

### Resume lock flow
`main.dart` arms lock on `inactive/paused/hidden` and enforces `/system-auth` on `resumed` when needed.

Excluded routes:
- `/`
- `/first-time-setup`
- `/system-auth`

### Security change flow
`SystemAuthScreen` checks `hasSecurityConfigChanged()`.
If changed:
1. disable app auth state
2. show warning
3. force route to `/first-time-setup`

## 5. Authentication Engine Details

### local_auth options (current)
`authenticateWithSystem()` uses:
```dart
AuthenticationOptions(
  stickyAuth: false,
  sensitiveTransaction: true,
  biometricOnly: false,
)
```

Notes:
- `stickyAuth: false` avoids OEM loop issues in biometric -> credential transitions.
- `biometricOnly: false` allows PIN/pattern/password fallback.

### Fallback strategy
If `local_auth.authenticate(...)` returns `false` or throws `PlatformException`:
1. call `stopAuthentication()`
2. call native fallback via `MethodChannel('atao_quiz/device_credential')`

Native methods implemented in `MainActivity.kt`:
- `isDeviceCredentialAvailable`
- `authenticateWithDeviceCredential`

Native behavior:
- checks `KeyguardManager.isDeviceSecure`
- starts `createConfirmDeviceCredentialIntent(...)`
- returns result to Flutter in `onActivityResult` (request code `4242`)

This resolves the case where biometric is enrolled but user chooses password/pattern/PIN.

### Activation behavior
`enableSystemAuth({ requireCurrentUserVerification = false })` defaults to no immediate user verification to avoid activation failures on some OEM devices.

### Biometrics listing hardening
`getAvailableLockTypes()` catches exceptions from `getAvailableBiometrics()` so credential fallback still remains available.

### Error diagnostics
The service tracks:
- `lastAuthErrorCode`
- `lastAuthErrorMessage`

`SystemAuthScreen` logs those values for troubleshooting.

## 6. SharedPreferences Keys
- `is_first_time_setup` (bool)
- `system_auth_enabled` (bool)
- `device_lock_types` (List<String>)
- `last_security_hash` (String)

## 7. Android Configuration (Required)

### Permissions
In `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.USE_BIOMETRIC" />
<uses-permission android:name="android.permission.USE_FINGERPRINT" />
```

### Backup hardening
In `android/app/src/main/AndroidManifest.xml`:
```xml
android:allowBackup="false"
```

### Activity type
In `android/app/src/main/kotlin/com/example/atao_quiz/MainActivity.kt`:
```kotlin
class MainActivity : FlutterFragmentActivity()
```

### Theme compatibility
In both `styles.xml` files, `LaunchTheme` and `NormalTheme` inherit from:
```xml
@style/Theme.AppCompat.DayNight.NoActionBar
```

### Gradle/JVM
In `android/app/build.gradle.kts`:
- Java compatibility 11
- Kotlin `jvmTarget = 11`
- `minSdk = flutter.minSdkVersion`
- `targetSdk = flutter.targetSdkVersion`

## 8. Known Limitations
- Exact credential type (PIN vs pattern vs password) is not exposed by `local_auth`.
- Face unlock may not appear as an explicit selectable type even when available.

## 9. Recommended Validation Checklist
1. Enable auth during first-time setup
2. Enable auth later from security management after skip
3. Disable auth with re-authentication
4. Re-enable auth after disable
5. Success with biometric
6. Success with password/pattern/PIN when biometrics are also configured
7. Resume lock behavior from background
8. Security change detection after Android lock modification
9. Device without biometrics
10. Device with biometrics + device credential

## 10. Last Update
- February 16, 2026
