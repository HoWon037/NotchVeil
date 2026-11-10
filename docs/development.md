# Development

## Toolchain

Use a full Xcode installation with a Swift 6.1 or newer toolchain. The build script respects `DEVELOPER_DIR`, or uses the installation selected by `xcode-select`.

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
zsh scripts/check.sh
./scripts/build-app.sh
```

CI runs tests on macos-15 and macos-latest. The packaging job creates a compressed DMG containing the app and an Applications shortcut. CI artifacts are ad-hoc signed development builds, not notarized releases.

Create the disk image locally with `zsh scripts/package-dmg.sh`. It rebuilds the app, verifies the disk image, and writes `dist/NotchVeil.dmg`. An existing DMG is replaced only after the new image passes verification. Packaging does not sign or notarize the disk image.

Local builds target the build machine's architecture. The v0.4.1 preview DMG is arm64 (Apple Silicon), not a universal binary. The deployment target alone does not imply that the downloadable build runs on Intel Macs.

`scripts/check.sh` is the shared local/CI entry point for shell syntax, plist metadata, Swift formatting, unit tests and isolated script tests. It does not install or launch the app. The build script assembles and verifies a staged bundle before replacing its previous output. Compilation, resource and signing failures leave the previous output untouched. If replacement fails, the script restores the previous bundle; if restoration also fails, its backup is kept and the path is printed.

## Build and run

```sh
./scripts/run.sh
```

To build without launching, use `./scripts/build-app.sh`. The app is written to `dist/NotchVeil.app`. To stop running development copies, use `./scripts/stop.sh`; this stops all NotchVeil processes owned by the current user.

## Install from source

```sh
./scripts/install.sh
```

The installer builds the app, backs up an existing installation, then replaces `/Applications/NotchVeil.app`. To use another writable folder, supply the full app path, for example `./scripts/install.sh /path/to/NotchVeil.app`. The parent folder must already exist. Symlinks and unrelated existing bundles are rejected.

An enabled login item is repaired and tested after replacement. This can take several minutes. A failed login-item check leaves the new app installed and returns exit status 1. The backup path is printed during installation. To restore it, quit NotchVeil, move the new bundle aside, and move the backup to its original app path.

## Code layout

- `Sources/NotchVeil`: AppKit lifecycle, panels, SwiftUI settings and login-item registration.
- `Sources/NotchVeilCore`: geometry, preference migration and language selection, independently tested.
- `Sources/LoginLauncher`: the embedded login helper.
- `Tests/NotchVeilCoreTests`: unit tests and synthetic screen matrix.
- `Tests/InstallerTests`: isolated installation scenarios with mocked system commands.
- `Tests/BuildScriptTests`: output-path safety checks without compiling or touching installed apps.
- `Resources`: final artwork, app metadata and native icon document.

The core target is an internal module, not a separately distributed library. Keep window management on the main actor, and keep geometry calculations independent of AppKit.

## Icons

`Resources/AppIcon-source.png` is the approved source artwork. Regenerate committed derived assets with:

```sh
swift scripts/make-app-icon.swift Resources
```

The exporter creates the legacy ICNS, a 1024px PNG and the native catalog artwork. The catalog crop removes the approved source's outer inset; keep that inset when replacing the source or update the documented crop in the exporter.

With a macOS 26+ SDK the app build compiles `Resources/NotchVeil.icon` into `Assets.car`. Older SDKs use the legacy ICNS. The settings icon has dedicated 44px and 88px representations rather than using the system-composited app icon.

## Signing and login items

Local builds default to ad-hoc signing. To sign with your own identity:

```sh
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/build-app.sh
```

Do not commit certificates, private keys or signing credentials. A Developer ID signature alone is not notarization. Public distribution should use an appropriate signing and notarization workflow.

Developer ID builds request a secure timestamp; ad-hoc builds disable timestamping. This build script does not submit apps for notarization or staple tickets. Do not describe its output as notarized.

During development on macOS 27, replacing an ad-hoc signed app could leave an enabled login item unable to spawn, with `EX_CONFIG` (78). Waiting and re-registering from the installing shell worked in that environment. This is a measured workaround, not a guaranteed rule for every macOS release.

The installer preserves whether launch at login was registered, waits between repair attempts, then requires both a finished app launch at the exact destination and a successful launcher exit. `SETTLE_SECONDS` and `MAX_ATTEMPTS` control that bounded retry policy.

```sh
./scripts/install.sh
/Applications/NotchVeil.app/Contents/MacOS/NotchVeil --check-running
```

The readiness command is read-only: exit 0 means another instance of that exact app bundle has finished launching; exit 1 means it has not. It does not prove the launcher started it, so the installer also checks the launchd job.

Manual re-registration explicitly enables the login item, including after an interrupted repair:

```sh
/Applications/NotchVeil.app/Contents/MacOS/NotchVeil --register-login-item
launchctl print gui/$(id -u)/com.limdy.NotchVeil.LoginLauncher
```

## Compatibility testing

The [screen matrix](testing/screen-matrix.md) tests calculations, not physical MacBook appearance. Check whole-screen appearance, fullscreen transitions, Mission Control, display reconnects and sleep/wake on hardware before claiming compatibility.
