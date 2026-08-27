/// Canonical tab indices for the home screen navigation shell.
///
/// The integer values match the branch order in [createRouter] (`router.dart`).
/// Always use the enum members instead of raw integers to prevent index drift
/// when tabs are added or reordered.
enum TabIndex {
  models,
  flasher,
  designs,
  system,
}
