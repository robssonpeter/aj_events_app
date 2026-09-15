# Changelog

All notable changes to this app are documented here.

## 1.2.4+13 — 2026-09-12

### Added
- Contribution rounds ("mchango") in the mobile app: list and totals with
  filters and multi-select, contributor cards with a payments ledger,
  recording payments, adding contributors in bulk (paste one per line),
  and round setup (target, deadline, payment numbers, kamati contacts,
  message copy). Bulk card/reminder sending shares through the OS share
  sheet, the same path used to post a card to a WhatsApp group.
- Skeleton placeholder rows while the contributions list refetches after a
  filter or search change, so the screen doesn't look unresponsive on a
  slow connection. Only the newest request is allowed to update the list,
  closing a race where a stale response could overwrite fresher data.

### Fixed
- **Google Play compliance:** removed the broad `READ_MEDIA_IMAGES` /
  `READ_MEDIA_VIDEO` / `READ_EXTERNAL_STORAGE` permissions and the runtime
  requests for them. Picking a photo already opens the Android system photo
  picker (via `image_picker`), and saving a photo to the gallery already
  goes through `MediaStore` on Android 10+ — neither needs those
  permissions, and Play flags apps that request them anyway.
- Crash opening the contributions screen on an event with no contribution
  settings yet: an empty settings object from the API was arriving as
  `[]` instead of `{}` and was rejected outright. Empty/differently-shaped
  payloads now degrade to an empty map instead of throwing.
- Release builds no longer fail outright on a machine without the upload
  keystore (`key.properties`) — the Android signing config is now created
  only when that file is present, so debug builds work everywhere and CI
  without the keystore doesn't break.

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
