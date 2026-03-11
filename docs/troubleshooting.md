# Troubleshooting

## TMDB content does not load

Check `ui/flutter_app/.env` first:

- `TMDB_READ_ACCESS_TOKEN` or `TMDB_API_KEY` must exist locally

For CI builds, GitHub Actions also needs the matching repository secret. The workflow already injects it into `.env` during release builds.

## Discover page has no quick play button

Quick play depends on local media sources being available on the device.

Check:

- the device has synced or added Emby sources locally
- login was completed with email/password if sync needs to restore encrypted sources
- the source still has valid Emby credentials or can refresh them

If a device reused an old login session, log out and log in again to bootstrap sync.

## Android UI looks stale after changes

Prefer a full reinstall over hot reload when layout changes seem not to apply:

```bash
cd ui/flutter_app
flutter run -d <device-id>
```

## Windows main window has no close button

The app uses a hidden native title bar and provides custom window controls inside the desktop shell top bar. If they disappear, check:

- `ui/flutter_app/lib/core/widgets/shell_top_bar.dart`
- `ui/flutter_app/lib/player_window/desktop_player_window.dart`

## macOS playback or dylib issues

First verify the environment and build cleanly:

```bash
cd ui/flutter_app
flutter clean
flutter pub get
flutter build macos
```

If the problem is specific to SMB on Android, run:

```bash
./scripts/verify_android_smb.sh
```
