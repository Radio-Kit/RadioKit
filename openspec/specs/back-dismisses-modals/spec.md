# back-dismisses-modals Specification

## Purpose

On Android, the system back button SHALL dismiss an open modal surface (bottom sheet or dialog) shown from any shell branch before the app can exit. The app exits only when no modal is open and no in-app route can pop.

## Requirements

### Requirement: Back dismisses open modals before exiting

The app SHALL intercept the Android system back event with a custom `RootBackButtonDispatcher` on `MaterialApp.router`. When any modal route (bottom sheet or dialog) is open on any Navigator managed by the app, the dispatcher SHALL pop that modal and consume the back event; only when no modal is open SHALL it delegate to the go_router delegate (which handles page pops and app exit).

#### Scenario: Back with the device-info sheet open
- **WHEN** the user is on the models page, opens the device-info sheet (INFO/SETTINGS/FILESYSTEM tabs) and presses the system back button
- **THEN** the sheet dismisses, the user remains on the models page, and the app does not exit

#### Scenario: Back with the file editor or action sheet open
- **WHEN** the user has the file editor dialog or the per-entry FS action sheet open on top of the device-info sheet and presses back
- **THEN** the topmost modal dismisses and the underlying sheet remains

#### Scenario: Back with no modal open
- **WHEN** the user is on a shell root page (e.g. models) with no modal open and presses back
- **THEN** the dispatcher delegates to the go_router delegate and the app exits (standard root-page behavior)

### Requirement: Modal tracking observes all navigators

The app SHALL track modal routes across every Navigator that go_router manages (the root Navigator and each `StatefulShellRoute.indexedStack` branch Navigator) via a `NavigatorObserver` registered in the go_router observer list. The dispatcher SHALL pop the tracked modal on its owning Navigator, regardless of which branch it was shown from.

#### Scenario: Modal shown from a shell branch
- **WHEN** a bottom sheet is shown from a widget inside a shell branch (the modal lives on that branch's Navigator) and the user presses back
- **THEN** the dispatcher pops the sheet from the branch Navigator that owns it

#### Scenario: Page routes are not intercepted
- **WHEN** the topmost route is a go_router page route (not a modal) and the user presses back
- **THEN** the dispatcher does not pop it directly and delegates to the go_router delegate so go_router's route/URL state stays consistent

### Requirement: Modal stack stays consistent

The modal tracker SHALL remove routes from its stack when they are popped or replaced by any mechanism (user swipe-dismiss, tap-outside, programmatic pop, or back button) so a stale route is never popped a second time.

#### Scenario: Swipe-dismiss keeps the stack consistent
- **WHEN** the user dismisses a bottom sheet by swiping it down or tapping the barrier
- **THEN** the tracker removes the sheet from its stack and a subsequent back press is not consumed by a stale entry
