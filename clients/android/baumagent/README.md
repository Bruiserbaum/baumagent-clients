# baumagent (Flutter client — Android + Linux)

Native BaumAgent/BaumAI client. Originally an Android-only Flutter app; this project now also builds a native Linux desktop target from the same `lib/` code (see `linux/`), rather than a separate fork — this is standard Flutter multi-platform practice (one `pubspec.yaml`, one `lib/`, one native runner per platform).

See the [top-level README](../../../README.md) for the pairing flow, WebSocket protocol, and architecture decisions shared across all clients.

## Linux desktop notes

Everything in `lib/` is shared with Android. Two things don't have a Linux backend and are hidden on that platform instead of crashing:

- **QR camera scanning** (`mobile_scanner`) — pairing_screen.dart falls back to the existing manual URL + code entry, which was already the primary flow.
- **Voice dictation** (`speech_to_text`) — no Linux implementation exists for this plugin; the dictate button is hidden via `VoiceService.isSupported`.

### Build

```bash
flutter pub get
flutter build linux --release
# output: build/linux/x64/release/bundle/
```

Requires (Ubuntu/Debian): `clang`, `cmake`, `ninja-build`, `pkg-config`, `libgtk-3-dev`, `libsecret-1-dev`, `libjsoncpp-dev`.

**Known Flutter 3.27.x quirk**: a clean build (no prior `build/` directory) can fail with `CMake Error ... native_assets/linux: No such file or directory` — Flutter's Linux CMake install step expects that directory even though this project has no native (FFI) assets. Workaround until upgrading past the Flutter version that fixes this:

```bash
mkdir -p build/native_assets/linux
flutter build linux --release
```

**Compiler note**: if `clang++` isn't on `PATH` but is installed as a versioned package (e.g. `clang-21` via `/usr/lib/llvm-21/bin/clang++`), add that directory to `PATH` rather than reinstalling — Flutter's Linux CMake toolchain looks for a bare `clang++`.

The app's `linux/CMakeLists.txt` also downgrades one warning (`-Wno-error=deprecated-literal-operator`) to unblock a vendored `nlohmann/json` header inside the `flutter_secure_storage_linux` plugin that trips `-Werror` on newer clang — third-party code, not ours to fix here.
