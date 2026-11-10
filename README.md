# NotchVeil

**English** · [한국어](README.ko.md)

Blend your MacBook’s notch into a black menu bar background.

## Installation

[Download NotchVeil.dmg — v0.4.1 Preview](https://github.com/HoWon037/NotchVeil/releases/download/v0.4.1/NotchVeil.dmg) · Apple Silicon

Open `NotchVeil.dmg`, drag **NotchVeil** to **Applications**, then launch it from Applications. Xcode is not needed to install the app.

This preview is ad-hoc signed and **not notarized by Apple**. macOS may block it on first launch, and launch at login may fail after updates. See the [distribution notes](docs/development.md#signing-and-login-items). To build from source instead, see [Development](docs/development.md).

## Features

- Fits each display’s notch using its safe area, without model-specific sizes.
- Runs behind app windows without intercepting clicks or keyboard input.
- Leaves displays without a notch untouched.
- Optional launch at login and menu bar icon, both off by default.
- English and Korean, selectable in Settings.

## Requirements

A Mac with a notched display. The app targets macOS 12 or later; launch at login requires macOS 13 or later.

The minimum OS version is a deployment target, not a claim of testing on every supported macOS release or MacBook model. See [testing coverage](docs/testing/screen-matrix.md).

## Settings

Open NotchVeil from Applications to access Settings, even if its menu bar icon is hidden.

Turn notch hiding on or off, enable launch at login, show the menu bar icon, or select a language. Closing Settings keeps the app running; choose **Quit App** to stop it. Login launches start without opening Settings.

## Limitations

- NotchVeil does not hide the notch on the lock screen.
- Display geometry is covered by synthetic tests, not visual verification on every MacBook.
- Ad-hoc signed development builds can have login-item problems after updates. See [troubleshooting](docs/development.md#signing-and-login-items).

## Development

Build, test and installation commands are in [Development](docs/development.md). Bug reports and focused changes are welcome; see [Contributing](CONTRIBUTING.md).

## Privacy

No accounts, analytics or network requests. Preferences are stored locally on your Mac.

## License

[MIT](LICENSE)
