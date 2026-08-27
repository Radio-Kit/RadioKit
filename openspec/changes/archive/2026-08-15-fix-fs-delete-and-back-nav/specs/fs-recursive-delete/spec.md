# fs-recursive-delete Specification

## Purpose

`FS_DELETE` with the RECURSIVE flag SHALL delete a directory tree (files and subfolders at any depth) on the device LittleFS, and the firmware SHALL honor the flag instead of ignoring it.

## ADDED Requirements

### Requirement: Recursive delete removes files and subfolders

The firmware `handleDelete` SHALL use the RECURSIVE flag from the `FS_DELETE` payload. When the flag is set and the target is a directory, the firmware SHALL walk the directory, delete every file and subdirectory recursively, and finally remove the emptied directory. The walk SHALL be bounded by a maximum depth to protect the main-loop stack.

#### Scenario: Delete a nested folder tree
- **WHEN** the app sends `FS_DELETE` for a directory containing files and a subfolder (which itself contains a file) with the RECURSIVE flag set
- **THEN** the device deletes every file, recurses into the subfolder, removes the subfolder, removes the now-empty parent directory, and responds `FS_DELETE_ACK` with `RK_FS_ERR_OK`

#### Scenario: Delete a file with the recursive flag set
- **WHEN** the app sends `FS_DELETE` for a regular file with the RECURSIVE flag set
- **THEN** the file is removed and the response is `RK_FS_ERR_OK`

#### Scenario: Recursion depth is bounded
- **WHEN** a directory tree exceeds the configured maximum recursion depth
- **THEN** the delete fails and the response is not `RK_FS_ERR_OK` (the tree is left in a safe, partially-deleted state)

### Requirement: Non-recursive delete semantics are unchanged

When the RECURSIVE flag is clear, `FS_DELETE` SHALL keep current behavior: files are removed, empty directories are removed, and a non-empty directory is NOT removed.

#### Scenario: Non-recursive delete of an empty directory
- **WHEN** the app sends `FS_DELETE` for an empty directory with the RECURSIVE flag clear
- **THEN** the directory is removed and the response is `RK_FS_ERR_OK`

#### Scenario: Non-recursive delete of a non-empty directory
- **WHEN** the app sends `FS_DELETE` for a non-empty directory with the RECURSIVE flag clear
- **THEN** the directory and its contents are left in place and the response is `RK_FS_ERR_NOT_FOUND`

### Requirement: App sends the recursive flag for directories

The Flutter FS manager SHALL request deletion of directories with the RECURSIVE flag set, for both single-entry delete and multi-select delete.

#### Scenario: Single folder delete from the action sheet
- **WHEN** the user deletes a folder via the FS action sheet
- **THEN** the app sends `FS_DELETE` with the RECURSIVE flag set and, on `RK_FS_ERR_OK`, refreshes the listing showing the folder gone

#### Scenario: Multi-select delete including folders
- **WHEN** the user deletes multiple selected items that include folders
- **THEN** each folder is deleted with the RECURSIVE flag set and the listing refreshes
