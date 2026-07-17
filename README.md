# BaumAgent Client Suite

> **⚠️ Archived — moved to [BaumAI](https://github.com/Bruiserbaum/BaumAI)** as `clients/{macos,windows,android,spec}/`. Full commit history was merged in, this repo is now read-only. Releases now happen from BaumAI, tagged per-component (`android-v*`, `macos-v*`, `windows-v*`). Everything below describes the state before that merge.

Native clients for [BaumAgent](https://github.com/Bruiserbaum/BaumAgent) — a self-hosted AI task manager running on a homelab Kubernetes cluster.

```
┌─────────────────────────────────────────────────────┐
│                  BaumAgent (server)                 │
│   FastAPI · Redis/RQ · SQLite · Docker on k8s       │
│                                                     │
│  REST API  ──────────────────────────────────────┐  │
│  WebSocket (task log streaming)                  │  │
│  Push dispatch (APNs / FCM / WNS)               │  │
└──────────────────────────────────────────────────┼──┘
                                                   │
            ┌──────────────────────────────────────┼──────────────────┐
            │                                      │                  │
   ┌────────┼────────────────────────────────┐     │                  │
   │        │                                │     │                  │
   ▼        ▼                                ▼     ▼                  ▼
macOS     Windows                         Android  Linux            (VS Code
SwiftUI   WinUI 3                         Flutter  Flutter          extension —
(APNs)    (WNS toast)                     (FCM)    desktop          lives in the
                                                    (same lib/,      BaumAI repo,
                                                    no push)         not here)
```

Android and Linux are the same Flutter project (`clients/android/baumagent/`) with two native runners — see that directory's own README for what's Linux-specific.

Clients are **thin remotes** — all task execution happens on the BaumAgent server. The clients handle: first-launch pairing, task creation (with voice dictation), live log streaming, push notifications, and export downloads.

---

## Repository layout

```
baumagent-clients/
├── spec/
│   ├── openapi.yaml              # OpenAPI 3.1 — REST contract (source of truth)
│   ├── asyncapi.yaml             # AsyncAPI 2.6 — WebSocket frame schema
│   └── codegen/
│       ├── generate-swift.sh     # swift-openapi-generator
│       ├── generate-csharp.sh    # Kiota
│       └── generate-dart.sh      # openapi-generator dart-dio
├── clients/
│   ├── macos/                    # Swift / SwiftUI
│   ├── windows/                  # WinUI 3 (Windows App SDK)
│   └── android/                  # Flutter (Dart) — also builds Linux desktop (clients/android/baumagent/linux/)
└── .github/workflows/
    └── validate-spec.yml         # Spectral lint + AsyncAPI validate + Kiota dry-run
```

---

## Architecture decisions

| Concern | Decision | Rationale |
|---------|----------|-----------|
| Transport | REST + WebSocket | REST for commands, WS for live streaming |
| Auth | QR pairing → Bearer token | No SSO dependency on clients; revocable from web UI |
| Token storage | Platform-native secure storage | Keychain (Mac), Credential Manager (Win), EncryptedSharedPreferences (Android) |
| Voice input | OS-native STT (v1), on-device/server-side (v2) | Simplest path first; architecture allows switching |
| Push | APNs (Mac), WNS (Windows), FCM (Android) | Native platform channels, dispatched from server worker |
| WebSocket protocol | Structured JSON frames `{type, data}` | Typed enough for clients, no need for a binary protocol |
| Shared queue | `TEAM_MODE=true` env var on server | Single flag, no schema migration needed |
| Windows UI toolkit | WinUI 3 (Windows App SDK 1.5+) | Stable, Fluent design, native WNS and speech APIs |
| Android toolkit | Flutter | Single codebase for future iOS, strong platform channel story |
| Linux toolkit | Flutter desktop, same project as Android | Reuses ~95% of the Android `lib/` — pairing, tasks, chat, WebSocket streaming — instead of a separate GTK/Qt app. No push notifications (no Linux desktop push channel) or voice dictation (`speech_to_text` has no Linux backend); QR camera scan falls back to manual code entry. |
| Pause/resume | Deferred to v2 | RQ does not support cooperative pause without agent-side changes |

---

## First-launch pairing flow

```
Native client                        BaumAgent web UI (browser)
─────────────────────────────────────────────────────────────────
1. Enter BaumAgent URL
2. GET /api/health  ──────────────>  (validates URL)
3. Show "Pair Device" screen
                                     4. User navigates to
                                        Settings → Pair New Device
                                     5. POST /api/auth/pair/initiate
                                     6. Render QR from pair_url
7. Scan QR (or paste code)
8. POST /api/auth/pair/complete ──>
                                  <── 9. {token, user_id, user_email, …}
10. Store token in secure storage
11. GET /api/me  ─────────────────>  (confirm identity)
12. Main UI
```

Tokens are revocable from the web UI: Settings → Connected Devices → Revoke.

---

## WebSocket frame reference

Connect to: `wss://<host>/ws/tasks/<taskId>/logs?token=bat_<token>`

| Frame type | `data` type | Description |
|------------|-------------|-------------|
| `log` | `string` | Incremental log text — concatenate to reconstruct full log |
| `status` | `TaskStatus` | Task status changed |
| `progress` | `integer 0–100` | Agent-reported completion percentage |
| `done` | `DonePayload` | Terminal frame — close the WebSocket |
| `error` | `string` | Task not found / server error |

Reconnect with backoff if disconnected before a `done` frame. On reconnect the server replays from the beginning of the log.

---

## Spec development workflow

When you change the API (add an endpoint, change a field):

1. Update `spec/openapi.yaml` and/or `spec/asyncapi.yaml`.
2. Run the relevant codegen script to regenerate client stubs.
3. Compile the affected client — codegen errors surface immediately.
4. PR against `main` — CI validates the spec automatically.

---

## Dev setup

### macOS client

Requirements: Xcode 16+, macOS 14+

```bash
cd clients/macos
open BaumAgent.xcodeproj
# or: xcodebuild -scheme BaumAgent -destination 'platform=macOS'
```

Set the `BAUMAGENT_URL` environment variable in the scheme, or enter it on first launch.

### Windows client

Requirements: Visual Studio 2022 17.8+, Windows App SDK 1.5+, .NET 8

```powershell
cd clients/windows
dotnet build BaumAgentClient.sln
```

### Android client (Flutter)

Requirements: Flutter 3.19+, Android Studio / VS Code with Flutter extension

```bash
cd clients/android
flutter pub get
flutter run
```

---

## Server deployment checklist

Apply the `client-api` branch changes to your BaumAgent instance before pairing clients:

1. Pull the `client-api` branch (or merge to `main`):
   ```bash
   git checkout client-api
   docker compose up -d --build
   ```
2. Add push credentials to `.env` (see `.env.example` — all optional; push simply won't fire if absent).
3. Set `TEAM_MODE=true` if you want all paired devices to see the shared queue.
4. The database migrations run automatically on startup — no manual steps needed.
5. Verify the new endpoints:
   ```bash
   curl https://baumagent.baumwire.com/api/health
   curl -H "Authorization: Bearer bat_test" https://baumagent.baumwire.com/api/auth/tokens
   # should return 401 (invalid token), confirming auth middleware is active
   ```

---

## v1 feature matrix

| Feature | macOS | Windows | Android |
|---------|-------|---------|---------|
| First-launch pairing (QR + manual) | ✓ | ✓ | ✓ |
| Live task log streaming | ✓ | ✓ | ✓ |
| Push notifications on completion | APNs | WNS | FCM |
| Browse + download exports | ✓ | ✓ | ✓ |
| Cancel running tasks | ✓ | ✓ | ✓ |
| Task history + re-run | ✓ | ✓ | ✓ |
| Shared queue view (team mode) | ✓ | ✓ | ✓ |
| Voice dictation (OS-native) | Speech framework | WinSpeech API | speech_to_text |
| Dark/light mode | System | System | System |
| Re-pair / switch instance | Settings | Settings | Settings |

## Non-goals (v1)

- iOS app (Flutter codebase; small effort to add later)
- Web client (BaumAgent has its own React UI)
- Offline task queueing
- End-to-end encryption beyond TLS
- Pause/resume (v2 — requires cooperative agent changes)
- Server-side STT (v2 — requires Whisper endpoint)
