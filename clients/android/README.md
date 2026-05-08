# BaumAgent — Android Client (Flutter)

Flutter application targeting Android 8.0+ (API 26+). The codebase is structured
so iOS is a future drop-in — platform channels are isolated behind an abstraction
layer and only Android-specific code lives in `android/`.

## Stack

| Concern | Technology |
|---------|-----------|
| UI | Flutter (Material 3, dark/light theme) |
| Generated API client | openapi-generator `dart-dio` (from `spec/openapi.yaml`) |
| Networking (REST) | `dio` (generated client), `http` for utilities |
| WebSocket | `web_socket_channel` |
| Push notifications | `firebase_messaging` (FCM) |
| Voice dictation | `speech_to_text` package (on-device STT) |
| Secure storage | `flutter_secure_storage` (EncryptedSharedPreferences on Android) |
| State management | `riverpod` |
| QR scanning | `mobile_scanner` |
| Local notifications | `flutter_local_notifications` |

## Project structure (planned)

```
clients/android/
├── pubspec.yaml
├── lib/
│   ├── main.dart
│   ├── app.dart                    # MaterialApp, theme, router
│   ├── core/
│   │   ├── api_client.dart         # Wraps generated Dio client + auth interceptor
│   │   ├── websocket_service.dart  # Frame parsing, reconnect with backoff
│   │   ├── secure_storage.dart     # flutter_secure_storage wrapper
│   │   ├── push_service.dart       # FCM init + POST /api/push/register
│   │   └── voice_service.dart      # speech_to_text wrapper
│   ├── pairing/
│   │   ├── pairing_screen.dart     # URL entry + QR scan + manual code
│   │   └── pairing_notifier.dart   # Riverpod AsyncNotifier
│   ├── tasks/
│   │   ├── task_list_screen.dart
│   │   ├── task_detail_screen.dart # Live log + progress bar
│   │   ├── task_create_screen.dart # Voice input + form
│   │   └── tasks_notifier.dart
│   ├── exports/
│   │   └── exports_screen.dart
│   ├── settings/
│   │   ├── settings_screen.dart
│   │   └── connected_devices_screen.dart
│   └── generated/                  # openapi-generator output (do not edit)
│       └── lib/
├── android/
│   ├── app/
│   │   └── google-services.json    # FCM config (gitignored — add manually)
│   └── ...
└── test/
    ├── pairing_flow_test.dart
    └── task_lifecycle_test.dart
```

## First-launch flow

1. App reads `flutter_secure_storage` for a stored token.
2. If absent → show `PairingScreen`: enter BaumAgent URL → `GET /api/health`.
3. Show QR scan prompt: `mobile_scanner` reads the `baumagent://pair?...` deep-link.
4. Or user enters code manually.
5. `POST /api/auth/pair/complete` → receive token → write to `SecureStorage`.
6. `GET /api/me` → populate identity.
7. Navigate to main task list.

## Push notifications (FCM)

- `FirebaseMessaging.instance.getToken()` on startup.
- `POST /api/push/register` with `platform: "fcm"` and the FCM token.
- `FirebaseMessaging.onMessageOpenedApp` handles foreground deep-links to `TaskDetailScreen`.
- `flutter_local_notifications` displays heads-up notifications when the app is foregrounded.
- `google-services.json` must be placed at `android/app/google-services.json` (not committed).

## Voice dictation

- `SpeechToText` from the `speech_to_text` package — uses Android on-device STT.
- Hold-to-talk FAB in `TaskCreateScreen`.
- Transcript updates live; user edits before submitting.
- Permission: `RECORD_AUDIO` requested at runtime.

## Setup

```bash
# Install dependencies
flutter pub get

# Run on connected device / emulator
flutter run

# Build release APK
flutter build apk --release
```

## iOS (future)

The Flutter codebase is iOS-compatible with these additions:
- Replace `google-services.json` with `GoogleService-Info.plist`.
- Change push platform from `"fcm"` to `"apns"` in `PushService`.
- Add `NSMicrophoneUsageDescription` to `Info.plist`.
- Submit APNs device token instead of FCM token.

## Codegen

```bash
cd ../../spec/codegen
./generate-dart.sh
```

Regenerate whenever `spec/openapi.yaml` changes. The `generated/` directory is
committed so contributors without Java/openapi-generator-cli can build immediately.
