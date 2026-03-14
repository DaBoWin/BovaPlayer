import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'dart:io' show Platform;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:window_manager/window_manager.dart';
import 'package:provider/provider.dart';
import 'native_bridge.dart';

// i18n
import 'l10n/generated/app_localizations.dart';

// 云同步功能
import 'core/config/env_config.dart';
import 'core/providers/locale_provider.dart';
import 'core/providers/theme_provider.dart';
import 'features/auth/domain/services/auth_service.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/presentation/providers/auth_provider.dart'
    as auth_provider;
import 'features/auth/presentation/pages/login_page_redesign.dart';
import 'features/auth/presentation/pages/register_page.dart';
import 'features/auth/presentation/pages/forgot_password_page.dart';
import 'features/auth/presentation/pages/account_page.dart';

// 新的设计系统
import 'core/theme/app_theme.dart';
import 'core/widgets/main_navigation.dart';
import 'player_window/desktop_player_window.dart';
import 'player_window/window_focus_bridge.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  AppWindowArguments currentWindow = AppWindowArguments.main();
  DesktopPlayerPayload? playerPayload;
  final isDesktop =
      !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

  if (isDesktop) {
    try {
      final controller = await WindowController.fromCurrentEngine();
      currentWindow = AppWindowArguments.tryParse(controller.arguments) ??
          AppWindowArguments.main();
      print(
        '[Main] current desktop window id=${controller.windowId} '
        'type=${currentWindow.type}',
      );
      if (currentWindow.type == kPlayerAppWindowType &&
          currentWindow.payload != null) {
        playerPayload = DesktopPlayerPayload.fromJson(currentWindow.payload!);
      }
    } catch (e) {
      print('[Main] 读取窗口参数失败: $e');
    }
  }

  try {
    await dotenv.load(fileName: '.env');
    print('[Main] 环境变量加载成功');
  } catch (e) {
    print('[Main] 环境变量加载失败: $e');
  }

  try {
    await Supabase.initialize(
      url: EnvConfig.supabaseUrl,
      anonKey: EnvConfig.supabaseAnonKey,
      debug: EnvConfig.supabaseDebug,
    );
    print('[Main] Supabase 初始化成功');
    print('[Main] Supabase URL: ${EnvConfig.supabaseUrl}');
  } catch (e) {
    print('[Main] Supabase 初始化失败: $e');
  }

  MediaKit.ensureInitialized();
  print('[Main] media_kit 已初始化');

  try {
    final result = await NativeBridge.initialize();
    print('[Main] Native bridge initialized: $result');
  } catch (error) {
    print('[Main] Failed to initialize native library: $error');
  }

  if (isDesktop) {
    await windowManager.ensureInitialized();
    await windowManager.setIgnoreMouseEvents(false);
    final windowOptions = playerPayload != null
        ? playerWindowOptions(playerPayload)
        : mainWindowOptions();
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      if (playerPayload != null) {
        await windowManager.setResizable(false);
        await windowManager.setMaximizable(false);
      }
      await windowManager.show();
      await windowManager.focus();
    });
  }

  if (isDesktop && playerPayload == null) {
    print('[Main] registering main window focus channel');
    await registerMainWindowChannel();
    onWindowsChanged.listen((_) async {
      final windows = await WindowController.getAll();
      final summary = windows
          .map((window) {
            final parsed = AppWindowArguments.tryParse(window.arguments);
            return '${window.windowId}:${parsed?.type ?? 'unknown'}';
          })
          .join(', ');
      print('[Main] windows changed -> count=${windows.length} [$summary]');
      if (windows.length == 1) {
        await ensureMainWindowInteractive('windows changed immediate');
        Future<void>.delayed(const Duration(milliseconds: 80), () async {
          await ensureMainWindowInteractive('windows changed delayed(80ms)');
        });
        Future<void>.delayed(const Duration(milliseconds: 220), () async {
          await ensureMainWindowInteractive('windows changed delayed(220ms)');
        });
      }
    });
  }

  if (playerPayload != null) {
    runApp(DesktopPlayerWindowApp(payload: playerPayload));
    return;
  }

  runApp(const BovaPlayerApp());
}

class BovaPlayerApp extends StatelessWidget {
  const BovaPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authRepository = AuthRepositoryImpl();
    final authService = AuthService(authRepository);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => auth_provider.AuthProvider(authService),
        ),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer3<ThemeProvider, LocaleProvider, auth_provider.AuthProvider>(
        builder: (context, themeProvider, localeProvider, authProvider, _) {
          final hasProAccess = authProvider.user?.isPro ?? false;
          final authReady = authProvider.state != auth_provider.AuthState.initial &&
              authProvider.state != auth_provider.AuthState.loading;
          if (authReady &&
              ThemeProvider.isProTheme(themeProvider.themeMode) &&
              !hasProAccess) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              themeProvider.ensureThemeAccess(hasProAccess: hasProAccess);
            });
          }

          final themeData = AppTheme.themeFor(themeProvider.themeMode);
          return MaterialApp(
            title: 'BovaPlayer',
            debugShowCheckedModeBanner: false,
            theme: themeData,
            locale: localeProvider.locale,
            localizationsDelegates: S.localizationsDelegates,
            supportedLocales: S.supportedLocales,
            home: const AuthWrapper(),
            routes: {
              '/login': (context) => const LoginPageRedesign(),
              '/register': (context) => const RegisterPage(),
              '/forgot-password': (context) => const ForgotPasswordPage(),
              '/account': (context) => const AccountPage(),
              '/main': (context) => const MainNavigation(),
            },
          );
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<auth_provider.AuthProvider>(
      builder: (context, authProvider, _) {
        if (authProvider.state == auth_provider.AuthState.initial ||
            authProvider.state == auth_provider.AuthState.loading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (authProvider.isAuthenticated) {
          return const MainNavigation();
        }

        return const LoginPageRedesign();
      },
    );
  }
}
