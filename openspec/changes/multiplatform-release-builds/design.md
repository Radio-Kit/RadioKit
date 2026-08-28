## Context

The RadioKit companion app targets Android, Linux Flatpak, macOS, and Windows. Each platform requires native packaging (APK for Android, Flatpak bundle for Linux, DMG for macOS, Inno Setup EXE for Windows).

## Goals / Non-Goals

**Goals:**
- Provide robust packaging scripts in `.github/workflows/` for Android, Linux Flatpak, macOS, and Windows.
- Replace generic zip archives with native `.dmg` (macOS) and `.exe` (Windows) installer packages.
- Ensure unique non-colliding asset filenames across all runners.
- Enable testing release builds from `multi-ui` using a test tag.

**Non-Goals:**
- Code signing with paid Apple Developer / Microsoft Authenticode certificates in this phase (unsigned/self-contained native packages).

## Decisions

### Decision 1: Windows Packaging with Inno Setup
- Install Inno Setup on `windows-latest` runner via `choco install innosetup`.
- Compile `radiokit-app/windows/installer/RadioKit.iss` using `iscc.exe /DMyAppVersion=$VERSION`.
- Output: `radiokit-${VERSION}-windows-x64-setup.exe`.

### Decision 2: macOS Packaging with `hdiutil`
- Use native macOS `hdiutil create` tool on `macos-latest` runner:
  `hdiutil create -volname "RadioKit" -srcfolder "radiokit-app/build/macos/Build/Products/Release/Runner.app" -ov -format UDZO "radiokit-${VERSION}-macos.dmg"`
- Output: `radiokit-${VERSION}-macos.dmg`.

### Decision 3: Linux Flatpak Dynamic Ref
- Before running `flatpak-flutter`, update `flatpak/flatpak-flutter.yml` to replace `tag: main` with the triggering git ref `${GITHUB_REF_NAME}`.
- Output: `radiokit-${VERSION}.flatpak`.

### Decision 4: Release Creation Concurrency Handling
- Each runner executes `gh release upload ... --clobber || gh release create ...`.
