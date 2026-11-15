import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/ucapkas_logo.dart';
import '../../state/auth_provider.dart';

class ScreenSplash extends ConsumerStatefulWidget {
  const ScreenSplash({super.key});

  @override
  ConsumerState<ScreenSplash> createState() => _ScreenSplashState();
}

class _ScreenSplashState extends ConsumerState<ScreenSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _slideAnim;
  Timer? _navTimer;
  Future<bool>? _restoreFuture;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _slideAnim = Tween<double>(begin: 10, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.forward();
      _restoreFuture = ref.read(authProvider.notifier).restoreSession();
      _navTimer = Timer(const Duration(milliseconds: 6000), _finishSplash);
    });
  }

  Future<void> _finishSplash() async {
    if (!mounted) return;
    _navTimer?.cancel();
    if (_restoreFuture != null) {
      await _restoreFuture;
    }
    if (!mounted) return;
    final isAuthenticated = ref.read(authProvider).isAuthenticated;
    context.go(isAuthenticated ? '/kas' : '/onboarding');
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _finishSplash,
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnim.value,
                child: Transform.translate(
                  offset: Offset(0, _slideAnim.value),
                  child: child,
                ),
              );
            },
            child: SizedBox(
              width: double.infinity,
              child: Column(
                children: [
                  const Spacer(flex: 5),
                  const UcapKasLogo(
                    size: 72,
                    showWordmark: false,
                  ),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Ucap',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.8,
                          height: 1.1,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Kas',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.8,
                          height: 1.1,
                          color: AppColors.primaryTeal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tinggal ngomong, kas rapi.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      letterSpacing: -0.1,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(flex: 6),
                  Text(
                    'Buku Kas Usaha & Harian',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
