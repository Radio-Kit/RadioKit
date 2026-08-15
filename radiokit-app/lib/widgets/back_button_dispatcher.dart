import 'package:flutter/material.dart';

/// Tracks imperatively-pushed modal routes (bottom sheets, dialogs) across
/// every Navigator that go_router manages — the root Navigator and each
/// `StatefulShellRoute` branch Navigator.
///
/// Registered in go_router's `observers:` list. Only [PopupRoute] subclasses
/// are recorded: page routes belong to go_router and must never be popped
/// directly by the back dispatcher (go_router tracks its own page stack and
/// URL state).
class ModalRouteTracker extends NavigatorObserver {
  final List<Route<dynamic>> _modals = [];

  /// The topmost tracked modal, or null when none is open.
  Route<dynamic>? get topModal => _modals.isEmpty ? null : _modals.last;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) _modals.add(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _modals.remove(route);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _modals.remove(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) _modals.remove(oldRoute);
    if (newRoute != null && newRoute is PopupRoute) _modals.add(newRoute);
  }
}

/// Intercepts the Android system back button so an open modal surface
/// (bottom sheet, dialog) is dismissed before the go_router delegate can
/// exit the app.
///
/// Workaround for flutter/flutter#145290 ("Predictive back can close app when
/// navigation stack is not empty"): with predictive back on Android 13+,
/// back gestures dispatch through the go_router delegate, whose route
/// discovery can skip modals living on shell-branch Navigators — the app
/// exits instead of dismissing the sheet. When a modal is open we pop it
/// ourselves (on whichever Navigator owns it) and consume the back event;
/// otherwise we delegate to the framework/go_router path.
class RadioKitBackDispatcher extends RootBackButtonDispatcher {
  final ModalRouteTracker tracker;

  RadioKitBackDispatcher({required this.tracker});

  @override
  Future<bool> didPopRoute() async {
    final top = tracker.topModal;
    final navigator = top?.navigator;
    if (top != null && navigator != null && navigator.mounted) {
      navigator.pop();
      return true;
    }
    return super.didPopRoute();
  }
}
