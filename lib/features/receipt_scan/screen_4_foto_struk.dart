import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/pro_badge.dart';
import '../../data/models/cash_transaction.dart';
import '../../state/ledger_providers.dart';

class Screen4FotoStruk extends ConsumerWidget {
  const Screen4FotoStruk({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                      Icon(Icons.arrow_back, size: 18, color: AppColors.textSecondary),
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
                const ProBadge(label: 'PAKET USAHA'),
              ],
            ),
            const SizedBox(height: 18),
            // Camera Viewfinder Mock
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
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1F352E),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Struk Terbaca Otomatis • 4 Barang',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.mintSuccess,
                          ),
                        ),
                      ),
                      const Text(
                        'Foto Ulang',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textOnDarkMuted,
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
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TOKO BAHAN KUE BERKAH JAYA',
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Jl. Pasar Baru No. 45 • 24 Okt 2026 09:42',
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'TOTAL TUNAI (4 ITEM)',
                              style: TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Rp 450.000',
                              style: TextStyle(
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
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'RINCIAN DARI STRUK',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.7,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Toko Bahan Kue Berkah Jaya',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                  _buildLineRow('Tepung Terigu Cakra 25kg', '1 Sak × Rp 245.000', 'Rp 245.000'),
                  const SizedBox(height: 10),
                  _buildLineRow('Gula Pasir Gulaku 10kg', '1 Bal × Rp 165.000', 'Rp 165.000'),
                  const SizedBox(height: 10),
                  _buildLineRow('Ragi Instan Fermipan & Plastik', '2 Pak × Rp 20.000', 'Rp 40.000'),
                  const Divider(height: 24, color: AppColors.borderSubtle),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Belanja Bahan',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '- Rp 450.000',
                        style: TextStyle(
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.bgChipWarm,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Ada tulisan struk yang kurang pas? Ketuk rincian atau ucapkan koreksi.',
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
                            const CashTransaction(
                              id: 'tx-struk-new',
                              title: 'Toko Bahan Kue Berkah Jaya',
                              category: 'Bahan Baku',
                              paymentMethod: 'Tunai • Foto Struk (4 Barang)',
                              timeLabel: 'Baru saja',
                              dateGroup: 'HARI INI — SABTU, 24 OKT',
                              amount: -450000,
                              hasReceiptPhoto: true,
                            ),
                          );
                      context.go('/dashboard');
                    },
                    child: const Text(
                      'Simpan ke Kas',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
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

  Widget _buildLineRow(String title, String sub, String price) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            Text(
              sub,
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
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
