import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/rupiah_formatter.dart';
import '../../core/widgets/pro_badge.dart';
import '../../core/widgets/ucapkas_toast.dart';
import '../../data/models/cash_transaction.dart';
import '../../data/repositories/ai_repository.dart';
import '../../state/auth_provider.dart';
import '../../state/ledger_providers.dart';

class Screen4FotoStruk extends ConsumerStatefulWidget {
  const Screen4FotoStruk({super.key});

  @override
  ConsumerState<Screen4FotoStruk> createState() => _Screen4FotoStrukState();
}

class _Screen4FotoStrukState extends ConsumerState<Screen4FotoStruk> {
  String _selectedPreset = 'onderdil';
  bool _isScanning = false;

  static const Map<String, ReceiptAiResult> _localPresets = {
    'onderdil': ReceiptAiResult(
      storeName: 'Toko Onderdil Motor & Mobil Jaya',
      category: 'Suku Cadang',
      paymentMethod: 'Tunai',
      totalAmount: 180000,
      items: [
        TransactionLineItem(
          name: 'Kampas Rem Depan Honda Beat (2 Set)',
          quantity: 2,
          unitPrice: 45000,
        ),
        TransactionLineItem(
          name: 'Oli Mesin Shell Advance AX7 1L',
          quantity: 1,
          unitPrice: 65000,
        ),
        TransactionLineItem(
          name: 'Cairan Pembersih Karburator & Baut',
          quantity: 1,
          unitPrice: 25000,
        ),
      ],
    ),
    'sembako': ReceiptAiResult(
      storeName: 'Grosir Sembako Sumber Makmur',
      category: 'Bahan Baku',
      paymentMethod: 'Tunai',
      totalAmount: 314000,
      items: [
        TransactionLineItem(
          name: 'Beras Ramos Super 5kg',
          quantity: 2,
          unitPrice: 68000,
        ),
        TransactionLineItem(
          name: 'Minyak Goreng Tropical 2L',
          quantity: 3,
          unitPrice: 36000,
        ),
        TransactionLineItem(
          name: 'Gula Pasir Gulaku 1kg',
          quantity: 4,
          unitPrice: 17500,
        ),
      ],
    ),
    'operasional': ReceiptAiResult(
      storeName: 'Toko Plastik & Kemasan Lancar',
      category: 'Operasional',
      paymentMethod: 'QRIS',
      totalAmount: 135000,
      items: [
        TransactionLineItem(
          name: 'Kantong Plastik Kresek HD Besar',
          quantity: 5,
          unitPrice: 12000,
        ),
        TransactionLineItem(
          name: 'Kertas Struk Thermal 58mm (10 Roll)',
          quantity: 1,
          unitPrice: 45000,
        ),
        TransactionLineItem(
          name: 'Lakban Bening Daimaru 2 Inch',
          quantity: 2,
          unitPrice: 15000,
        ),
      ],
    ),
  };

