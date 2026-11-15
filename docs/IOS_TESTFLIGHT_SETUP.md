# NIKO iPhone distribution through GitHub Actions

This repository can build iOS on GitHub-hosted macOS runners. A Windows computer is sufficient to edit the project and manage the workflow; Xcode runs on the hosted macOS runner.

## Current status and limitations

- The iOS Simulator workflow runs Flutter analysis, Flutter tests, and a simulator build.
- The workflow generates a temporary Flutter iOS Runner scaffold during CI because `mobile/ios` is not yet tracked in this branch. This is a reproducible build scaffold, not a committed native iOS implementation.
- The signed IPA and TestFlight jobs are gated behind repository configuration. They do not run until the owner deliberately configures Apple signing secrets and sets `ENABLE_IOS_SIGNING=true`.
- A successful simulator build is not an installable iPhone IPA and is not proof of physical-device operation.
- The app's chat API still requires a real JWT sign-in integration. TestFlight installation alone will not make authenticated chat work.

## Apple requirements

### For Simulator CI only

No paid Apple membership or signing certificate is needed to run the simulator workflow.

### For installing on a physical iPhone through TestFlight

1. An Apple Account with two-factor authentication enabled.
2. Active Apple Developer Program membership. Apple's published price is USD 99 per membership year (or local-currency pricing where available). A free Apple developer account does not provide TestFlight distribution.
3. Identity verification and legal account details. For an individual account, Apple's enrollment guidance says the legal name is displayed as the seller name.
4. An explicit App ID / Bundle ID. The workflow default is `com.nikoai.niko`; first confirm it is available in the Apple Developer account. If a different ID is needed, set the GitHub Actions repository variable `IOS_BUNDLE_ID` to exactly the same value and use it consistently in the App ID, App Store Connect app record, and provisioning profile.
5. An App Store Connect app record using that Bundle ID and a unique SKU.
6. An Apple Distribution certificate and an App Store provisioning profile for that App ID.
7. An App Store Connect API key with permission to upload builds (App Manager or an appropriately privileged role).

Apple references:
- https://developer.apple.com/programs/
- https://developer.apple.com/help/account/membership/program-enrollment/
- https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/
- https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/sign-xcode-applications

## GitHub configuration

In the repository, open **Settings → Secrets and variables → Actions**.

### Repository variable

Create this variable only after choosing the final App ID:

- `IOS_BUNDLE_ID`: `com.nikoai.niko` (or the exact alternative registered with Apple)
- `ENABLE_IOS_SIGNING`: set to `true` only after every signing secret below is ready. Leave unset/false before that.

### Repository secrets

Create these Actions secrets. Never commit them or paste them into an issue, chat, source file, or workflow log.

| Secret | Value |
|---|---|
| `IOS_CERTIFICATE_P12_BASE64` | Base64 contents of the Apple Distribution `.p12` certificate |
| `IOS_CERTIFICATE_PASSWORD` | Password used when exporting the `.p12` |
| `IOS_PROVISIONING_PROFILE_BASE64` | Base64 contents of the App Store `.mobileprovision` profile |
| `IOS_TEAM_ID` | Apple Developer Team ID |
| `IOS_KEYCHAIN_PASSWORD` | A new strong random password used only for the temporary CI keychain |
| `ASC_KEY_ID` | App Store Connect API key ID |
| `ASC_ISSUER_ID` | App Store Connect API issuer ID |
| `ASC_PRIVATE_KEY` | Full contents of the downloaded App Store Connect `.p8` private key |

The App Store Connect API private key is shown/downloadable only when created. Keep a secure backup. Do not send it to anyone.

## Creating the signing files from Windows

These are one-time owner actions in Apple's developer portals. They do not require Xcode on the Windows PC.

1. Install OpenSSL from a trusted Windows distribution.
2. Generate a private key and CSR locally:
   ```powershell
   openssl req -new -newkey rsa:2048 -nodes -keyout niko_distribution.key -out niko_distribution.csr
   ```
3. In Apple Developer → Certificates, Identifiers & Profiles, create an **Apple Distribution** certificate and upload the CSR. Download the issued certificate.
4. Convert the downloaded DER certificate to PEM and export a password-protected P12:
   ```powershell
   openssl x509 -inform DER -in distribution.cer -out distribution.pem
   openssl pkcs12 -export -inkey niko_distribution.key -in distribution.pem -out niko_distribution.p12
   ```
5. In Profiles, create an **App Store** provisioning profile for the exact NIKO App ID and the Apple Distribution certificate. Download the `.mobileprovision` file.
6. Convert the two files to Base64 for pasting into GitHub Actions secrets:
   ```powershell
   [Convert]::ToBase64String([IO.File]::ReadAllBytes(".\\distribution.p12")) | Set-Clipboard
   ```
   Paste the clipboard into `IOS_CERTIFICATE_P12_BASE64`. Repeat with the profile:
   ```powershell
   [Convert]::ToBase64String([IO.File]::ReadAllBytes(".\\NIKO_AppStore.mobileprovision")) | Set-Clipboard
   ```
   Paste into `IOS_PROVISIONING_PROFILE_BASE64`. Do not paste either value into this chat.
7. In App Store Connect → Users and Access → Integrations → App Store Connect API, create an API key with upload permissions. Record the Key ID and Issuer ID, and store the downloaded `.p8` file contents as `ASC_PRIVATE_KEY`.
8. Add all secrets in GitHub, then set `ENABLE_IOS_SIGNING=true`.

Keep `niko_distribution.key`, the `.p12`, provisioning profile, and `.p8` private. Remove temporary copies from shared or untrusted computers after securely backing them up.

## Running the workflow

1. Open **Actions → Build NIKO iOS**.
2. Choose **Run workflow** on `feat/tab-ai-parity-foundation`.
3. Leave `upload_testflight` unchecked for a signed IPA artifact only.
4. Select `upload_testflight` only when you intend to upload that build to App Store Connect/TestFlight.
5. Download `niko-ai-ios-ipa` only after the signed IPA job succeeds. For a TestFlight upload, wait for Apple's processing to finish in App Store Connect.

The workflow never uploads to TestFlight on ordinary pushes. Upload requires an explicit manual workflow dispatch with `upload_testflight=true`.

## Install on iPhone

1. Install Apple's TestFlight app from the App Store.
2. In App Store Connect, add the Apple Account used on the iPhone as an internal tester, or create an external testing group.
3. For external testers, complete Apple's Beta App Review when requested.
4. Accept the TestFlight invitation on the iPhone and install NIKO.
5. Test microphone and speech-recognition permissions, text entry, app lifecycle, and network connectivity on the physical device.

## What still blocks a useful NIKO test

The current mobile client does not yet have a sign-in screen, token acquisition, or Keychain-backed JWT storage. The backend correctly rejects anonymous chat requests. Do not put a static JWT, backend signing secret, or provider key in the app. A real authentication provider and secure client integration must be implemented before the TestFlight app can use `/v1/chat`.

The iOS Runner is generated during CI and is not yet committed as a native project. Native Swift audio-session and local NIKO wake-word work, physical-device background-audio validation, and iPhone acceptance testing remain separate tasks.
