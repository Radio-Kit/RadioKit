import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:radiokit_widgets/radiokit_widgets.dart';
import '../../providers/settings_provider.dart';

/// A read-only designer canvas preview that respects the app's
/// [SettingsProvider.overrideTheme] setting.
///
/// When [overrideTheme] is enabled, the preview uses the current app theme
/// instead of the design's saved skin. When disabled, the design's own
/// [DesignerState.activeSkin] is used (falling back to [fallbackTokens]).
class DesignPreview extends StatelessWidget {
  final DesignerState state;
  final RKTokens fallbackTokens;

  const DesignPreview({
    super.key,
    required this.state,
    required this.fallbackTokens,
  });

  /// Resolves which [RKTokens] to use for the preview.
  ///
  /// When [overrideTheme] is true, the fallback (app) tokens are always
  /// used.  When false, the design's [skin] is used unless it is
  /// `'default'`, in which case the fallback tokens apply.
  static RKTokens resolveTokens({
    required bool overrideTheme,
    required String skin,
    required RKTokens fallbackTokens,
  }) {
    final useDeviceSkin = !overrideTheme && skin != 'default';
    return useDeviceSkin
        ? (RKTokens.presetsByName[skin] ?? fallbackTokens)
        : fallbackTokens;
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        final settings = context.watch<SettingsProvider>();
        final previewTokens = resolveTokens(
          overrideTheme: settings.overrideTheme,
          skin: state.activeSkin,
          fallbackTokens: fallbackTokens,
        );
        return Container(
          color: fallbackTokens.base300,
          child: RKTheme(
            tokens: previewTokens,
            child: AbsorbPointer(
              child: DesignerCanvas(state: state),
            ),
          ),
        );
      },
    );
  }
}
