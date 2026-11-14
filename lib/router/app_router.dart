import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/onboarding/screen_splash.dart';
import '../features/onboarding/screen_0_onboarding.dart';
import '../features/dashboard/screen_1_dashboard.dart';
import '../features/voice_entry/screen_2_voice_sheet.dart';
import '../features/dashboard/screen_12_riwayat_kas.dart';
import '../features/manual_entry/screen_3_catat_manual.dart';
import '../features/receipt_scan/screen_4_foto_struk.dart';
import '../features/receipt_scan/screen_5_ubah_rincian.dart';
import '../features/nota_wa/screen_6_buat_nota_suara.dart';
import '../features/nota_wa/screen_7_daftar_nota.dart';
import '../features/nota_wa/screen_13_detail_nota.dart';
import '../features/reports/screen_8_laporan.dart';
import '../features/account_pro/screen_9_akun_kas.dart';
import '../features/account_pro/screen_10_paket_usaha.dart';
import '../features/account_pro/screen_11_bayar_qris.dart';

CustomTransitionPage<void> _smoothPage(
  GoRouterState state,
  Widget child, {
  bool isSheetOrPush = false,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: Duration(milliseconds: isSheetOrPush ? 260 : 200),
    reverseTransitionDuration: Duration(milliseconds: isSheetOrPush ? 220 : 180),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      if (isSheetOrPush) {
        final offsetTween = Tween<Offset>(
          begin: const Offset(0, 0.045),
          end: Offset.zero,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: offsetTween.animate(curved),
            child: child,
          ),
        );
      }
      return FadeTransition(
        opacity: curved,
        child: child,
      );
    },
  );
}

final appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      pageBuilder: (context, state) =>
          _smoothPage(state, const ScreenSplash()),
    ),
    GoRoute(
      path: '/onboarding',
      pageBuilder: (context, state) =>
          _smoothPage(state, const Screen0Onboarding()),
    ),
    GoRoute(
      path: '/kas',
      pageBuilder: (context, state) =>
          _smoothPage(state, const Screen1Dashboard()),
    ),
    GoRoute(
      path: '/dashboard',
      pageBuilder: (context, state) =>
          _smoothPage(state, const Screen1Dashboard()),
    ),
    GoRoute(
      path: '/bicara',
      pageBuilder: (context, state) => _smoothPage(
        state,
        const Screen2VoiceSheet(),
        isSheetOrPush: true,
      ),
    ),
    GoRoute(
      path: '/catat-manual',
      pageBuilder: (context, state) => _smoothPage(
        state,
        const Screen3CatatManual(),
        isSheetOrPush: true,
      ),
    ),
    GoRoute(
      path: '/foto-struk',
      pageBuilder: (context, state) => _smoothPage(
        state,
        const Screen4FotoStruk(),
        isSheetOrPush: true,
      ),
    ),
    GoRoute(
      path: '/ubah-rincian',
      pageBuilder: (context, state) => _smoothPage(
        state,
        const Screen5UbahRincian(),
        isSheetOrPush: true,
      ),
    ),
    GoRoute(
      path: '/buat-nota',
      pageBuilder: (context, state) => _smoothPage(
        state,
        const Screen6BuatNotaSuara(),
        isSheetOrPush: true,
      ),
    ),
    GoRoute(
      path: '/buat-nota-suara',
      pageBuilder: (context, state) => _smoothPage(
        state,
        const Screen6BuatNotaSuara(),
        isSheetOrPush: true,
      ),
    ),
    GoRoute(
      path: '/nota',
      pageBuilder: (context, state) =>
          _smoothPage(state, const Screen7DaftarNota()),
    ),
    GoRoute(
      path: '/detail-nota',
      pageBuilder: (context, state) => _smoothPage(
        state,
        const Screen13DetailNota(),
        isSheetOrPush: true,
      ),
    ),
    GoRoute(
      path: '/laporan',
      pageBuilder: (context, state) =>
          _smoothPage(state, const Screen8Laporan()),
    ),
    GoRoute(
      path: '/akun',
      pageBuilder: (context, state) =>
          _smoothPage(state, const Screen9AkunKas()),
    ),
    GoRoute(
      path: '/paket-usaha',
      pageBuilder: (context, state) => _smoothPage(
        state,
        const Screen10PaketUsaha(),
        isSheetOrPush: true,
      ),
    ),
    GoRoute(
      path: '/bayar-qris',
      pageBuilder: (context, state) => _smoothPage(
        state,
        const Screen11BayarQris(),
        isSheetOrPush: true,
      ),
    ),
    GoRoute(
      path: '/riwayat-kas',
      pageBuilder: (context, state) => _smoothPage(
        state,
        const Screen12RiwayatKas(),
        isSheetOrPush: true,
      ),
    ),
  ],
);
