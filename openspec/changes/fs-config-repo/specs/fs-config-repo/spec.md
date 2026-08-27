# fs-config-repo Specification

## Purpose

The FS manager SHALL let users browse a device-declared GitHub config repository and install config bundles onto the device filesystem with one tap.

## ADDED Requirements

### Requirement: Cache device-declared repo info on connect

The app SHALL request the device's config repository information via the settings protocol after connection and SHALL cache the repo URL and subdir in `DeviceProvider` for the connected device.

#### Scenario: Device declares a repo
- **WHEN** the app connects to a device and receives a `REPO_INFO_DATA` response with a non-empty URL
- **THEN** `DeviceProvider` exposes `repoUrl` and `repoSubdir` for that connection and the FS manager offers the config-browse feature

#### Scenario: Device declares no repo
- **WHEN** the app connects to a device and the `REPO_INFO_DATA` response has an empty URL (or older firmware never responds)
- **THEN** `DeviceProvider` treats the repo as unset and the FS manager shows a hint that no config repo is configured

### Requirement: Parse GitHub repository URLs

The app SHALL convert a normal GitHub URL (e.g. `https://github.com/owner/repo`) into the raw content base used for fetching, extracting owner, repo, and an optional ref. When no ref is given, `HEAD` SHALL be used.

#### Scenario: Plain repository URL
- **WHEN** `ConfigRepoService` parses `https://github.com/rambros3d/RadioKit`
- **THEN** the raw base resolves to `https://raw.githubusercontent.com/rambros3d/RadioKit/HEAD`

#### Scenario: Branch-qualified repository URL
- **WHEN** `ConfigRepoService` parses `https://github.com/rambros3d/RadioKit/tree/dev/configs`
- **THEN** the raw base resolves to `https://raw.githubusercontent.com/rambros3d/RadioKit/dev`

#### Scenario: Non-GitHub URL
- **WHEN** `ConfigRepoService` parses a URL whose host is not `github.com`
- **THEN** parsing fails and the catalog sheet shows an error state

### Requirement: Fetch and parse the config manifest

The app SHALL fetch `radiokit.json` from the repo subdir (`{rawBase}/{subdir}/radiokit.json`) and parse it into manifest items, each with id, name, description, version, optional icon, and a list of files (name + optional target path). A malformed or missing manifest SHALL result in a visible error state with retry.

#### Scenario: Manifest present and valid
- **WHEN** the catalog sheet loads and the manifest fetch succeeds with a parseable `radiokit.json`
- **THEN** the sheet renders one card per config item

#### Scenario: Manifest missing or unreachable
- **WHEN** the manifest fetch returns HTTP 404, times out, or fails network validation
- **THEN** the catalog sheet shows an error state with a retry action

#### Scenario: Malformed manifest
- **WHEN** the fetched manifest is not valid JSON or lacks a `configs` array
- **THEN** the catalog sheet shows an error state rather than an empty catalog

### Requirement: Show catalog with capacity bar

The catalog sheet SHALL display each config as a card with its name, description, version, and file count, and SHALL show the device filesystem's live used/total capacity so the user can gauge available space before installing.

#### Scenario: Catalog opened with connected FS device
- **WHEN** the user opens the config catalog sheet on a connected device with a declared repo
- **THEN** the sheet lists config cards and a capacity indicator reflecting `DeviceFsService.getInfo()`

### Requirement: Install a config bundle to the device filesystem

Tapping a config card SHALL fetch each file from the repo and write it to the device via the CRC32-verified upload protocol at its declared target path, or `/config/<name>` when no path is declared. The install SHALL report per-file progress and a final success/failure summary, and the FS tab SHALL refresh after a successful install.

#### Scenario: Successful install
- **WHEN** the user taps a config with files `a.json` (path `/config/a.json`) and `b.html` (no path)
- **THEN** `a.json` is written to `/config/a.json` and `b.html` to `/config/b.html`, each verified by CRC32, and the FS tab refreshes its listing

#### Scenario: Partial install failure
- **WHEN** the second file of a two-file config fails to upload after the first succeeded
- **THEN** the sheet reports which files succeeded and which failed, offers retry, and leaves the successfully written files in place

#### Scenario: Default path collision
- **WHEN** an installed file targets a path that already exists on the device
- **THEN** the existing file is overwritten (upload protocol truncates)

### Requirement: FS tab browse trigger and no-repo hint

The FS manager SHALL expose a config-browse action when the connected device declares a repo, and SHALL show a compact hint instead when it does not.

#### Scenario: Repo declared
- **WHEN** the FS tab is shown for a device with a declared repo
- **THEN** the tab offers a CONFIGS action that opens the catalog sheet

#### Scenario: No repo declared
- **WHEN** the FS tab is shown for a device with no declared repo
- **THEN** the tab shows a hint that the device does not declare a config repo, and no CONFIGS action is offered