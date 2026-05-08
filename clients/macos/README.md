# BaumAgent — macOS Client

Native Swift / SwiftUI application for macOS 14+.

## Stack

| Concern | Technology |
|---------|-----------|
| UI | SwiftUI |
| Menu bar | `NSStatusItem` + `NSMenu` |
| Networking | `URLSession` (REST) + `URLSessionWebSocketTask` (WS) |
| Generated API client | swift-openapi-generator (from `spec/openapi.yaml`) |
| Push notifications | `UNUserNotificationCenter` + APNs |
| Voice dictation | `Speech` framework (`SFSpeechRecognizer`) |
| Secure storage | Keychain via `Security` framework |
| Dark/light mode | SwiftUI `.preferredColorScheme` from system |

## Project structure (planned)

```
clients/macos/
├── BaumAgent.xcodeproj
├── Sources/
│   ├── App/
│   │   ├── BaumAgentApp.swift        # @main, AppDelegate, menu bar setup
│   │   └── AppState.swift            # ObservableObject holding connection + tasks
│   ├── Pairing/
│   │   ├── PairingView.swift         # URL entry + QR scanner + manual code entry
│   │   └── PairingViewModel.swift
│   ├── Tasks/
│   │   ├── TaskListView.swift
│   │   ├── TaskDetailView.swift      # Live log stream via URLSessionWebSocketTask
│   │   ├── TaskCreateView.swift      # Voice input + form
│   │   └── TaskViewModel.swift
│   ├── Exports/
│   │   └── ExportsView.swift
│   ├── Settings/
│   │   ├── SettingsView.swift
│   │   └── ConnectedDevicesView.swift  # Token revocation
│   ├── Services/
│   │   ├── BaumAgentClient.swift     # Wraps generated OpenAPI client + auth header
│   │   ├── WebSocketService.swift    # JSON frame parsing, reconnect with backoff
│   │   ├── KeychainService.swift     # Token store/retrieve/delete
│   │   ├── PushService.swift         # APNs registration + POST /api/push/register
│   │   └── VoiceService.swift        # SFSpeechRecognizer wrapper
│   └── Generated/                    # swift-openapi-generator output (do not edit)
└── Tests/
    ├── PairingFlowTests.swift
    └── TaskLifecycleTests.swift
```

## First-launch flow

1. `BaumAgentApp` checks Keychain for a stored token.
2. If absent → show `PairingView`: enter BaumAgent URL → hit "Connect" → `GET /api/health`.
3. Show QR scan prompt: user goes to BaumAgent web UI → Settings → Pair New Device.
4. Scan QR with `AVFoundation` or paste code manually.
5. `POST /api/auth/pair/complete` → receive token → store in Keychain.
6. `GET /api/me` → populate `AppState.currentUser`.
7. Show main UI.

## Push notifications

- Request `UNUserNotificationCenter` authorization on first launch (after pairing).
- Register for APNs: `UIApplication.registerForRemoteNotifications()`.
- Receive token in `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)`.
- `POST /api/push/register` with `platform: "apns"`.
- Notification deep-links open `TaskDetailView` for the relevant `task_id` via URL scheme `baumagent://tasks/<id>`.

## Voice dictation

- `SFSpeechRecognizer` + `AVAudioEngine` for on-device STT.
- Tap-to-talk button in `TaskCreateView`: hold to record, release to transcribe.
- Transcript shown live via `SFSpeechRecognitionRequest.requiresOnDeviceRecognition = true`.
- Edit transcript before submitting.

## Build

```bash
xcodebuild \
  -project BaumAgent.xcodeproj \
  -scheme BaumAgent \
  -destination 'platform=macOS' \
  build
```

## Codegen

```bash
cd ../../spec/codegen
./generate-swift.sh
```

Regenerate whenever `spec/openapi.yaml` changes.
