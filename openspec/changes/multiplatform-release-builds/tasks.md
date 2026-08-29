## 1. Platform Runners & Asset Packaging

- [x] 1.1 Restore and verify `radiokit-app/windows/` and `radiokit-app/macos/` runner directories on `multi-ui`
- [x] 1.2 Update `.github/workflows/release-windows.yml` to install Inno Setup and build `radiokit-${VERSION}-windows-x64-setup.exe`
- [x] 1.3 Update `.github/workflows/release-macos.yml` to package `Runner.app` into `radiokit-${VERSION}-macos.dmg` via `hdiutil`
- [x] 1.4 Update `.github/workflows/release-linux-flatpak.yml` for dynamic git ref injection and naming `radiokit-${VERSION}.flatpak`
- [x] 1.5 Update `.github/workflows/release-android.yml` for robust release asset uploading

## 2. Commit & Push

- [ ] 2.1 Commit changes to `multi-ui` and push to `origin/multi-ui`

## 3. Tagging & Build Verification

- [ ] 3.1 Create and push test release tag `v2.0.0-test1` to GitHub
- [ ] 3.2 Monitor and verify GitHub Actions runs across all 4 platforms
