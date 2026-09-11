# Changelog

All notable changes to this app are documented here.

## 1.2.3+11 — 2026-09-10

### Fixed
- **Google Play compliance:** app now targets Android 16 (API 36), resolving
  the "target API level" warning.
- **Google Play compliance:** native libraries are now packaged uncompressed
  and 16 KB-page-aligned (`useLegacyPackaging = false`, NDK r27), resolving
  the "16 KB memory page size" warning.

## 1.2.2+10 — 2026-09-10

### Added
- Direct WhatsApp sharing for invitations (send image + caption straight to
  a guest's WhatsApp chat) via a native method channel and `FileProvider`.
- New `lib/models` (event, invitee, SMS template) and `lib/widgets`
  (filter bar, actions toolbar, invitation upload card, invitee card,
  invitation selection tools) to support the invitee management screen.
- `lib/config/app_config.dart` for centralized app configuration.

### Changed
- Upgraded `mobile_scanner` from 3.5.1 to 7.2.0.
- Refactored invitee management, event screen, scan screen, and the
  customize-invitation screen to use the new models/widgets.

### Removed
- Unused `lib/scan_screen_new.dart`.
