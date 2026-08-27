## ADDED Requirements

### Requirement: Standardized Multi-Platform Release Triggers
The CI release workflows SHALL trigger automatically whenever a version tag matching `v*` (e.g. `v1.0.0`) is pushed, and SHALL support manual invocation via `workflow_dispatch`.

#### Scenario: Git tag push triggers platform workflows
- **WHEN** a user pushes a tag formatted as `v1.2.3` to the repository
- **THEN** Android, Windows, macOS, and Linux Flatpak release workflows are initiated concurrently

#### Scenario: Manual trigger via workflow dispatch
- **WHEN** a workflow is triggered via `workflow_dispatch` with an optional target tag or commit
- **THEN** the workflow executes the build and release steps using the specified reference

### Requirement: Windows Inno Setup Installer Generation
The Windows release workflow SHALL compile Flutter Windows artifacts into a standalone installer executable (`.exe`) via Inno Setup and create a compressed `.zip` archive.

#### Scenario: Windows release build
- **WHEN** the Windows release workflow executes on `windows-latest`
- **THEN** it generates `radiokit-<version>-windows-x64-setup.exe` and `radiokit-<version>-windows-x64.zip`

### Requirement: macOS Apple Silicon DMG Generation
The macOS release workflow SHALL build native Apple Silicon binaries on `macos-latest` and package the application bundle into a mountable Disk Image (`.dmg`).

#### Scenario: macOS release build
- **WHEN** the macOS release workflow executes on `macos-latest`
- **THEN** it packages `RadioKit.app` into `radiokit-<version>-macos-arm64.dmg`

### Requirement: Linux Flatpak Single-File Bundle Generation
The Linux Flatpak release workflow SHALL build the application via `flatpak-builder` and export a standalone `.flatpak` bundle.

#### Scenario: Linux release build
- **WHEN** the Linux Flatpak release workflow executes on `ubuntu-latest`
- **THEN** it produces `radiokit-<version>-linux-x86_64.flatpak`

### Requirement: Android Release APK Generation
The Android release workflow SHALL build a signed/universal release APK.

#### Scenario: Android release build
- **WHEN** the Android release workflow executes on `ubuntu-latest`
- **THEN** it produces `radiokit-<version>-android.apk`

### Requirement: Race-Free Soft Release Publishing
All platform workflows SHALL publish and attach their generated assets to the GitHub Release corresponding to the git tag without race condition failures or overwriting other platform assets.

#### Scenario: Concurrent asset uploads
- **WHEN** multiple platform workflows finish at approximately the same time
- **THEN** the release is created if it does not yet exist, and each platform asset is attached via softprops/action-gh-release with clobber enabled
