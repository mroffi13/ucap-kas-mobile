import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/rupiah_formatter.dart';
import '../../core/widgets/ucapkas_toast.dart';
import '../../data/models/cash_transaction.dart';
import '../../data/models/nota_invoice.dart';
import '../../state/auth_provider.dart';
import '../../state/ledger_providers.dart';

class Screen6BuatNotaSuara extends ConsumerStatefulWidget {
  const Screen6BuatNotaSuara({super.key});

  @override
  ConsumerState<Screen6BuatNotaSuara> createState() =>
      _Screen6BuatNotaSuaraState();
}

class _DraftInvoiceLine {
  final TextEditingController nameController;
  final TextEditingController qtyController;
  final TextEditingController priceController;
  int quantity;
  int unitPrice;

  _DraftInvoiceLine({
    required String name,
    required this.quantity,
    required this.unitPrice,
  })  : nameController = TextEditingController(text: name),
        qtyController = TextEditingController(text: quantity.toString()),
        priceController = TextEditingController(text: _formatDots(unitPrice));

  int get subtotal => quantity * unitPrice;

  TransactionLineItem toLineItem() {
    final trimmed = nameController.text.trim();
    return TransactionLineItem(
      name: trimmed.isEmpty ? 'Item Invoice' : trimmed,
      quantity: quantity,
      unitPrice: unitPrice,
    );
  }

  void dispose() {
    nameController.dispose();
    qtyController.dispose();
    priceController.dispose();
  }

  static String _formatDots(int value) {
    if (value <= 0) return '';
    final str = value.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }
}

class _Screen6BuatNotaSuaraState extends ConsumerState<Screen6BuatNotaSuara> {
  late final TextEditingController _customerController;
  late final TextEditingController _contactController;
  late final TextEditingController _dueDateController;
  late final List<_DraftInvoiceLine> _items;
  DateTime? _selectedDueDate;
  bool _isSubmitting = false;

  static const List<(String label, int days)> _duePresets = [
    ('Besok', 1),
    ('7 Hari Lagi', 7),
    ('14 Hari Lagi', 14),
    ('30 Hari Lagi', 30),
  ];

