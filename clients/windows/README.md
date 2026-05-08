# BaumAgent — Windows Client

Native WinUI 3 application (Windows App SDK 1.5+) for Windows 11.

## Stack

| Concern | Technology |
|---------|-----------|
| UI | WinUI 3 (XAML) |
| System tray | `TrayIcon` (CommunityToolkit.WinUI) |
| Networking | `HttpClient` (REST) + `ClientWebSocket` (WS) |
| Generated API client | Kiota (from `spec/openapi.yaml`) |
| Push notifications | `Microsoft.Windows.AppNotifications` (Windows App SDK) |
| Voice dictation | `Windows.Media.SpeechRecognition.SpeechRecognizer` |
| Secure storage | `Windows.Security.Credentials.PasswordVault` |
| Dark/light mode | `UISettings.GetColorValue(UIColorType.Background)` |

## Why WinUI 3 over WPF

- Native Fluent design (Acrylic, Mica, rounded corners) on Windows 11
- `Windows.Media.SpeechRecognition` works without interop hacks in a packaged app
- `Microsoft.Windows.AppNotifications` for toast notifications with deep-links
- System tray support via CommunityToolkit (no Win32 P/Invoke needed)
- Active development; WPF is in maintenance mode

## Project structure (planned)

```
clients/windows/
├── BaumAgentClient.sln
├── BaumAgentClient/
│   ├── BaumAgentClient.csproj      # net8.0-windows10.0.22621.0; Windows App SDK 1.5
│   ├── App.xaml / App.xaml.cs      # App entry, tray icon setup, notification registration
│   ├── Pairing/
│   │   ├── PairingPage.xaml        # URL entry + QR scanner (ZXing.Net) + manual code
│   │   └── PairingViewModel.cs
│   ├── Tasks/
│   │   ├── TaskListPage.xaml
│   │   ├── TaskDetailPage.xaml     # Live log stream + progress bar
│   │   ├── TaskCreatePage.xaml     # Voice input + form
│   │   └── TaskViewModel.cs
│   ├── Exports/
│   │   └── ExportsPage.xaml
│   ├── Settings/
│   │   ├── SettingsPage.xaml
│   │   └── ConnectedDevicesPage.xaml
│   ├── Services/
│   │   ├── BaumAgentApiClient.cs   # Wraps Kiota client + auth handler
│   │   ├── WebSocketService.cs     # JSON frame parsing, reconnect with backoff
│   │   ├── CredentialService.cs    # PasswordVault wrapper
│   │   ├── PushService.cs          # WNS channel + POST /api/push/register
│   │   └── VoiceService.cs         # SpeechRecognizer wrapper
│   └── Generated/                  # Kiota output (do not edit)
└── BaumAgentClient.Tests/
    ├── PairingFlowTests.cs
    └── TaskLifecycleTests.cs
```

## First-launch flow

1. App checks `PasswordVault` for a stored token.
2. If absent → show `PairingPage`: enter BaumAgent URL → `GET /api/health`.
3. Show QR prompt: user pairs from web UI.
4. Scan QR with ZXing.Net.Maui webcam control, or paste code.
5. `POST /api/auth/pair/complete` → receive token → store in `PasswordVault`.
6. `GET /api/me` → populate identity.
7. Show main window.

## Push notifications (WNS)

- Register `Microsoft.Windows.AppNotifications.AppNotificationManager` on startup.
- Obtain channel URI via `PushNotificationChannel.CreatePushNotificationChannelForApplicationAsync()`.
- `POST /api/push/register` with `platform: "wns"` and the channel URI as `token`.
- Toast on task completion activates the app and navigates to `TaskDetailPage` via activation args.

## Voice dictation

- `Windows.Media.SpeechRecognition.SpeechRecognizer` for OS-native STT.
- Tap-to-talk button in `TaskCreatePage`.
- `SpeechRecognitionSession` with continuous recognition; results update transcript live.
- Edit transcript before submitting.

## Build

```powershell
cd clients/windows
dotnet build BaumAgentClient.sln -c Release
```

To package for distribution:
```powershell
dotnet publish -c Release -f net8.0-windows10.0.22621.0 --self-contained true
```

## Codegen

```bash
cd ../../spec/codegen
./generate-csharp.sh
```

Regenerate whenever `spec/openapi.yaml` changes.
