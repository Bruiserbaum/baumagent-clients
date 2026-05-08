# Code Signing Setup

All three clients are built unsigned by default. Signing activates automatically when the relevant GitHub repository secrets are configured. This document explains how to obtain and configure each certificate.

---

## Android

Android apps must be signed to install outside the Play Store. You need a Java KeyStore (JKS).

### 1. Generate a keystore (one-time)

```bash
keytool -genkeypair -v \
  -keystore baumagent.jks \
  -keyalg RSA -keysize 4096 \
  -validity 10000 \
  -alias baumagent \
  -dname "CN=BaumAgent, OU=, O=Bruiserbaum, L=, S=, C=US"
```

You will be prompted to set a store password and a key password. **Save these — they cannot be recovered.**

### 2. Base64-encode the keystore for CI

```bash
# macOS / Linux
base64 -i baumagent.jks | pbcopy        # copies to clipboard

# Windows (PowerShell)
[Convert]::ToBase64String([IO.File]::ReadAllBytes("baumagent.jks")) | Set-Clipboard
```

### 3. Add GitHub repository secrets

Go to **Settings → Secrets and variables → Actions → New repository secret**:

| Secret name | Value |
|---|---|
| `ANDROID_KEYSTORE` | Base64-encoded `.jks` from step 2 |
| `ANDROID_KEY_ALIAS` | `baumagent` (or whatever alias you used) |
| `ANDROID_KEY_PASSWORD` | Key password from step 1 |
| `ANDROID_STORE_PASSWORD` | Store password from step 1 |

### 4. Local development

Copy `clients/android/baumagent/android/key.properties.example` to `key.properties` (same directory) and fill in your values. Copy `baumagent.jks` to `clients/android/baumagent/android/app/keystore.jks`.

`key.properties` and `keystore.jks` are gitignored.

---

## Windows

Windows code signing prevents SmartScreen warnings. You need a code signing certificate in PFX format.

### Option A — Commercial EV certificate (recommended for distribution)

Purchase an Extended Validation (EV) or OV certificate from a CA such as DigiCert, Sectigo, or GlobalSign. They will issue a `.pfx` or `.p12` file with a password.

> **EV certificates** remove the SmartScreen "Unknown Publisher" warning immediately.
> **OV certificates** remove it after accumulating enough download reputation (can take weeks).

### Option B — Self-signed certificate (testing only)

```powershell
# Run in PowerShell as administrator
$cert = New-SelfSignedCertificate `
  -Type CodeSigningCert `
  -Subject "CN=BaumAgent Dev" `
  -KeyUsage DigitalSignature `
  -FriendlyName "BaumAgent Dev Signing" `
  -CertStoreLocation "Cert:\CurrentUser\My" `
  -NotAfter (Get-Date).AddYears(5)

$pwd = ConvertTo-SecureString -String "changeme" -Force -AsPlainText
Export-PfxCertificate -Cert $cert -FilePath baumagent-dev.pfx -Password $pwd
```

### Base64-encode the PFX

```powershell
# PowerShell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("baumagent.pfx")) | Set-Clipboard
```

```bash
# macOS / Linux
base64 -i baumagent.pfx | pbcopy
```

### Add GitHub repository secrets

| Secret name | Value |
|---|---|
| `WINDOWS_CERT_PFX` | Base64-encoded `.pfx` |
| `WINDOWS_CERT_PASSWORD` | PFX password |

The build workflow signs both `BaumAgentClient.exe` and `BaumAgent-Setup-*.exe` using SHA-256 with a DigiCert RFC 3161 timestamp so signatures remain valid after the certificate expires.

---

## macOS

macOS apps distributed outside the App Store need a **Developer ID Application** certificate to pass Gatekeeper. Notarisation additionally prevents the "unidentified developer" warning on macOS 10.15+.

### Prerequisites

- An Apple Developer Program membership ($99/year)
- Xcode or Command Line Tools installed locally

### 1. Create a Developer ID Application certificate

1. Open **Xcode → Settings → Accounts**, sign in with your Apple ID.
2. Click **Manage Certificates → + → Developer ID Application**.
3. The certificate is created in your system keychain.

Or via the Apple Developer portal: **Certificates, Identifiers & Profiles → Certificates → + → Developer ID Application**.

### 2. Export the certificate as a .p12

```bash
# In Keychain Access:
# 1. Find "Developer ID Application: Your Name (TEAMID)"
# 2. Right-click → Export
# 3. Save as .p12, set a strong password

# Or via CLI (replace MY_CERT with the exact CN shown in Keychain Access):
security export \
  -k login.keychain \
  -t identities \
  -f pkcs12 \
  -o baumagent-dev-id.p12 \
  -P "changeme" \
  "Developer ID Application: Your Name (XXXXXXXXXX)"
```

### 3. Base64-encode for CI

```bash
base64 -i baumagent-dev-id.p12 | pbcopy
```

### 4. Create an app-specific password for notarisation

1. Sign in at [appleid.apple.com](https://appleid.apple.com).
2. **Sign-In and Security → App-Specific Passwords → + Generate**.
3. Name it "BaumAgent CI Notarisation".

### 5. Find your Team ID

```bash
xcrun altool --list-providers -u "your@apple.id" -p "@keychain:AC_PASSWORD"
# Or check developer.apple.com/account → Membership Details
```

### 6. Add GitHub repository secrets

| Secret name | Value |
|---|---|
| `MACOS_CERT_P12` | Base64-encoded `.p12` |
| `MACOS_CERT_PASSWORD` | `.p12` export password |
| `MACOS_NOTARIZE_APPLE_ID` | Your Apple ID email |
| `MACOS_NOTARIZE_TEAM_ID` | 10-character Team ID (e.g. `ABCD123456`) |
| `MACOS_NOTARIZE_APP_PASSWORD` | App-specific password from step 4 |

### What happens in CI

1. The `.p12` is decoded and imported into a temporary keychain.
2. `security find-identity` extracts the exact certificate CN.
3. `codesign` signs the `.app` with the Developer ID, `--options runtime` (hardened runtime), and a secure timestamp.
4. `xcrun notarytool submit` uploads the DMG to Apple for notarisation (async; waits up to 30 minutes).
5. `xcrun stapler staple` attaches the notarisation ticket to the DMG so it works offline.

Notarisation only runs when **both** `MACOS_CERT_P12` and `MACOS_NOTARIZE_APPLE_ID` are set.

---

## Triggering a signed release

```bash
git tag v1.0.1
git push origin v1.0.1
```

The `release.yml` workflow creates the GitHub release and triggers all three build jobs in parallel. Each job signs its output if the corresponding secrets are present.

## Verifying signatures

```bash
# Windows — check signature on installer
signtool verify /pa BaumAgent-Setup-1.0.1.exe

# Android — check APK signature
apksigner verify --verbose BaumAgent-1.0.1.apk

# macOS — check .app inside DMG
hdiutil attach BaumAgent-1.0.1.dmg
codesign --verify --deep --strict /Volumes/BaumAgent*/BaumAgent.app
spctl --assess --type exec --verbose /Volumes/BaumAgent*/BaumAgent.app
```
