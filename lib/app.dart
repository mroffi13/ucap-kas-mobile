import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'router/app_router.dart';

class UcapKasApp extends StatelessWidget {
  const UcapKasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'UcapKas',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.light,
      routerConfig: appRouter,
      builder: (context, child) => _HotReloadSplashRedirector(
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}

class _HotReloadSplashRedirector extends StatefulWidget {
  final Widget child;
  const _HotReloadSplashRedirector({required this.child});

  @override
  State<_HotReloadSplashRedirector> createState() =>
      _HotReloadSplashRedirectorState();
}

class _HotReloadSplashRedirectorState extends State<_HotReloadSplashRedirector> {
  static bool _didRedirectOnFirstMount = false;

  @override
  void initState() {
    super.initState();
    if (!_didRedirectOnFirstMount) {
      _didRedirectOnFirstMount = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        appRouter.go('/splash');
      });
    }
  }

  @override
  void reassemble() {
    super.reassemble();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      appRouter.go('/splash');
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
