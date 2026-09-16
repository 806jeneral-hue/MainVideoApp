# Main Video

A local video player for Android, built with Flutter. No login, no backend, no
network: it reads the videos already on the device and keeps playlists,
favourites, watch history and settings in a local database.

Built from the phase plan in `../mark down/` (phases 1–8; phase 9 is deliberately
not implemented).

## Running it

```bash
flutter run
```

```bash
flutter build apk --release
```

The first launch asks for media access. Renaming or deleting a file asks for
"All files access" separately, and only at the moment you try it.

## How the code is laid out

```
lib/
  core/            theme and formatting helpers
  data/
    models/        Video, VideoFolder, Playlist, WatchRecord, enums
    local/         Hive boxes and every settings key
    repositories/  typed access to settings, favourites, history, playlists
    services/      permissions, media scan, thumbnails, file ops, PiP channel
  state/           LibraryController, SettingsController, PlayerController
  ui/
    shell/         bottom navigation
    home/          home screen, list/grid tiles, sort sheet
    folders/       folders + playlists, collection screen, video picker
    favorites/     favourites tab
    player/        player screen, gestures, controls, sheets
    settings/      playback settings, app settings, scan folders, about
    video/         actions sheet and video info
```

Choices worth knowing:

- **State**: `provider` with `ChangeNotifier`. `LibraryController` is the single
  source of truth for the library; `PlayerController` is created per visit to
  the player and disposed with it.
- **Database**: Hive storing only primitives and plain maps, so there are no
  generated adapters and no `build_runner` step.
- **Video identity** is the absolute file path, not the MediaStore id, so
  favourites, history and playlists survive a rescan. Renaming a file re-keys
  all three.
- **Scanning** reads the single "all videos" album and groups by real directory,
  rather than reading one album and missing the rest.
- **PiP** has no Flutter API, so `MainActivity` exposes `isPipSupported` /
  `enterPip` over the `main_video/pip` channel and reports PiP changes back.

## Feature map

| Phase | Where |
| --- | --- |
| 1 — setup & data layer | `data/` |
| 2 — home & navigation | `ui/home/`, `ui/shell/` |
| 3 — folders & playlists | `ui/folders/`, `ui/settings/scan_folders_page.dart` |
| 4 — player | `ui/player/`, `state/player_controller.dart` |
| 5 — playback settings | `ui/settings/playback_settings_page.dart` |
| 6 — video management | `ui/video/`, `ui/favorites/` |
| 7 — app settings | `ui/settings/app_settings_page.dart` |
| 8 — visual design | `core/theme/app_theme.dart` |
| 9 — advanced | not built, by design |

## Tests

```bash
flutter test
```

Covers the pure logic — formatting, models, storage round-trips. Anything that
needs MediaStore or a real player is left to on-device testing.

## Android notes

- `compileSdk` is pinned to 37 because `permission_handler_android` requires it.
- Permissions: `READ_MEDIA_VIDEO` (Android 13+), `READ_EXTERNAL_STORAGE`
  (≤ Android 12), `MANAGE_EXTERNAL_STORAGE` (rename/delete only), `WAKE_LOCK`.
