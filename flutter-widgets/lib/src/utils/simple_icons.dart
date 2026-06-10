import 'package:flutter/widgets.dart';

/// A custom implementation of SimpleIcons that bypasses the broken official package.
/// This uses the same API but works with modern Flutter versions.
class SimpleIcons {
  SimpleIcons._();

  /// Renault icon (Unicode 0xf3bf)
  static const IconData renault = IconData(
    0xf3bf,
    fontFamily: 'SimpleIcons',
    fontPackage: 'radiokit_widgets',
  );
}
