# Development Guide

## Workspace

BovaPlayer is currently centered on the Flutter application in `ui/flutter_app`.

Primary areas:

- `ui/flutter_app/lib/core/` shared theme, shell, reusable widgets
- `ui/flutter_app/lib/features/` feature modules such as auth, discover, media library
- `ui/flutter_app/lib/player_window/` desktop window bootstrapping
- `.github/workflows/build.yml` CI builds and release packaging
- `scripts/` local helper scripts

## Environment

Copy `ui/flutter_app/.env.example` to `ui/flutter_app/.env` and fill the values you actually use.

Common keys:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `TMDB_READ_ACCESS_TOKEN` or `TMDB_API_KEY`
- `GITHUB_CLIENT_ID`
- `GITHUB_REDIRECT_URI`

## Local Run

macOS:

```bash
./scripts/run_macos.sh
```

Android:

```bash
cd ui/flutter_app
flutter run -d <device-id>
```

Windows:

```bash
cd ui/flutter_app
flutter run -d windows
```

## Local Build

Use the unified local build script:

```bash
./scripts/build_local.sh macos
./scripts/build_local.sh android
./scripts/build_local.sh windows
```

Notes:

- `windows` builds must run on Windows.
- `macos` builds must run on macOS.
- Android builds require Flutter + Android SDK.

## Quality Checks

```bash
cd ui/flutter_app
dart format lib
flutter analyze
```

## Release Flow

Normal release flow:

1. Commit the release-ready changes.
2. Create or move a version tag like `v0.6.0`.
3. Push `main` and the tag.
4. GitHub Actions builds Windows, macOS and Android artifacts and publishes the release.

Platform filtering is controlled by the tag suffix rules already implemented in `.github/workflows/build.yml`.

Examples:

```bash
git tag v0.6.0
git push origin v0.6.0
```

```bash
git tag v0.6.0-android
git push origin v0.6.0-android
```

## Useful Scripts

- `scripts/build_local.sh` local build entry point
- `scripts/run_macos.sh` quick macOS run helper
- `scripts/update_icons.sh` regenerate launcher icons
- `scripts/verify_android_smb.sh` Android SMB integration sanity check