  static const List<String> _indoMonths = [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  static String _formatIndoDate(DateTime date) {
    return '${date.day} ${_indoMonths[date.month]} ${date.year}';
  }

  @override
  void initState() {
    super.initState();
    final isAuth = ref.read(authProvider).isAuthenticated;
    if (isAuth) {
      final defaultDue = DateTime.now().add(const Duration(days: 7));
      _selectedDueDate = defaultDue;
      _customerController = TextEditingController();
      _contactController = TextEditingController();
      _dueDateController =
          TextEditingController(text: _formatIndoDate(defaultDue));
      _items = [
        _DraftInvoiceLine(
          name: '',
          quantity: 1,
          unitPrice: 0,
        ),
      ];
    } else {
      _customerController = TextEditingController(text: 'Pak Reza');
      _contactController = TextEditingController(text: '0812-8890-3344');
      _dueDateController = TextEditingController(text: '12 November 2026');
      _items = [
        _DraftInvoiceLine(
          name: 'Kursi Kerja',
          quantity: 3,
          unitPrice: 100000,
        ),
        _DraftInvoiceLine(
          name: 'Meja',
          quantity: 3,
          unitPrice: 200000,
        ),
      ];
    }
  }

  @override
  void dispose() {
    _customerController.dispose();
    _contactController.dispose();
    _dueDateController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  int get _grandTotal => _items.fold(0, (sum, item) => sum + item.subtotal);

  void _stepQty(int index, int delta) {
    HapticFeedback.selectionClick();
    setState(() {
      final item = _items[index];
      final nextQty = (item.quantity + delta).clamp(1, 999);
      item.quantity = nextQty;
      final text = nextQty.toString();
      item.qtyController.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    });
  }

  void _onQtyChanged(int index, String raw) {
    final clean = raw.replaceAll(RegExp(r'[^0-9]'), '');
    final parsed = int.tryParse(clean) ?? 0;
    setState(() {
      _items[index].quantity = parsed.clamp(0, 999);
    });
  }

  void _onPriceChanged(int index, String raw) {
    final clean = raw.replaceAll(RegExp(r'[^0-9]'), '');
    final parsed = int.tryParse(clean) ?? 0;
    setState(() {
      _items[index].unitPrice = parsed.clamp(0, 999999999);
    });
  }

  void _addLine() {
    HapticFeedback.selectionClick();
    setState(() {
      _items.add(
        _DraftInvoiceLine(
          name: '',
          quantity: 1,
          unitPrice: 0,
        ),
      );
    });
  }

  void _removeLine(int index) {
    if (_items.length <= 1) return;
    HapticFeedback.selectionClick();
    setState(() {
      final removed = _items.removeAt(index);
      removed.dispose();
    });
  }

  Future<void> _saveAndCreateInvoice() async {
    if (_isSubmitting) return;
    HapticFeedback.mediumImpact();

    final rawCustomer = _customerController.text.trim();
    if (rawCustomer.isEmpty) {
      UcapKasToast.showInfo(
        context,
        headerLabel: 'Lengkapi Data',
        title: 'Nama pelanggan wajib diisi',
        subtitle: 'Isi nama pelanggan atau toko tujuan tagihan',
        badgeText: 'INFO',
      );
      return;
    }

    if (_grandTotal <= 0) {
      UcapKasToast.showInfo(
        context,
        headerLabel: 'Lengkapi Data',
        title: 'Nominal tagihan masih Rp 0',
        subtitle: 'Masukkan harga satuan barang atau jasa terlebih dahulu',
        badgeText: 'INFO',
      );
      return;
    }

    final isAuth = ref.read(authProvider).isAuthenticated;
    final contact = _contactController.text.trim().isEmpty
        ? 'WA Pelanggan'
        : _contactController.text.trim();
    final due = _dueDateController.text.trim().isEmpty
        ? '7 Hari Lagi'
        : _dueDateController.text.trim();
    final lineItems = _items.map((e) => e.toLineItem()).toList();
    final summary =
        lineItems.map((e) => '${e.quantity}x ${e.name}').join(', ');

    final tempId = isAuth ? 'temp-${DateTime.now().millisecondsSinceEpoch}' : '';
    final number = isAuth
        ? ''
        : 'NOTA/2026/${1109 + ref.read(notaListProvider).length}';

    setState(() => _isSubmitting = true);

    final ok = await ref.read(notaListProvider.notifier).addNota(
          NotaInvoice(
            id: tempId,
            number: number,
            clientName: '$rawCustomer — $summary',
            clientContact: contact,
            subtitle: number.isEmpty ? 'Tempo: $due' : '$number • Tempo: $due',
            dateIssued: 'Hari Ini',
            dueDateLabel: 'Tempo: $due',
            dueAt: _selectedDueDate,
            amount: _grandTotal,
            status: NotaStatus.menunggu,
            items: List.unmodifiable(lineItems),
          ),
        );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (!ok) {
      UcapKasToast.showInfo(
        context,
        headerLabel: 'Gagal Menyimpan',
        title: 'Invoice gagal disimpan ke server',
        subtitle: 'Periksa koneksi internet Anda dan coba lagi',
        badgeText: 'ERROR',
      );
      return;
    }

    if (number.isNotEmpty) {
      ref.read(selectedNotaNumberProvider.notifier).state = number;
    } else {
      final latest = ref.read(notaListProvider);
      if (latest.isNotEmpty) {
        ref.read(selectedNotaNumberProvider.notifier).state =
            latest.first.number;
      }
    }

    UcapKasToast.showInfo(
      context,
      headerLabel: 'Invoice Tersimpan',
      title: rawCustomer,
      subtitle: summary,
      badgeText: RupiahFormatter.format(_grandTotal),
    );
    context.go('/nota');
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final initial = _selectedDueDate ?? now.add(const Duration(days: 7));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedDueDate = picked;
      _dueDateController.text = _formatIndoDate(picked);
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentDue = _dueDateController.text.trim();

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
          'Buat Invoice Baru',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: GestureDetector(
                onTap: () {
                  ref.read(lastVoiceSessionProvider.notifier).state =
                      const VoiceRecordingSession(
                    durationSeconds: 5,
                    isPushToTalk: false,
                    transcript: VoiceRecordingSession.sampleInvoiceSpeech,
                  );
                  context.push('/bicara');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryTealSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.mic_none_rounded,
                        size: 14,
                        color: AppColors.primaryTeal,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Isi pakai suara',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryTeal,
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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 32),
        children: [
          // 1. Kartu Data Pelanggan & Jatuh Tempo
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
                Text(
                  'Tagihkan Kepada (Pelanggan)',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _customerController,
                  textCapitalization: TextCapitalization.words,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(
                      Icons.person_outline_rounded,
                      size: 17,
                      color: AppColors.primaryTeal,
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 38,
                      minHeight: 38,
                    ),
                    hintText: 'Nama pelanggan atau perusahaan',
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
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'No. WhatsApp Pelanggan',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _contactController,
                  keyboardType: TextInputType.phone,
                  style: AppTheme.numStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(
                      Icons.phone_outlined,
                      size: 17,
                      color: AppColors.primaryTeal,
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 38,
                      minHeight: 38,
                    ),
                    hintText: 'Contoh: 0812-8890-3344',
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
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Jatuh Tempo',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _dueDateController,
                  onChanged: (_) => setState(() {
                    _selectedDueDate = null;
                  }),
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(
                      Icons.event_outlined,
                      size: 17,
                      color: AppColors.primaryTeal,
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 38,
                      minHeight: 38,
                    ),
                    suffixIcon: IconButton(
                      onPressed: _pickDueDate,
                      tooltip: 'Pilih tanggal jatuh tempo',
                      icon: const Icon(
                        Icons.calendar_month_outlined,
                        size: 18,
                        color: AppColors.primaryTeal,
                      ),
                    ),
                    hintText: 'Contoh: 23 Nov 2026',
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
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _duePresets.map((preset) {
                    final targetDate =
                        DateTime.now().add(Duration(days: preset.$2));
                    final formattedTarget = _formatIndoDate(targetDate);
                    final selected = currentDue == formattedTarget ||
                        currentDue == preset.$1;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _selectedDueDate = targetDate;
                          _dueDateController.text = formattedTarget;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.heroDark
                              : AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          preset.$1,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 2. Kartu Rincian Barang / Jasa (Flat Ledger Rows)
          Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
              boxShadow: AppColors.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'Rincian Item Invoice',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _addLine,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.add_rounded,
                            size: 16,
                            color: AppColors.primaryTeal,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'Tambah Barang',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryTeal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.border),
                for (int i = 0; i < _items.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: AppColors.border),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: _buildLineEditor(i, _items[i]),
                  ),
                ],
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Tagihan Invoice',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      RupiahFormatter.format(_grandTotal),
                      style: AppTheme.numStyle(
                        fontSize: 20,
                        color: AppColors.primaryTeal,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: ElevatedButton.icon(
            onPressed: _isSubmitting ? null : _saveAndCreateInvoice,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.heroDark,
              foregroundColor: Colors.white,
              elevation: 0,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: _isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_rounded, size: 16),
            label: Text(
              _isSubmitting ? 'Menyimpan Invoice...' : 'Simpan & Kirim Invoice',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLineEditor(int index, _DraftInvoiceLine item) {
    final rowNumber = (index + 1).toString().padLeft(2, '0');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 24,
              child: Text(
                rowNumber,
                style: AppTheme.numStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            Expanded(
              child: TextField(
                controller: item.nameController,
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                decoration: const InputDecoration(
                  hintText: 'Nama barang / jasa',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 4),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              RupiahFormatter.format(item.subtotal),
              style: AppTheme.numStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
            if (_items.length > 1) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => _removeLine(index),
                child: const Icon(
                  Icons.close_rounded,
                  size: 15,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 24),
          child: Row(
            children: [
              Container(
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => _stepQty(index, -1),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        child: Icon(Icons.remove_rounded, size: 13),
                      ),
                    ),
                    SizedBox(
                      width: 32,
                      child: TextField(
                        controller: item.qtyController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(3),
                        ],
                        onChanged: (v) => _onQtyChanged(index, v),
                        style: AppTheme.numStyle(
                          fontSize: 12.5,
                          color: AppColors.textPrimary,
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => _stepQty(index, 1),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        child: Icon(Icons.add_rounded, size: 13),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '×',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Rp',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: TextField(
                          controller: item.priceController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            _NotaDotFormatter(),
                          ],
                          onChanged: (v) => _onPriceChanged(index, v),
                          style: AppTheme.numStyle(
                            fontSize: 12.5,
                            color: AppColors.textPrimary,
                          ),
                          decoration: const InputDecoration(
                            hintText: '0',
                            isDense: true,
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NotaDotFormatter extends TextInputFormatter {
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
    final str = parsed.toString();
    final buffer = StringBuffer();
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
