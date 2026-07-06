# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- The lens: hold right ⌘ (or ⌃⌥ / fn) to see a live circular peek at the
  window hidden beneath the frontmost one, streamed via ScreenCaptureKit;
  release to dismiss, click inside to raise the revealed window
- Onboarding window with a coded demo animation, Screen Recording and
  Accessibility permission flow (including the required relaunch after an
  in-session Screen Recording grant), and launch-at-login opt-in
- Menu bar presence with a permission warning state and Fix Permissions entry
- Settings window: trigger key, lens size with live quarter-scale preview,
  launch at login
- Brass lens app icon
- Initial project scaffold from [macos-app-template](https://github.com/tomada1114/macos-app-template)

[Unreleased]: https://github.com/tomada1114/spyglass/commits/main
