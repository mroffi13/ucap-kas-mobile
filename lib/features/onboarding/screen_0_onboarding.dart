import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ucapkas_logo.dart';
import '../../state/ledger_providers.dart';

class _LedgerSpecimen {
  final String label;
  final IconData icon;
  final int workspaceIndex;
  final String voiceTag;
  final String spokenLine;
  final String entryTitle;
  final String entryCategory;
  final String paymentMethod;
  final String amountText;
  final bool isIncome;
  final List<double> waveHeights;

  const _LedgerSpecimen({
    required this.label,
    required this.icon,
    required this.workspaceIndex,
    required this.voiceTag,
    required this.spokenLine,
    required this.entryTitle,
    required this.entryCategory,
    required this.paymentMethod,
    required this.amountText,
    required this.isIncome,
    required this.waveHeights,
  });
}

class Screen0Onboarding extends ConsumerStatefulWidget {
  const Screen0Onboarding({super.key});

  @override
  ConsumerState<Screen0Onboarding> createState() => _Screen0OnboardingState();
}

class _Screen0OnboardingState extends ConsumerState<Screen0Onboarding>
    with TickerProviderStateMixin {
  static const List<_LedgerSpecimen> _specimens = [
    _LedgerSpecimen(
      label: 'UMKM / Jasa',
      icon: Icons.storefront_outlined,
      workspaceIndex: 0,
      voiceTag: '0:05',
      spokenLine: '"Catat servis AC Avanza 450 ribu tunai dari Pak Joko"',
      entryTitle: 'Servis AC Mobil Avanza',
      entryCategory: 'Jasa Servis • Pak Joko',
      paymentMethod: 'Nota WA siap kirim',
      amountText: '+Rp 450.000',
      isIncome: true,
      waveHeights: [
        0.32, 0.68, 0.96, 0.54, 0.82, 1.0, 0.62, 0.44, 0.88, 0.72, 0.48, 0.34,
        0.64, 0.42
      ],
    ),
    _LedgerSpecimen(
      label: 'Rumah Tangga',
      icon: Icons.home_outlined,
      workspaceIndex: 1,
      voiceTag: '0:04',
      spokenLine: '"Beli beras 5 kilo 75 ribu sama telor sekilo 28 ribu"',
      entryTitle: 'Beras 5kg & Telur Ayam 1kg',
      entryCategory: 'Belanja Dapur • Pasar',
      paymentMethod: '2 barang tercatat',
      amountText: '-Rp 103.000',
      isIncome: false,
      waveHeights: [
        0.38, 0.76, 0.52, 0.92, 0.64, 0.46, 0.96, 0.78, 0.56, 0.84, 0.50, 0.36,
        0.58, 0.38
      ],
    ),
    _LedgerSpecimen(
      label: 'Komunitas',
      icon: Icons.groups_outlined,
      workspaceIndex: 0,
      voiceTag: '0:05',
      spokenLine: '"Iuran kas warga RT 12 bulan November masuk 600 ribu"',
      entryTitle: 'Iuran Kas Warga RT 12',
      entryCategory: 'Iuran Bulanan • Bendahara',
      paymentMethod: 'Kwitansi WA siap',
      amountText: '+Rp 600.000',
      isIncome: true,
      waveHeights: [
        0.30, 0.56, 0.86, 0.72, 0.94, 0.60, 0.76, 1.0, 0.66, 0.52, 0.72, 0.42,
        0.60, 0.35
      ],
    ),
  ];

  // Tinted colored shadows matching the Nordic Slate-Teal palette (no generic black box-shadow)
  static const List<BoxShadow> _tintedStageShadow = [
    BoxShadow(
      color: Color(0x140D9488),
      blurRadius: 28,
      offset: Offset(0, 12),
    ),
    BoxShadow(
      color: Color(0x0A0B1220),
      blurRadius: 10,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> _tintedPrimaryCtaShadow = [
    BoxShadow(
      color: Color(0x2E0D9488),
      blurRadius: 20,
      offset: Offset(0, 8),
    ),
  ];

  int _selectedIndex = 0;
  late final AnimationController _entranceController;
  late final AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _entranceController.forward();
      _waveController.forward(from: 0);
    });
  }

  @override
  void reassemble() {
    super.reassemble();
    _entranceController.value = 1.0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.go('/splash');
      }
    });
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  void _selectSpecimen(int index) {
    if (_selectedIndex == index) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedIndex = index;
    });
    _waveController.forward(from: 0);
  }

  void _loginAndContinue() {
    final workspaces = ref.read(workspacesProvider);
    final specimen = _specimens[_selectedIndex];
    final targetIdx = specimen.workspaceIndex.clamp(0, workspaces.length - 1);
    ref.read(activeWorkspaceIndexProvider.notifier).state = targetIdx;
    context.go('/kas');
  }

  Widget _buildStaggeredStage({
    required double start,
    required double end,
    required bool reduceMotion,
    required Widget child,
  }) {
    if (reduceMotion) return child;
    return AnimatedBuilder(
      animation: _entranceController,
      builder: (context, _) {
        final curve = CurvedAnimation(
          parent: _entranceController,
          curve: Interval(start, end, curve: Curves.easeOutCubic),
        ).value;
        return Opacity(
          opacity: curve,
          child: Transform.translate(
            offset: Offset(0, (1 - curve) * 14),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final specimen = _specimens[_selectedIndex];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Padding(
                    // Optical vertical padding: slightly deeper bottom padding for visual balance
                    padding: const EdgeInsets.fromLTRB(22, 14, 22, 26),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Stage 1: Brand Bar & Package Link
                        _buildStaggeredStage(
                          start: 0.0,
                          end: 0.55,
                          reduceMotion: reduceMotion,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _TactilePressable(
                                semanticLabel: 'UcapKas',
                                onTap: () => context.go('/splash'),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 4),
                                  child: UcapKasLogo(
                                    size: 30,
                                    showWordmark: true,
                                  ),
                                ),
                              ),
                              _TactilePressable(
                                semanticLabel: 'Lihat paket usaha',
                                onTap: () => context.push('/paket-usaha'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: AppColors.border,
                                    ),
                                  ),
                                  child: Text(
                                    'Lihat paket',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Stage 2: Editorial Sentence-Case Display Headline & Subtext
                        _buildStaggeredStage(
                          start: 0.10,
                          end: 0.68,
                          reduceMotion: reduceMotion,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Catat kas dan kirim nota\ncukup bicara 5 detik.',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.9,
                                  color: AppColors.textPrimary,
                                  height: 1.14,
                                ),
                              ),
                              const SizedBox(height: 10),
                              ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 365),
                                child: Text(
                                  'Pisahkan uang dapur dan modal usaha lewat suara sehari-hari, langsung rapi tanpa ketik manual.',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 22),

                        // Stage 3: Tonal Segmented Switcher + Layered Voice-to-Receipt Artifact
                        Expanded(
                          child: _buildStaggeredStage(
                            start: 0.22,
                            end: 0.84,
                            reduceMotion: reduceMotion,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Recessed Tonal Segmented Track
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8EEF5),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Row(
                                    children: [
                                      for (int i = 0;
                                          i < _specimens.length;
                                          i++)
                                        _buildSegmentPill(
                                          specimen: _specimens[i],
                                          selected: _selectedIndex == i,
                                          reduceMotion: reduceMotion,
                                          onTap: () => _selectSpecimen(i),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // Cohesive Tonal Layered Stage (No sudden #000 black box jump on a light page)
                                _TactilePressable(
                                  key: const Key('card_onboarding_voice_demo'),
                                  semanticLabel: 'Coba simulasi suara',
                                  onTap: () => context.push('/bicara'),
                                  child: _buildLayeredTonalVoiceStage(
                                    specimen: specimen,
                                    reduceMotion: reduceMotion,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Stage 4: Brand-Tinted Primary CTA + Tonal Secondary CTA + Skip/Legal Row
                        _buildStaggeredStage(
                          start: 0.34,
                          end: 1.0,
                          reduceMotion: reduceMotion,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Primary CTA: Desaturated Deep Teal with Tinted Hue Shadow
                              _TactilePressable(
                                key: const Key('btn_login_google'),
                                semanticLabel: 'Masuk Lewat Google',
                                onTap: _loginAndContinue,
                                child: Container(
                                  constraints:
                                      const BoxConstraints(minHeight: 52),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 13,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryTeal,
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: _tintedPrimaryCtaShadow,
                                    border: Border.all(
                                      color: const Color(0x26FFFFFF),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 26,
                                        height: 26,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(7),
                                        ),
                                        child: Text(
                                          'G',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.primaryTeal,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'Masuk Lewat Google',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: -0.1,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      const Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Tertiary Skip & Legal Row (Strategic Omissions fixed)
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Privasi & Ketentuan Layanan',
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                  _TactilePressable(
                                    key: const Key('btn_skip_onboarding'),
                                    semanticLabel: 'Lewati dan coba dulu',
                                    onTap: _loginAndContinue,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 4,
                                        horizontal: 2,
                                      ),
                                      child: Text(
                                        'Lewati, coba dulu →',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primaryTeal,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentPill({
    required _LedgerSpecimen specimen,
    required bool selected,
    required bool reduceMotion,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: _TactilePressable(
        semanticLabel: specimen.label,
        selected: selected,
        onTap: onTap,
        child: AnimatedContainer(
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected ? AppColors.cardShadow : const [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                specimen.icon,
                size: 14,
                color: selected ? AppColors.primaryTeal : AppColors.textMuted,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  specimen.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Cohesive Tonal Layered Stage:
  /// Uses a tinted cool-teal recessed upper chamber (#E6F1F1) paired with an overlapping
  /// elevated white receipt card (#FFFFFF) with varied border radii (20px outer -> 14px card -> 6px tag)
  /// and teal-tinted shadows — zero jarring dark-mode block in the middle of a light page.
  Widget _buildLayeredTonalVoiceStage({
    required _LedgerSpecimen specimen,
    required bool reduceMotion,
  }) {
    final amountColor =
        specimen.isIncome ? AppColors.incomeEmerald : AppColors.expenseRose;
    final amountBg =
        specimen.isIncome ? AppColors.incomeSoft : AppColors.expenseSoft;

    return AnimatedSwitcher(
      duration:
          reduceMotion ? Duration.zero : const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: Column(
        key: ValueKey<String>(specimen.label),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Upper Tonal Acoustic Chamber (20px top radius)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFE6F4F1),
                  Color(0xFFE8EEF6),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
                bottom: Radius.circular(12),
              ),
              border: Border.all(
                color: const Color(0xFFD0E4E0),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: AppColors.primaryTeal,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.mic_none_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AnimatedBuilder(
                        animation: _waveController,
                        builder: (context, _) {
                          final t = reduceMotion ? 1.0 : _waveController.value;
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              for (int i = 0;
                                  i < specimen.waveHeights.length;
                                  i++) ...[
                                if (i > 0) const SizedBox(width: 3.5),
                                _buildWaveBar(
                                  targetFactor: specimen.waveHeights[i],
                                  progress: t,
                                  index: i,
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      specimen.voiceTag,
                      style: AppTheme.numStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryTeal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  specimen.spokenLine,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    height: 1.36,
                  ),
                ),
              ],
            ),
          ),

          // Overlapping Lower Paper Receipt Card (-12px negative offset via Transform.translate for depth)
          Transform.translate(
            offset: const Offset(0, -12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white,
                    width: 1.5,
                  ),
                  boxShadow: _tintedStageShadow,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 3.5,
                      height: 38,
                      decoration: BoxDecoration(
                        color: amountColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            specimen.entryTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            specimen.entryCategory,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          specimen.amountText,
                          style: AppTheme.numStyle(
                            fontSize: 15,
                            color: amountColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: amountBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            specimen.paymentMethod,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: amountColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaveBar({
    required double targetFactor,
    required double progress,
    required int index,
  }) {
    final wavePulse = math.sin((progress * math.pi) + (index * 0.45)).abs();
    final factor =
        (targetFactor * (0.45 + 0.55 * progress) * (0.75 + 0.25 * wavePulse))
            .clamp(0.22, 1.0);
    final isHighlight = index == 2 || index == 5 || index == 8;

    return Container(
      width: 3,
      height: 20 * factor,
      decoration: BoxDecoration(
        color: isHighlight
            ? AppColors.primaryTeal
            : const Color(0xFF94B8B5),
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}

/// Physical press feedback wrapper (`scale(0.98)` + `translateY(1px)`) per `/redesign-existing-projects`
class _TactilePressable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final String semanticLabel;
  final bool? selected;

  const _TactilePressable({
    super.key,
    required this.child,
    required this.onTap,
    required this.semanticLabel,
    this.selected,
  });

  @override
  State<_TactilePressable> createState() => _TactilePressableState();
}

class _TactilePressableState extends State<_TactilePressable> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: (!reduceMotion && _pressed) ? 0.98 : 1.0,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOutCubic,
          child: AnimatedSlide(
            offset: (!reduceMotion && _pressed)
                ? const Offset(0, 0.015)
                : Offset.zero,
            duration: const Duration(milliseconds: 110),
            curve: Curves.easeOutCubic,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
