import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/rupiah_formatter.dart';
import '../../core/utils/slang_parser.dart';
import '../../core/widgets/ucapkas_toast.dart';
import '../../core/widgets/workspace_pill.dart';
import '../../data/models/cash_transaction.dart';
import '../../data/models/nota_invoice.dart';
import '../../state/ledger_providers.dart';

class Screen2VoiceSheet extends ConsumerStatefulWidget {
  const Screen2VoiceSheet({super.key});

  @override
  ConsumerState<Screen2VoiceSheet> createState() => _Screen2VoiceSheetState();
}

class _EditableVoiceItem {
  final TextEditingController nameController;
  final TextEditingController qtyController;
  final TextEditingController priceController;
  int quantity;
  int unitPrice;

  _EditableVoiceItem({
    required String name,
    required this.quantity,
    required this.unitPrice,
  })  : nameController = TextEditingController(text: name),
        qtyController = TextEditingController(text: quantity.toString()),
        priceController = TextEditingController(
          text: _formatDots(unitPrice),
        );

  int get subtotal => quantity * unitPrice;

  TransactionLineItem toLineItem() {
    final trimmed = nameController.text.trim();
    return TransactionLineItem(
      name: trimmed.isEmpty ? 'Item' : trimmed,
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

class _Screen2VoiceSheetState extends ConsumerState<Screen2VoiceSheet>
    with SingleTickerProviderStateMixin {
  VoiceIntentType _intentType = VoiceIntentType.bukuKas;
  bool _isKasMasuk = true;
  late final AnimationController _modeController;
  late final Animation<double> _modeAnim;

  // Shared free-text speech transcript controller
  late final TextEditingController _transcriptController;

  // Buku Kas controllers & state
  late final TextEditingController _kasNoteController;
  late final TextEditingController _categoryController;
  String _selectedPayment = 'Tunai';
  final List<_EditableVoiceItem> _kasItems = [];

  // Kirim Invoice controllers & state
  late final TextEditingController _invoiceCustomerController;
  late final TextEditingController _invoiceContactController;
  late final TextEditingController _invoiceDueDateController;
  late final TextEditingController _invoiceNotesController;
  final List<_EditableVoiceItem> _invoiceItems = [];

  static const List<String> _presetCategories = [
    'Servis',
    'Suku Cadang',
    'Bahan Baku',
    'Operasional',
    'Lainnya',
  ];

  static const List<(String, IconData)> _paymentMethods = [
    ('Tunai', Icons.payments_outlined),
    ('QRIS', Icons.qr_code_rounded),
    ('Transfer', Icons.account_balance_outlined),
  ];

  static const List<String> _dueDatePills = [
    '12 November 2026',
    '7 Hari Lagi',
    'Akhir Bulan',
  ];

  @override
  void initState() {
    super.initState();
    _modeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      value: 0.0,
    );
    _modeAnim = CurvedAnimation(
      parent: _modeController,
      curve: Curves.fastOutSlowIn,
    );

    final session = ref.read(lastVoiceSessionProvider);
    _transcriptController = TextEditingController(text: session.transcript);
    _kasNoteController =
        TextEditingController(text: 'Pak Husni — Benerin motor');
    _categoryController = TextEditingController(text: 'Servis');

    _invoiceCustomerController = TextEditingController(text: 'Pak Reza');
    _invoiceContactController =
        TextEditingController(text: '0812-8890-3344');
    _invoiceDueDateController =
        TextEditingController(text: '12 November 2026');
    _invoiceNotesController = TextEditingController(
      text: 'Pembelian kursi kerja 3 buah & meja 3 buah',
    );

    _resetDefaultKasItems();
    _resetDefaultInvoiceItems();
    _detectAndApplySpeech(session.transcript, resetItems: false);
  }

  void _resetDefaultKasItems() {
    for (final item in _kasItems) {
      item.dispose();
    }
    _kasItems
      ..clear()
      ..addAll([
        _EditableVoiceItem(
          name: 'Oli Mesin Beat',
          quantity: 3,
          unitPrice: 10000,
        ),
        _EditableVoiceItem(
          name: 'Busi Motor Standar',
          quantity: 1,
          unitPrice: 25000,
        ),
      ]);
  }

  void _resetDefaultInvoiceItems() {
    for (final item in _invoiceItems) {
      item.dispose();
    }
    _invoiceItems
      ..clear()
      ..addAll([
        _EditableVoiceItem(
          name: 'Kursi Kerja',
          quantity: 3,
          unitPrice: 100000,
        ),
        _EditableVoiceItem(
          name: 'Meja',
          quantity: 3,
          unitPrice: 200000,
        ),
      ]);
  }

  @override
  void dispose() {
    _modeController.dispose();
    _transcriptController.dispose();
    _kasNoteController.dispose();
    _categoryController.dispose();
    _invoiceCustomerController.dispose();
    _invoiceContactController.dispose();
    _invoiceDueDateController.dispose();
    _invoiceNotesController.dispose();
    for (final item in _kasItems) {
      item.dispose();
    }
    for (final item in _invoiceItems) {
      item.dispose();
    }
    super.dispose();
  }

  List<_EditableVoiceItem> get _activeItems =>
      _intentType == VoiceIntentType.bukuKas ? _kasItems : _invoiceItems;

  int get _totalAmount =>
      _activeItems.fold(0, (sum, item) => sum + item.subtotal);

  /// Parses free-text speech to determine whether it is a Buku Kas entry or
  /// a Kirim Invoice command, and extracts customer / due date / notes.
  void _detectAndApplySpeech(String rawSpeech, {required bool resetItems}) {
    final lower = rawSpeech.toLowerCase();
    final isInvoiceSpeech = lower.contains('invoice') ||
        lower.contains('tagihan') ||
        lower.contains('jatuh tempo') ||
        lower.contains('faktur') ||
        lower.contains('buatin nota');

    setState(() {
      if (isInvoiceSpeech) {
        _intentType = VoiceIntentType.kirimInvoice;

        // Extract customer name after "untuk " or "kepada "
        final customerMatch = RegExp(
          r'(?:untuk|kepada|ke)\s+([a-zA-Z\s\.]+?)(?:,|pembelian|beli|sebesar|total|$)',
          caseSensitive: false,
        ).firstMatch(rawSpeech);
        if (customerMatch != null) {
          final extracted = customerMatch.group(1)?.trim() ?? '';
          if (extracted.isNotEmpty) {
            _invoiceCustomerController.text = extracted;
          }
        }

        // Extract due date after "jatuh tempo"
        final dueMatch = RegExp(
          r'jatuh\s+tempo\s+(?:tgl|tanggal)?\s*([0-9]{1,2}\s+[a-zA-Z]+(?:\s+[0-9]{4})?)',
          caseSensitive: false,
        ).firstMatch(rawSpeech);
        if (dueMatch != null) {
          final rawDue = dueMatch.group(1)?.trim() ?? '';
          if (rawDue.isNotEmpty) {
            _invoiceDueDateController.text =
                rawDue.contains('202') ? rawDue : '$rawDue 2026';
          }
        }

        if (resetItems) {
          _resetDefaultInvoiceItems();
        }
      } else {
        _intentType = VoiceIntentType.bukuKas;
        final isOutflow = lower.contains('uang keluar') ||
            lower.contains('kas keluar') ||
            lower.contains('bayar ') ||
            (lower.contains('beli ') && !lower.contains('uang masuk'));
        _isKasMasuk = !isOutflow;
        if (_isKasMasuk) {
          _modeController.reverse();
        } else {
          _modeController.forward();
        }

        // Extract person / reason from "dari <name>"
        final fromMatch = RegExp(
          r'dari\s+([a-zA-Z\s]+?)(?:\s+benerin|\s+servis|\s+ganti|\s+beli|,|$)',
          caseSensitive: false,
        ).firstMatch(rawSpeech);
        if (fromMatch != null) {
          final sender = fromMatch.group(1)?.trim() ?? '';
          if (sender.isNotEmpty) {
            _kasNoteController.text = lower.contains('benerin motor')
                ? '$sender — Benerin motor'
                : sender;
          }
        }

        if (resetItems) {
          _resetDefaultKasItems();
        }
      }
    });
  }

  void _applySampleSpeech(String sample) {
    HapticFeedback.selectionClick();
    _transcriptController.value = TextEditingValue(
      text: sample,
      selection: TextSelection.collapsed(offset: sample.length),
    );
    _detectAndApplySpeech(sample, resetItems: true);
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

  void _stepItemQty(int index, int delta) {
    HapticFeedback.selectionClick();
    setState(() {
      final item = _activeItems[index];
      final nextQty = (item.quantity + delta).clamp(1, 999);
      item.quantity = nextQty;
      final text = nextQty.toString();
      item.qtyController.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    });
  }

  void _onQtyTextChanged(int index, String raw) {
    final clean = raw.replaceAll(RegExp(r'[^0-9]'), '');
    final parsed = int.tryParse(clean) ?? 0;
    setState(() {
      _activeItems[index].quantity = parsed.clamp(0, 999);
    });
  }

  void _onPriceTextChanged(int index, String raw) {
    final clean = raw.replaceAll(RegExp(r'[^0-9]'), '');
    final parsed = int.tryParse(clean) ?? 0;
    setState(() {
      _activeItems[index].unitPrice = parsed.clamp(0, 999999999);
    });
  }

  void _addNewItem() {
    HapticFeedback.selectionClick();
    setState(() {
      _activeItems.add(
        _EditableVoiceItem(
          name: _intentType == VoiceIntentType.kirimInvoice
              ? 'Item Tagihan Baru'
              : 'Barang / Jasa Baru',
          quantity: 1,
          unitPrice: _intentType == VoiceIntentType.kirimInvoice ? 100000 : 15000,
        ),
      );
    });
  }

  void _removeItem(int index) {
    if (_activeItems.length <= 1) return;
    HapticFeedback.selectionClick();
    setState(() {
      final removed = _activeItems.removeAt(index);
      removed.dispose();
    });
  }

  void _selectCategoryChip(String cat) {
    HapticFeedback.selectionClick();
    setState(() {
      _categoryController.value = TextEditingValue(
        text: cat,
        selection: TextSelection.collapsed(offset: cat.length),
      );
    });
  }

  void _saveVoiceTransaction() {
    HapticFeedback.mediumImpact();
    final total = _totalAmount;
    final signedAmount = _isKasMasuk ? total : -total;
    final lineItems = _kasItems.map((e) => e.toLineItem()).toList();
    final itemTitle = lineItems.map((e) => e.name).join(' & ');
    final noteText = _kasNoteController.text.trim();
    final categoryText = _categoryController.text.trim().isEmpty
        ? 'Lainnya'
        : _categoryController.text.trim();

    ref.read(transactionsProvider.notifier).addTransaction(
          CashTransaction(
            id: 'tx-voice-${DateTime.now().millisecondsSinceEpoch}',
            title: itemTitle,
            category: categoryText,
            paymentMethod: _selectedPayment,
            timeLabel: 'Baru saja',
            dateGroup: 'HARI INI • RABU, 11 NOV 2026',
            amount: signedAmount,
            customerName: noteText.isEmpty ? null : noteText,
            items: List.unmodifiable(lineItems),
          ),
        );
    if (_isKasMasuk) {
      UcapKasToast.showKasMasuk(
        context,
        title: itemTitle,
        amount: total,
        subtitle: '$categoryText • $_selectedPayment',
      );
    } else {
      UcapKasToast.showKasKeluar(
        context,
        title: itemTitle,
        amount: total,
        subtitle: '$categoryText • $_selectedPayment',
      );
    }
    context.go('/kas');
  }

  void _saveAndSendVoiceInvoice() {
    HapticFeedback.mediumImpact();
    final total = _totalAmount;
    final lineItems = _invoiceItems.map((e) => e.toLineItem()).toList();
    final customer = _invoiceCustomerController.text.trim().isEmpty
        ? 'Pelanggan'
        : _invoiceCustomerController.text.trim();
    final contact = _invoiceContactController.text.trim().isEmpty
        ? 'WA Pelanggan'
        : 'WA: ${_invoiceContactController.text.trim()}';
    final dueDate = _invoiceDueDateController.text.trim().isEmpty
        ? '12 November 2026'
        : _invoiceDueDateController.text.trim();
    final itemSummary = lineItems.map((e) => '${e.quantity}x ${e.name}').join(', ');
    final invoiceNumber =
        'NOTA/2026/${1109 + ref.read(notaListProvider).length}';

    ref.read(notaListProvider.notifier).addNota(
          NotaInvoice(
            number: invoiceNumber,
            clientName: '$customer — $itemSummary',
            clientContact: contact,
            subtitle: '$invoiceNumber • Jatuh Tempo $dueDate',
            dateIssued: '14 Nov 2026',
            dueDateLabel: 'Jatuh Tempo: $dueDate',
            amount: total,
            status: NotaStatus.menunggu,
            items: List.unmodifiable(lineItems),
          ),
        );
    ref.read(selectedNotaNumberProvider.notifier).state = invoiceNumber;
    UcapKasToast.showInfo(
      context,
      headerLabel: 'Nota WA Siap Dikirim',
      title: '$customer • $invoiceNumber',
      subtitle: itemSummary,
      badgeText: RupiahFormatter.format(total),
    );
    context.go('/nota');
  }

  @override
  Widget build(BuildContext context) {
    final ws = ref.watch(activeWorkspaceProvider);
    final voiceSession = ref.watch(lastVoiceSessionProvider);
    final formattedDuration =
        '00:${voiceSession.durationSeconds.toString().padLeft(2, '0')}';
    final slangAmount = SlangParser.parseSpokenAmount('ceban tiga') ?? 30000;

    return AnimatedBuilder(
      animation: _modeAnim,
      builder: (context, _) {
        final t = _modeAnim.value;
        final kasAccent = Color.lerp(
              AppColors.primaryTeal,
              AppColors.expenseRose,
              t,
            ) ??
            AppColors.primaryTeal;
        final kasSoftBg = Color.lerp(
              AppColors.primaryTealSoft,
              AppColors.expenseSoft,
              t,
            ) ??
            AppColors.primaryTealSoft;

        final activeAccent = _intentType == VoiceIntentType.kirimInvoice
            ? AppColors.primaryTeal
            : kasAccent;

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
              'Periksa Catatan Suara',
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
                // 1. Free-Text Speech Box + Intent Switcher (Buku Kas vs Kirim Invoice)
                _buildVoiceSpeechCard(
                  formattedDuration: formattedDuration,
                  isPushToTalk: voiceSession.isPushToTalk,
                  slangAmount: slangAmount,
                  accent: activeAccent,
                ),
                const SizedBox(height: 14),

                // 2. SWITCH CASE based on VoiceIntentType
                switch (_intentType) {
                  VoiceIntentType.bukuKas => _buildBukuKasContent(
                      t: t,
                      accent: kasAccent,
                      softBg: kasSoftBg,
                    ),
                  VoiceIntentType.kirimInvoice => _buildKirimInvoiceContent(
                      accent: AppColors.primaryTeal,
                    ),
                },
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
                      onPressed: () => context.pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.borderStrong),
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Rekam Ulang',
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
                    child: switch (_intentType) {
                      VoiceIntentType.bukuKas => ElevatedButton(
                          onPressed: _saveVoiceTransaction,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kasAccent,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            _isKasMasuk
                                ? 'Simpan Kas Masuk'
                                : 'Simpan Kas Keluar',
                            style: GoogleFonts.inter(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      VoiceIntentType.kirimInvoice => ElevatedButton.icon(
                          onPressed: _saveAndSendVoiceInvoice,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.heroDark,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(
                            Icons.send_rounded,
                            size: 16,
                          ),
                          label: Text(
                            'Buat & Kirim Invoice',
                            style: GoogleFonts.inter(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Top card: Free-text speech box + automatic intent detection + sample speech pills
  Widget _buildVoiceSpeechCard({
    required String formattedDuration,
    required bool isPushToTalk,
    required int slangAmount,
    required Color accent,
  }) {
    final isInvoice = _intentType == VoiceIntentType.kirimInvoice;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Suara Anda + Mode Switcher (Buku Kas vs Kirim Invoice)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Icon(
                      Icons.graphic_eq_rounded,
                      size: 15,
                      color: accent,
                    ),
                    Text(
                      'Suara Anda · $formattedDuration',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSubtle,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isPushToTalk ? 'Push-to-Talk' : 'Rekam Klik',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              // Intent Type Pill Switcher (Buku Kas vs Kirim Invoice)
              Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildIntentSwitchPill(
                      label: 'Buku Kas',
                      selected: !isInvoice,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _intentType = VoiceIntentType.bukuKas;
                        });
                      },
                    ),
                    _buildIntentSwitchPill(
                      label: 'Kirim Invoice',
                      selected: isInvoice,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _intentType = VoiceIntentType.kirimInvoice;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Free-text editable speech box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  key: const Key('input_voice_transcript'),
                  controller: _transcriptController,
                  minLines: 1,
                  maxLines: 3,
                  onChanged: (val) =>
                      _detectAndApplySpeech(val, resetItems: false),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText:
                        'Ketik kalimat suara (misal: "Ada uang masuk..." atau "Buatin invoice...")',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: AppColors.textMuted,
                    ),
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isInvoice
                      ? 'Terdeteksi perintah Invoice untuk ${_invoiceCustomerController.text} · Jatuh tempo ${_invoiceDueDateController.text}'
                      : 'Terdeteksi pencatatan Kas · "ceban tiga" = ${RupiahFormatter.format(slangAmount)}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: accent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Simulasi Cepat Kalimat Suara (1-tap test for both speech types)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Coba ucapan:',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
              _buildSampleSpeechPill(
                label: 'Kas Masuk (Pak Husni)',
                isActive: !isInvoice,
                onTap: () => _applySampleSpeech(
                  VoiceRecordingSession.sampleKasSpeech,
                ),
              ),
              _buildSampleSpeechPill(
                label: 'Buat Invoice (Pak Reza · Rp 900 rb)',
                isActive: isInvoice,
                onTap: () => _applySampleSpeech(
                  VoiceRecordingSession.sampleInvoiceSpeech,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// CASE 1: BUKU KAS (Kas Masuk / Kas Keluar)
  Widget _buildBukuKasContent({
    required double t,
    required Color accent,
    required Color softBg,
  }) {
    final currentCategory = _categoryController.text.trim();
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Hero Financial Summary + Smooth Sliding Toggle (Kas Masuk / Keluar)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
            boxShadow: AppColors.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final trackWidth = constraints.maxWidth - 6;
                  return GestureDetector(
                    onHorizontalDragUpdate: (details) {
                      if (trackWidth <= 0) return;
                      final nextVal = (_modeController.value +
                              (details.primaryDelta ?? 0) / (trackWidth * 0.5))
                          .clamp(0.0, 1.0);
                      _modeController.value = nextVal;
                    },
                    onHorizontalDragEnd: (details) {
                      final vx = details.primaryVelocity ?? 0;
                      final goToKeluar = vx > 180 ||
                          (vx >= -180 && _modeController.value >= 0.5);
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
                      height: 42,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Stack(
                        children: [
                          Align(
                            alignment: Alignment(t * 2.0 - 1.0, 0.0),
                            child: FractionallySizedBox(
                              widthFactor: 0.5,
                              heightFactor: 1.0,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x100B1220),
                                      blurRadius: 6,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => _switchTransactionType(true),
                                  child: Center(
                                    child: Text(
                                      'Kas Masuk',
                                      style: GoogleFonts.inter(
                                        fontSize: 12.5,
                                        fontWeight: t < 0.5
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: leftTextColor,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => _switchTransactionType(false),
                                  child: Center(
                                    child: Text(
                                      'Kas Keluar',
                                      style: GoogleFonts.inter(
                                        fontSize: 12.5,
                                        fontWeight: t >= 0.5
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: rightTextColor,
                                      ),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isKasMasuk
                              ? 'Total Uang Masuk'
                              : 'Total Uang Keluar',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_kasItems.length} rincian tercatat',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_isKasMasuk ? '+' : '-'}${RupiahFormatter.format(_totalAmount)}',
                    style: AppTheme.numStyle(
                      fontSize: 26,
                      color: accent,
                      letterSpacing: -0.7,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Free-text Catatan / Keterangan Kas (misal: Pak Husni — Benerin motor)
              TextField(
                controller: _kasNoteController,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  prefixIcon: const Icon(
                    Icons.notes_rounded,
                    size: 17,
                    color: AppColors.textMuted,
                  ),
                  hintText: 'Keterangan kas (misal: Pak Husni — Benerin motor)',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: AppColors.textMuted,
                  ),
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(11),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Rincian Catatan Suara (Flat Ledger Sheet)
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
                      'Rincian Catatan Suara',
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
                    onTap: _addNewItem,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, size: 16, color: accent),
                        const SizedBox(width: 3),
                        Text(
                          'Tambah Baris',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.border),
              for (int i = 0; i < _kasItems.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: AppColors.border),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: _buildLedgerItemRow(i, _kasItems[i], accent),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Kategori Kas & Cara Bayar
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
                      'Kategori Kas',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      'Ketik atau pilih di bawah',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('input_voice_category'),
                controller: _categoryController,
                onChanged: (_) => setState(() {}),
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  prefixIcon: Icon(
                    Icons.folder_open_rounded,
                    size: 17,
                    color: accent,
                  ),
                  hintText: 'Tulis kategori (misal: Servis, Suku Cadang)',
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
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (int i = 0; i < _presetCategories.length; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      Builder(
                        builder: (context) {
                          final cat = _presetCategories[i];
                          final selected =
                              currentCategory.toLowerCase() == cat.toLowerCase();
                          return GestureDetector(
                            onTap: () => _selectCategoryChip(cat),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppColors.heroDark
                                    : AppColors.background,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                cat,
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
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Divider(height: 1, color: AppColors.border),
              ),
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
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(
                            () => _selectedPayment = _paymentMethods[i].$1,
                          );
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _selectedPayment == _paymentMethods[i].$1
                                ? softBg
                                : AppColors.background,
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(
                              color: _selectedPayment == _paymentMethods[i].$1
                                  ? accent
                                  : Colors.transparent,
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _paymentMethods[i].$2,
                                size: 15,
                                color: _selectedPayment == _paymentMethods[i].$1
                                    ? accent
                                    : AppColors.textMuted,
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  _paymentMethods[i].$1,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: _selectedPayment ==
                                            _paymentMethods[i].$1
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: _selectedPayment ==
                                            _paymentMethods[i].$1
                                        ? accent
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// CASE 2: KIRIM INVOICE (Pelanggan Free Text, Jatuh Tempo, Item Invoice, Total Tagihan)
  Widget _buildKirimInvoiceContent({required Color accent}) {
    final currentDue = _invoiceDueDateController.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Kartu Pelanggan & Jatuh Tempo (Free Text)
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
              // Ringkasan Total Invoice di atas
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Tagihan Invoice',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_invoiceItems.length} barang · Siap dibuatkan invoice',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    RupiahFormatter.format(_totalAmount),
                    style: AppTheme.numStyle(
                      fontSize: 26,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.7,
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Divider(height: 1, color: AppColors.border),
              ),

              // Nama Pelanggan (Free Text)
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
                key: const Key('input_invoice_customer'),
                controller: _invoiceCustomerController,
                onChanged: (_) => setState(() {}),
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  prefixIcon: Icon(
                    Icons.person_outline_rounded,
                    size: 17,
                    color: accent,
                  ),
                  hintText: 'Ketik nama pelanggan (misal: Pak Reza)',
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
                ),
              ),
              const SizedBox(height: 12),

              // Nomor WhatsApp / Kontak & Tanggal Jatuh Tempo (Free Text)
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                          key: const Key('input_invoice_due_date'),
                          controller: _invoiceDueDateController,
                          onChanged: (_) => setState(() {}),
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          decoration: InputDecoration(
                            prefixIcon: Icon(
                              Icons.event_outlined,
                              size: 16,
                              color: accent,
                            ),
                            hintText: '12 November 2026',
                            isDense: true,
                            filled: true,
                            fillColor: AppColors.background,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 11,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(11),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kontak / No. WA (Opsional)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _invoiceContactController,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(
                              Icons.phone_outlined,
                              size: 16,
                              color: AppColors.textMuted,
                            ),
                            hintText: '0812-xxxx-xxxx',
                            isDense: true,
                            filled: true,
                            fillColor: AppColors.background,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 11,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(11),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (int i = 0; i < _dueDatePills.length; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _invoiceDueDateController.text = _dueDatePills[i];
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: currentDue == _dueDatePills[i]
                                ? AppColors.heroDark
                                : AppColors.background,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _dueDatePills[i],
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: currentDue == _dueDatePills[i]
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 2. Kartu Item Invoice (Flat Ledger Sheet)
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
                    onTap: _addNewItem,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, size: 16, color: accent),
                        const SizedBox(width: 3),
                        Text(
                          'Tambah Barang',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.border),
              for (int i = 0; i < _invoiceItems.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: AppColors.border),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: _buildLedgerItemRow(i, _invoiceItems[i], accent),
                ),
              ],
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 12),
              Text(
                'Catatan Invoice (Opsional)',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _invoiceNotesController,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Tulis catatan tambahan untuk penerima invoice...',
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIntentSwitchPill({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x120B1220),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppColors.textPrimary : AppColors.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildSampleSpeechPill({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primaryTealSoft : AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? AppColors.primaryTeal : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            color: isActive ? AppColors.primaryTeal : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  /// Flat, editorial ledger row without nested card-in-card borders.
  Widget _buildLedgerItemRow(
    int index,
    _EditableVoiceItem item,
    Color accent,
  ) {
    final rowNumber = (index + 1).toString().padLeft(2, '0');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tier 1: Index + Editable Item Name + Right-Aligned Subtotal
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
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
                key: Key('input_voice_item_name_$index'),
                controller: item.nameController,
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Nama barang atau jasa',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: accent, width: 1.2),
                  ),
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
            if (_activeItems.length > 1) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => _removeItem(index),
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(
                    Icons.close_rounded,
                    size: 15,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),

        // Tier 2: Indented Qty Stepper × Editable Unit Price
        Padding(
          padding: const EdgeInsets.only(left: 24),
          child: Row(
            children: [
              // Compact Qty Stepper + Direct Input
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
                      onTap: () => _stepItemQty(index, -1),
                      borderRadius: BorderRadius.circular(8),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        child: Icon(
                          Icons.remove_rounded,
                          size: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 32,
                      child: TextField(
                        key: Key('input_voice_item_qty_$index'),
                        controller: item.qtyController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(3),
                        ],
                        onChanged: (v) => _onQtyTextChanged(index, v),
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
                      onTap: () => _stepItemQty(index, 1),
                      borderRadius: BorderRadius.circular(8),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        child: Icon(
                          Icons.add_rounded,
                          size: 13,
                          color: AppColors.textSecondary,
                        ),
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
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              // Compact Editable Unit Price Field
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
                          key: Key('input_voice_item_price_$index'),
                          controller: item.priceController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            _VoiceDotSeparatorFormatter(),
                          ],
                          onChanged: (v) => _onPriceTextChanged(index, v),
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
                      const Icon(
                        Icons.edit_outlined,
                        size: 12,
                        color: AppColors.textMuted,
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

class _VoiceDotSeparatorFormatter extends TextInputFormatter {
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
