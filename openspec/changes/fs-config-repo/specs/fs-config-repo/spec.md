# fs-config-repo Specification

## Purpose

The Filesystem tab SHALL let users browse a remote GitHub repository or subfolder directly from the file browser and selectively upload files and folders to the device LittleFS.

## ADDED Requirements

### Requirement: Cache device-declared links on connect

The app SHALL request the device's remote link information via the settings protocol after connection and SHALL cache the filesystem link (`fsUrl`) and OTA link (`otaUrl`) in `DeviceProvider`.

#### Scenario: Device declares a filesystem link
- **WHEN** the app connects to a device and receives a `LINKS_INFO_DATA` response with a non-empty `fs_url`
- **THEN** `DeviceProvider` exposes `fsUrl` for that connection

#### Scenario: Device declares no links
- **WHEN** the app connects to a device and the `LINKS_INFO_DATA` response has empty URLs (or older firmware never responds)
- **THEN** `DeviceProvider` treats the links as unset

### Requirement: Parse GitHub repository and subfolder URLs

The app SHALL convert a GitHub URL (e.g. `https://github.com/owner/repo` or `https://github.com/owner/repo/tree/branch/subfolder`) into owner, repo, ref (defaulting to `HEAD`), and subfolder path components.

#### Scenario: Plain repository URL
- **WHEN** `RepoTreeService` parses `https://github.com/rambros3d/RadioKit`
- **THEN** owner is `rambros3d`, repo is `RadioKit`, ref is `HEAD`, and subfolder is empty

#### Scenario: Subfolder repository URL
- **WHEN** `RepoTreeService` parses `https://github.com/rambros3d/RadioKit/tree/main/configs/sensors`
- **THEN** owner is `rambros3d`, repo is `RadioKit`, ref is `main`, and subfolder is `configs/sensors`

### Requirement: Remote repo browser modal in Filesystem tab

The Filesystem tab SHALL provide a remote repository browse action button in its toolbar/FAB and empty-directory menu. Tapping the action SHALL open a modal window displaying the directory tree of the repository/subfolder with selective checkboxes for files and directories.

#### Scenario: Open modal with declared repo link
- **WHEN** the user taps the remote repo action button
- **THEN** the modal opens, pre-fills the configured `fs_url`, fetches the tree structure, and displays the folder hierarchy

#### Scenario: Editable repository URL in modal
- **WHEN** the user edits the repository URL in the modal and submits
- **THEN** the modal fetches and renders the tree corresponding to the new URL

### Requirement: Granular file and folder selection

The modal SHALL allow the user to select individual files or entire folders. Checking a folder SHALL automatically check all descendant files and folders. The modal SHALL display the total byte size of selected items and compare it against available device storage.

#### Scenario: Select a folder
- **WHEN** the user checks a directory containing multiple files
- **THEN** all files within that directory are marked selected and the total size is updated

### Requirement: Sequential upload to board LittleFS

Tapping "Upload to Board" SHALL fetch raw bytes for each selected file from GitHub and upload them sequentially to the connected board at the active destination directory using `DeviceFsService.writeFileUpload` (CRC32-verified).

#### Scenario: Successful batch upload
- **WHEN** the user selects 3 files and taps "Upload to Board"
- **THEN** each file is uploaded with live progress indication, and on completion the modal closes and the file list refreshes

#### Scenario: Partial failure handling
- **WHEN** one file in the batch fails network download or transfer
- **THEN** the modal displays an error status, leaves successfully uploaded files on the board, and allows retrying remaining files