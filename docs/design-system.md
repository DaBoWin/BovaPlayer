# Design System

## Intent

BovaPlayer uses one visual language across desktop and mobile, while keeping navigation and interaction patterns platform-appropriate.

Principles:

- content first
- soft light surfaces instead of heavy glassmorphism
- clear hierarchy and dense but readable media layouts
- desktop and mobile share brand language, not identical structure

## Shell Strategy

- Android and iOS use the mobile shell
- Windows, macOS and Linux use the desktop shell
- screen size adjusts density and grid count, not the entire interaction model

Key shell files:

- `ui/flutter_app/lib/core/widgets/main_navigation.dart`
- `ui/flutter_app/lib/core/widgets/shell_top_bar.dart`
- `ui/flutter_app/lib/core/widgets/bova_bottom_nav.dart`
- `ui/flutter_app/lib/core/theme/design_system.dart`

## Tokens

Core design tokens live in:

- `ui/flutter_app/lib/core/theme/design_system.dart`
- `ui/flutter_app/lib/core/theme/app_theme.dart`
- `ui/flutter_app/lib/core/theme/bova_icons.dart`

They define:

- color palette
- spacing scale
- typography scale
- corner radius
- shadows
- motion durations and curves

## Shared Components

Reusable UI components:

- `BovaButton`
- `BovaCard`
- `BovaTextField`
- `DesktopSidebar`
- `ShellTopBar`
- `BovaBottomNav`

When adding new UI, prefer composing these before introducing ad-hoc widget styling.

## Discover and Library UI

The most visible product surfaces are:

- Discover feed in `ui/flutter_app/lib/features/discover/`
- Media library in `ui/flutter_app/lib/features/media_library/`
- Auth workspace in `ui/flutter_app/lib/features/auth/presentation/widgets/auth_workspace_shell.dart`

Guidelines:

- posters should stay readable before decorative
- quick actions should remain one tap away
- mobile cards should prioritize touch size over density
- desktop should preserve drag regions and window controls

## Icon and Branding

Launcher icon generation is handled by:

```bash
./scripts/update_icons.sh
```

Source assets live under `ui/flutter_app/assets/`.
