# NotchVeil

**English** · [한국어](README.ko.md)

Blend your MacBook’s notch into a black menu bar background.

## Installation

A public app download is not available yet. This repository currently provides the source code; see [Development](docs/development.md) to build the app yourself. Xcode is only needed for building, not for running a packaged app.

If you already have a packaged `NotchVeil.app`, move it into **Applications** and open it. Local builds are ad-hoc signed and are not notarized; macOS may block a downloaded build. See the [distribution notes](docs/development.md#signing-and-login-items).

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
