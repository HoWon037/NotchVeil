# Contributing

Keep changes focused and explain the user-visible problem they address. For display bugs, include your macOS version, Mac model, display scaling and reproduction steps. Redact personal paths and private information from logs or screenshots.

Before submitting a change:

```sh
zsh scripts/check.sh
./scripts/build-app.sh
```

Use the full Xcode toolchain described in [Development](docs/development.md). Add regression coverage for behavior changes. Do not present synthetic screen tests as hardware verification.

Keep Korean and English UI text and documentation in sync. Do not add generated build output, signing credentials, design experiments or machine-specific paths.

The project is licensed under [MIT](LICENSE). Contributions are submitted under the same license.