  Future<void> _scanReceiptWithAI(String presetId) async {
    if (_isScanning) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedPreset = presetId;
      _isScanning = true;
    });

    final fallback = _localPresets[presetId] ?? _localPresets['onderdil']!;
    final isAuth = ref.read(authProvider).isAuthenticated;
    final wsId = ref.read(activeWorkspaceProvider).id;

    if (!isAuth || wsId.isEmpty) {
      ref.read(parsedReceiptDraftProvider.notifier).state = fallback;
      setState(() => _isScanning = false);
      return;
    }

    try {
      final result = await ref.read(aiRepositoryProvider).parseReceipt(
            workspaceId: wsId,
            presetId: presetId,
          );
      if (!mounted) return;
      ref.read(parsedReceiptDraftProvider.notifier).state = result;
      ref.read(aiQuotaProvider.notifier).state = result.quota;
      UcapKasToast.showInfo(
        context,
        headerLabel: 'AI Struk Terbaca',
        title: result.storeName,
        subtitle: result.quota.isUnlimited
            ? '${result.items.length} Barang • AI Tanpa Batas'
            : '${result.items.length} Barang • Kuota AI ${result.quota.used}/${result.quota.limit}',
        badgeText: RupiahFormatter.format(result.totalAmount),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      UcapKasToast.showInfo(
        context,
        headerLabel:
            e.code == 'AI_QUOTA_EXCEEDED' ? 'Kuota AI Habis' : 'Gagal Scan AI',
        title: e.message,
      );
    } catch (_) {
      if (!mounted) return;
      ref.read(parsedReceiptDraftProvider.notifier).state = fallback;
    } finally {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(parsedReceiptDraftProvider);
    final totalFormatted = RupiahFormatter.format(draft.totalAmount);

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => context.go('/dashboard'),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.arrow_back,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Kembali',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Text(
                  'Foto Struk Belanja',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const ProBadge(label: 'AI VISION'),
              ],
            ),
            const SizedBox(height: 16),

            // Sample Struk Selector Pills
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildPresetChip('onderdil', 'Struk Onderdil'),
                  const SizedBox(width: 8),
                  _buildPresetChip('sembako', 'Struk Sembako'),
                  const SizedBox(width: 8),
                  _buildPresetChip('operasional', 'Struk Kemasan'),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Camera Viewfinder & OCR Preview
            Container(
              height: 196,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.heroPine,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1F352E),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _isScanning
                              ? 'Memindai Struk dengan AI...'
                              : 'Struk Terbaca Otomatis • ${draft.items.length} Barang',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.mintSuccess,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _scanReceiptWithAI(_selectedPreset),
                        child: Text(
                          _isScanning ? 'Memproses...' : 'Foto Ulang',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textOnDarkMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF8F5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          draft.storeName.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Kategori: ${draft.category} • Metode: ${draft.paymentMethod}',
                          style: const TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'TOTAL ${draft.paymentMethod.toUpperCase()} (${draft.items.length} ITEM)',
                              style: const TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              totalFormatted,
                              style: const TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.terracottaOut,
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
            const SizedBox(height: 16),

            // Extracted Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'RINCIAN DARI STRUK',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.7,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              draft.storeName,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.bgChipDanger,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Uang Keluar',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.terracottaOut,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24, color: AppColors.borderSubtle),
                  for (int i = 0; i < draft.items.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    _buildLineRow(
                      draft.items[i].name,
                      '${draft.items[i].quantity} × ${RupiahFormatter.format(draft.items[i].unitPrice)}',
                      RupiahFormatter.format(draft.items[i].subtotal),
                    ),
                  ],
                  const Divider(height: 24, color: AppColors.borderSubtle),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Belanja (${draft.category})',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '- $totalFormatted',
                        style: const TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.terracottaOut,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Hint Banner
            GestureDetector(
              onTap: () => context.push('/ubah-rincian'),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.bgChipWarm,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Ada tulisan struk yang kurang pas? Ketuk untuk ubah rincian barang.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.amberWarm,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Ubah →',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.amberWarm,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppColors.borderSubtle),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => context.push('/ubah-rincian'),
                    child: const Text(
                      'Ubah Rincian',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.emeraldPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      ref.read(transactionsProvider.notifier).addTransaction(
                            CashTransaction(
                              id: 'tx-struk-${DateTime.now().millisecondsSinceEpoch}',
                              title: draft.storeName,
                              category: draft.category,
                              paymentMethod: draft.paymentMethod,
                              timeLabel: 'Baru saja',
                              dateGroup: 'HARI INI',
                              amount: -draft.totalAmount,
                              hasReceiptPhoto: true,
                              source: 'receipt_ai',
                              items: draft.items,
                            ),
                            source: 'receipt_ai',
                          );
                      UcapKasToast.showKasKeluar(
                        context,
                        title: draft.storeName,
                        amount: draft.totalAmount,
                        subtitle:
                            '${draft.category} • Foto Struk (${draft.items.length} Barang)',
                      );
                      context.go('/kas');
                    },
                    child: const Text(
                      'Simpan ke Kas',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
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
  }

  Widget _buildPresetChip(String id, String label) {
    final active = _selectedPreset == id;
    return GestureDetector(
      onTap: () => _scanReceiptWithAI(id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppColors.heroPine : AppColors.bgCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? AppColors.heroPine : AppColors.borderSubtle,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_rounded,
              size: 14,
              color: active ? AppColors.mintSuccess : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineRow(String title, String sub, String price) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                sub,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          price,
          style: const TextStyle(
            fontFamily: 'JetBrains Mono',
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
