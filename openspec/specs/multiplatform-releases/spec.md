# multiplatform-releases Specification

## Purpose
TBD - created by archiving change multiplatform-release-builds. Update Purpose after archive.
## Requirements
### Requirement: Automated Multi-Platform Release Asset Packaging
The CI release workflows SHALL produce distinct, native installer and bundle assets for all supported platforms upon pushing a release tag.

#### Scenario: Android release build
- **WHEN** a release tag starting with `v*` is pushed
- **THEN** the Android workflow builds `radiokit-app` with `flutter build apk --release`
- **AND** publishes `radiokit-${VERSION}.apk` to the GitHub Release.

#### Scenario: Linux Flatpak release build
- **WHEN** a release tag starting with `v*` is pushed
- **THEN** the Flatpak workflow injects the current git ref into `flatpak/flatpak-flutter.yml`
- **AND** builds and publishes `radiokit-${VERSION}.flatpak` to the GitHub Release.

#### Scenario: macOS release build
- **WHEN** a release tag starting with `v*` is pushed
- **THEN** the macOS workflow builds `radiokit-app` with `flutter build macos --release`
- **AND** packages `Runner.app` into `radiokit-${VERSION}-macos.dmg` via `hdiutil`
- **AND** publishes the `.dmg` to the GitHub Release.

#### Scenario: Windows release build
- **WHEN** a release tag starting with `v*` is pushed
- **THEN** the Windows workflow builds `radiokit-app` with `flutter build windows --release`
- **AND** compiles the Inno Setup installer via `iscc`
- **AND** publishes `radiokit-${VERSION}-windows-x64-setup.exe` to the GitHub Release.

