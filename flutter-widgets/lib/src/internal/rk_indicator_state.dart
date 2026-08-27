// Internal shared state machine for sliding indicator widgets.
// Not part of the public API — do not export from radiokit_widgets.dart.

/// Describes the current interaction mode of a sliding indicator.
enum RKToggleMode { none, animating, dragged }

/// Immutable state for a sliding indicator's animation.
///
/// Tracks [start] and [end] positions (fractional slot indices),
/// and the current [toggleMode].
class RKIndicatorState {
  /// The position the indicator started animating from.
  final double start;

  /// The target position the indicator is animating toward.
  final double end;

  /// Current interaction mode.
  final RKToggleMode toggleMode;

  const RKIndicatorState(this.start)
      : end = start,
        toggleMode = RKToggleMode.none;

  const RKIndicatorState._internal(
    this.start,
    this.end,
    this.toggleMode,
  );

  /// Returns the interpolated position at animation progress [t] ∈ [0, 1].
  double valueAt(double t) => start + (end - start) * t;

  /// Starts an animation toward [newEnd] from an optional [current] position.
  RKIndicatorState toEnd(double newEnd, {double? current}) =>
      RKIndicatorState._internal(
        current ?? start,
        newEnd,
        RKToggleMode.animating,
      );

  /// Marks the animation as complete — [start] snaps to [end].
  RKIndicatorState ended() =>
      RKIndicatorState._internal(end, end, RKToggleMode.none);

  /// Enters drag mode. [dragPos] is the current fractional index under the pointer.
  /// [anchorPos] optionally overrides where the animation started from.
  RKIndicatorState dragged(double dragPos, {double? anchorPos}) =>
      RKIndicatorState._internal(
        anchorPos ?? start,
        dragPos,
        RKToggleMode.dragged,
      );

  /// Returns to idle state at an optional [current] fractional position.
  RKIndicatorState idle({double? current}) =>
      RKIndicatorState._internal(
        current ?? end,
        current ?? end,
        RKToggleMode.none,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RKIndicatorState &&
          start == other.start &&
          end == other.end &&
          toggleMode == other.toggleMode;

  @override
  int get hashCode => start.hashCode ^ end.hashCode ^ toggleMode.hashCode;
}
