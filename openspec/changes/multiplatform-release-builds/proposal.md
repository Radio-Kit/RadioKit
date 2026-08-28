## Why

The RadioKit companion app needs automated, verified multi-platform GitHub Actions release builds across Android (APK), Linux (Flatpak), macOS (DMG), and Windows (Inno Setup EXE installer). Currently, Windows and macOS release workflows output raw zip files with potential path errors and asset filename collisions, and the runner projects for Windows/macOS were missing on `multi-ui`. Furthermore, the Flatpak builder had a hardcoded `main` branch tag reference preventing testing on feature branches like `multi-ui`.

## What Changes

- **Restore Platform Runners to `multi-ui`**: Ensure `radiokit-app/windows/` and `radiokit-app/macos/` contain all required runner files (`Runner.xcodeproj`, `CMakeLists.txt`, `RadioKit.iss`, etc.).
- **Windows Inno Setup `.exe` Installer**: Update `.github/workflows/release-windows.yml` to install Inno Setup and compile `radiokit-app/windows/installer/RadioKit.iss` into `radiokit-${VERSION}-windows-x64-setup.exe`.
- **macOS Native `.dmg` Disk Image**: Update `.github/workflows/release-macos.yml` to package `Runner.app` into `radiokit-${VERSION}-macos.dmg` using `hdiutil`.
- **Flatpak Dynamic Tag Injection**: Update `.github/workflows/release-linux-flatpak.yml` to dynamically inject the triggering ref/tag (`${GITHUB_REF_NAME}`) into `flatpak/flatpak-flutter.yml`.
- **Android Release Naming**: Ensure Android builds name the output `radiokit-${VERSION}.apk`.
- **End-to-End Verification**: Push `multi-ui` and a test tag (e.g. `v2.0.0-test1`) to trigger and monitor all 4 platform builders on GitHub Actions.

## Capabilities

### New Capabilities
- `multiplatform-release-matrix`: Automated packaging and GitHub Release asset creation for Android APK, Flatpak bundle, macOS DMG, and Windows EXE.

## Impact

- `.github/workflows/release-windows.yml`: Inno Setup installer compilation and non-colliding asset upload.
- `.github/workflows/release-macos.yml`: `hdiutil` `.dmg` packaging and non-colliding asset upload.
- `.github/workflows/release-linux-flatpak.yml`: Dynamic tag injection and Flatpak bundle creation.
- `radiokit-app/windows/` and `radiokit-app/macos/`: Maintained Flutter platform runners.
