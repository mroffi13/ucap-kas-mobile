import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ucapkas_toast.dart';
import '../../core/widgets/workspace_pill.dart';
import '../../data/models/cash_transaction.dart';
import '../../state/auth_provider.dart';
import '../../state/ledger_providers.dart';

class Screen3CatatManual extends ConsumerStatefulWidget {
  const Screen3CatatManual({super.key});

  @override
  ConsumerState<Screen3CatatManual> createState() => _Screen3CatatManualState();
}

class _Screen3CatatManualState extends ConsumerState<Screen3CatatManual>
    with SingleTickerProviderStateMixin {
  bool _isKasMasuk = true;
  int _nominal = 0;
  bool _isSubmitting = false;
  late final AnimationController _modeController;
  late final Animation<double> _modeAnim;
  late final TextEditingController _nominalController;
  late final FocusNode _nominalFocusNode;
  late final TextEditingController _descController;
  late final TextEditingController _categoryController;
  String _category = 'Servis';
  String _paymentMethod = 'Tunai';

  static const List<(String, IconData)> _paymentMethods = [
    ('Tunai', Icons.payments_outlined),
    ('QRIS', Icons.qr_code_rounded),
    ('Transfer', Icons.account_balance_outlined),
  ];

  @override
  void initState() {
    super.initState();
    final isAuth = ref.read(authProvider).isAuthenticated;
    final activeCats = ref.read(activeWorkspaceProvider).quickCategories;
    if (activeCats.isNotEmpty) {
      _category = activeCats.first;
    }
    // 0.0 = Kas Masuk, 1.0 = Kas Keluar — single synchronized 60fps vsync ticker
    _modeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 0.0,
    );
    _modeAnim = CurvedAnimation(
      parent: _modeController,
      curve: Curves.fastOutSlowIn,
    );
    _nominal = isAuth ? 0 : 450000;
    _nominalController = TextEditingController(
      text: _formatNumberOnly(_nominal),
    );
    _nominalFocusNode = FocusNode();
    _descController = TextEditingController(
      text: isAuth ? '' : 'Servis AC Mobil Avanza',
    );
    _categoryController = TextEditingController(text: _category);
  }

  @override
  void dispose() {
    _modeController.dispose();
    _nominalController.dispose();
    _nominalFocusNode.dispose();
    _descController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  static String _formatNumberOnly(int value) {
    if (value <= 0) return '';
    final digits = value.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  void _updateNominalValue(int nextNominal) {
    final clamped = nextNominal.clamp(0, 999999999);
    final formatted = _formatNumberOnly(clamped);
    setState(() {
      _nominal = clamped;
      _nominalController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    });
  }

  void _onNominalTextChanged(String rawText) {
    final cleanDigits = rawText.replaceAll(RegExp(r'[^0-9]'), '');
    final parsed = int.tryParse(cleanDigits) ?? 0;
    setState(() {
      _nominal = parsed;
    });
  }

  void _switchTransactionType(bool kasMasuk) {
    if (_isKasMasuk == kasMasuk) return;
    HapticFeedback.lightImpact();
    setState(() {
      _isKasMasuk = kasMasuk;
    });
    if (kasMasuk) {
      _modeController.reverse();
    } else {
      _modeController.forward();
    }
  }

  Future<void> _saveTransaction({required bool stayOnPage}) async {
    if (_isSubmitting) return;
    final isAuth = ref.read(authProvider).isAuthenticated;

    if (isAuth && _nominal <= 0) {
      HapticFeedback.lightImpact();
      UcapKasToast.showInfo(
        context,
        headerLabel: 'Lengkapi Data',
        title: 'Nominal transaksi masih Rp 0',
        subtitle: 'Masukkan jumlah uang masuk atau keluar terlebih dahulu',
        badgeText: 'INFO',
      );
      _nominalFocusNode.requestFocus();
      return;
    }

    final effectiveNominal = _nominal > 0 ? _nominal : 50000;
    final titleText = _descController.text.trim().isEmpty
        ? (_isKasMasuk ? 'Pemasukan Kas' : 'Pengeluaran Kas')
        : _descController.text.trim();

    setState(() => _isSubmitting = true);

    final ok = await ref.read(transactionsProvider.notifier).addTransaction(
          CashTransaction(
            id: 'tx-${DateTime.now().millisecondsSinceEpoch}',
            title: titleText,
            category: _category,
            paymentMethod: _paymentMethod,
            timeLabel: 'Baru saja',
            dateGroup: 'Hari Ini',
            amount: _isKasMasuk ? effectiveNominal : -effectiveNominal,
          ),
        );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (!ok) {
      UcapKasToast.showInfo(
        context,
        headerLabel: 'Gagal Menyimpan',
        title: 'Catatan kas gagal disimpan ke server',
        subtitle: 'Periksa koneksi internet Anda dan coba lagi',
        badgeText: 'ERROR',
      );
      return;
    }

    if (_isKasMasuk) {
      UcapKasToast.showKasMasuk(
        context,
        title: titleText,
        amount: effectiveNominal,
        subtitle: '$_category • $_paymentMethod',
      );
    } else {
      UcapKasToast.showKasKeluar(
        context,
        title: titleText,
        amount: effectiveNominal,
        subtitle: '$_category • $_paymentMethod',
      );
    }

    if (stayOnPage) {
      _updateNominalValue(0);
      setState(() {
        _descController.clear();
      });
      _nominalFocusNode.requestFocus();
      return;
    }

    context.go('/kas');
  }

  @override
  Widget build(BuildContext context) {
    final ws = ref.watch(activeWorkspaceProvider);

    return AnimatedBuilder(
      animation: _modeAnim,
      builder: (context, _) {
        final t = _modeAnim.value;
        final accent = Color.lerp(
              AppColors.primaryTeal,
              AppColors.expenseRose,
              t,
            ) ??
            AppColors.primaryTeal;
        final softBg = Color.lerp(
              AppColors.primaryTealSoft,
              AppColors.expenseSoft,
              t,
            ) ??
            AppColors.primaryTealSoft;

        // Interpolated colors for left (Kas Masuk) and right (Kas Keluar) toggle items
        final leftTextColor = Color.lerp(
              AppColors.textPrimary,
              AppColors.textMuted,
              t,
            ) ??
            AppColors.textPrimary;
        final rightTextColor = Color.lerp(
              AppColors.textMuted,
              AppColors.textPrimary,
              t,
            ) ??
            AppColors.textMuted;
        final leftIconColor = Color.lerp(
              AppColors.incomeEmerald,
              AppColors.textMuted,
              t,
            ) ??
            AppColors.incomeEmerald;
        final rightIconColor = Color.lerp(
              AppColors.textMuted,
              AppColors.expenseRose,
              t,
            ) ??
            AppColors.textMuted;
        final leftBadgeBg = Color.lerp(
              AppColors.incomeSoft,
              Colors.transparent,
              t,
            ) ??
            Colors.transparent;
        final rightBadgeBg = Color.lerp(
              Colors.transparent,
              AppColors.expenseSoft,
              t,
            ) ??
            Colors.transparent;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.background,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: AppColors.textPrimary,
              ),
              onPressed: () => context.pop(),
            ),
            titleSpacing: 0,
            title: Text(
              'Catat Kas',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
                color: AppColors.textPrimary,
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 18),
                child: Center(
                  child: WorkspacePill(
                    label: ws.shortName,
                    onTap: () => context.go('/akun'),
                  ),
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Single-Ticker 60fps Sliding Segmented Toggle (Tap or Drag)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final trackWidth = constraints.maxWidth - 8;
                    return GestureDetector(
                      onHorizontalDragUpdate: (details) {
                        if (trackWidth <= 0) return;
                        final nextVal = (_modeController.value +
                                (details.primaryDelta ?? 0) /
                                    (trackWidth * 0.5))
                            .clamp(0.0, 1.0);
                        _modeController.value = nextVal;
                      },
                      onHorizontalDragEnd: (details) {
                        final vx = details.primaryVelocity ?? 0;
                        final goToKeluar =
                            vx > 180 || (vx >= -180 && _modeController.value >= 0.5);
                        setState(() {
                          _isKasMasuk = !goToKeluar;
                        });
                        if (goToKeluar) {
                          _modeController.forward();
                        } else {
                          _modeController.reverse();
                        }
                      },
                      child: Container(
                        height: 50,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Stack(
                          children: [
                            // Sliding Active Pill Thumb driven by single vsync ticker `t`
                            Align(
                              alignment: Alignment(t * 2.0 - 1.0, 0.0),
                              child: FractionallySizedBox(
                                widthFactor: 0.5,
                                heightFactor: 1.0,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: accent.withValues(alpha: 0.22),
                                      width: 1,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x120B1220),
                                        blurRadius: 10,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // Foreground Tap Targets
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => _switchTransactionType(true),
                                    child: Center(
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 22,
                                            height: 22,
                                            decoration: BoxDecoration(
                                              color: leftBadgeBg,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.south_west_rounded,
                                              size: 13,
                                              color: leftIconColor,
                                            ),
                                          ),
                                          const SizedBox(width: 7),
                                          Text(
                                            'Kas Masuk',
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight: t < 0.5
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              color: leftTextColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => _switchTransactionType(false),
                                    child: Center(
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 22,
                                            height: 22,
                                            decoration: BoxDecoration(
                                              color: rightBadgeBg,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.north_east_rounded,
                                              size: 13,
                                              color: rightIconColor,
                                            ),
                                          ),
                                          const SizedBox(width: 7),
                                          Text(
                                            'Kas Keluar',
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight: t >= 0.5
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              color: rightTextColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),

                // 2. Interactive Editable Nominal Stage Card
                GestureDetector(
                  onTap: () => _nominalFocusNode.requestFocus(),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.28),
                        width: 1.2,
                      ),
                      boxShadow: AppColors.cardShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Row inside Nominal Stage
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: accent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  Flexible(
                                    child: Text(
                                      _isKasMasuk
                                          ? 'Jumlah Uang Masuk'
                                          : 'Jumlah Uang Keluar',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => context.push('/bicara'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: softBg,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.mic_none_rounded,
                                      size: 14,
                                      color: accent,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Isi pakai suara',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: accent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Editable Big Nominal Field
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                _isKasMasuk ? '+ Rp' : '- Rp',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: accent,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  key: const Key('input_nominal_kas'),
                                  controller: _nominalController,
                                  focusNode: _nominalFocusNode,
                                  keyboardType: TextInputType.number,
                                  textInputAction: TextInputAction.done,
                                  cursorColor: accent,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    _ThousandsSeparatorInputFormatter(),
                                  ],
                                  onChanged: _onNominalTextChanged,
                                  style: AppTheme.numStyle(
                                    fontSize: 30,
                                    color: AppColors.textPrimary,
                                    letterSpacing: -0.8,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: '0',
                                    hintStyle: AppTheme.numStyle(
                                      fontSize: 30,
                                      color: AppColors.borderStrong,
                                      letterSpacing: -0.8,
                                    ),
                                    isDense: true,
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 6,
                                    ),
                                  ),
                                ),
                              ),
                              if (_nominal > 0)
                                IconButton(
                                  onPressed: () {
                                    _updateNominalValue(0);
                                    _nominalFocusNode.requestFocus();
                                  },
                                  visualDensity: VisualDensity.compact,
                                  tooltip: 'Kosongkan nominal',
                                  icon: const Icon(
                                    Icons.cancel_rounded,
                                    size: 19,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Quick Increment Chips
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildQuickNominalPill(
                                '+10 rb',
                                () => _updateNominalValue(_nominal + 10000),
                              ),
                              const SizedBox(width: 8),
                              _buildQuickNominalPill(
                                '+25 rb',
                                () => _updateNominalValue(_nominal + 25000),
                              ),
                              const SizedBox(width: 8),
                              _buildQuickNominalPill(
                                '+50 rb',
                                () => _updateNominalValue(_nominal + 50000),
                              ),
                              const SizedBox(width: 8),
                              _buildQuickNominalPill(
                                '+100 rb',
                                () => _updateNominalValue(_nominal + 100000),
                              ),
                              const SizedBox(width: 8),
                              _buildQuickNominalPill(
                                '450 rb',
                                () => _updateNominalValue(450000),
                                isHighlighted: _nominal == 450000,
                                accent: accent,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 3. Integrated Details Card (Keperluan, Kategori & Cara Bayar)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                    boxShadow: AppColors.cardShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              'Untuk keperluan apa?',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Hari ini, 14:30',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _descController,
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(
                            Icons.notes_rounded,
                            size: 18,
                            color: AppColors.textMuted,
                          ),
                          hintText: 'Tulis catatan (misal: Servis AC Avanza)',
                          hintStyle: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.textMuted,
                          ),
                          filled: true,
                          fillColor: AppColors.background,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: accent, width: 1.2),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Divider(height: 1, color: AppColors.border),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Kategori',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: GestureDetector(
                              onTap: () => context.go('/akun'),
                              child: Text(
                                'Pilih cepat (3) · Atur di Akun',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryTeal,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        key: const Key('input_kategori_kas'),
                        controller: _categoryController,
                        onChanged: (val) {
                          setState(() {
                            _category = val.trim().isEmpty ? 'Lainnya' : val.trim();
                          });
                        },
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          prefixIcon: Icon(
                            Icons.label_outline_rounded,
                            size: 17,
                            color: accent,
                          ),
                          hintText: 'Ketik kategori atau pilih 3 di bawah',
                          hintStyle: GoogleFonts.inter(
                            fontSize: 12.5,
                            color: AppColors.textMuted,
                          ),
                          isDense: true,
                          filled: true,
                          fillColor: AppColors.background,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 11,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(11),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(11),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(11),
                            borderSide: BorderSide(color: accent, width: 1.2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Builder(
                        builder: (_) {
                          final quickCats =
                              ws.quickCategories.take(3).toList();
                          return Row(
                            children: [
                              for (int i = 0; i < quickCats.length; i++) ...[
                                if (i > 0) const SizedBox(width: 8),
                                Expanded(
                                  child: Builder(
                                    builder: (_) {
                                      final catLabel = quickCats[i];
                                      final selected =
                                          _category.toLowerCase() ==
                                              catLabel.toLowerCase();
                                      return GestureDetector(
                                        key: ValueKey(
                                          'quick_category_chip_$i',
                                        ),
                                        onTap: () {
                                          HapticFeedback.selectionClick();
                                          setState(() {
                                            _category = catLabel;
                                            _categoryController.value =
                                                TextEditingValue(
                                              text: catLabel,
                                              selection:
                                                  TextSelection.collapsed(
                                                offset: catLabel.length,
                                              ),
                                            );
                                          });
                                        },
                                        child: AnimatedContainer(
                                          duration:
                                              const Duration(milliseconds: 180),
                                          curve: Curves.easeOutCubic,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            color: selected
                                                ? AppColors.heroDark
                                                : AppColors.background,
                                            borderRadius:
                                                BorderRadius.circular(11),
                                            border: Border.all(
                                              color: selected
                                                  ? AppColors.heroDark
                                                  : AppColors.border,
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              catLabel,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
                                              style: GoogleFonts.inter(
                                                fontSize: 11.5,
                                                fontWeight: selected
                                                    ? FontWeight.w600
                                                    : FontWeight.w500,
                                                color: selected
                                                    ? Colors.white
                                                    : AppColors.textSecondary,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Cara Bayar',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          for (int i = 0; i < _paymentMethods.length; i++) ...[
                            if (i > 0) const SizedBox(width: 8),
                            Expanded(
                              child: _buildPaymentTile(
                                label: _paymentMethods[i].$1,
                                icon: _paymentMethods[i].$2,
                                selected:
                                    _paymentMethod == _paymentMethods[i].$1,
                                accent: accent,
                                softBg: softBg,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(
                                    () =>
                                        _paymentMethod = _paymentMethods[i].$1,
                                  );
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: OutlinedButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => _saveTransaction(stayOnPage: true),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.borderStrong),
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Catat Lagi',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: ElevatedButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => _saveTransaction(stayOnPage: false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _isSubmitting
                            ? 'Menyimpan...'
                            : (_isKasMasuk
                                ? 'Simpan Kas Masuk'
                                : 'Simpan Kas Keluar'),
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickNominalPill(
    String label,
    VoidCallback onTap, {
    bool isHighlighted = false,
    Color? accent,
  }) {
    final activeColor = accent ?? AppColors.primaryTeal;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isHighlighted
              ? activeColor.withValues(alpha: 0.1)
              : AppColors.background,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: isHighlighted ? activeColor : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: isHighlighted ? activeColor : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentTile({
    required String label,
    required IconData icon,
    required bool selected,
    required Color accent,
    required Color softBg,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? softBg : AppColors.background,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: selected ? accent : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: selected ? accent : AppColors.textMuted,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? accent : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }
    final limited =
        digitsOnly.length > 9 ? digitsOnly.substring(0, 9) : digitsOnly;
    final parsed = int.tryParse(limited) ?? 0;
    if (parsed == 0) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final buffer = StringBuffer();
    final str = parsed.toString();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(str[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
