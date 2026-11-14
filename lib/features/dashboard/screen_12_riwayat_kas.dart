import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/rupiah_formatter.dart';
import '../../core/widgets/ucapkas_bottom_nav.dart';
import '../../core/widgets/workspace_pill.dart';
import '../../data/models/cash_transaction.dart';
import '../../state/ledger_providers.dart';

class Screen12RiwayatKas extends ConsumerWidget {
  const Screen12RiwayatKas({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ws = ref.watch(activeWorkspaceProvider);
    final query = ref.watch(txSearchQueryProvider).toLowerCase();
    final filter = ref.watch(txFilterCategoryProvider);
    final allTxs = ref.watch(transactionsProvider);

    final filtered = allTxs.where((tx) {
      final matchesQuery = query.isEmpty ||
          tx.title.toLowerCase().contains(query) ||
          (tx.customerName?.toLowerCase().contains(query) ?? false);
      final matchesFilter = switch (filter) {
        'Kas Masuk' => tx.isInflow,
        'Kas Keluar' => !tx.isInflow,
        'QRIS' => tx.paymentMethod.toUpperCase().contains('QRIS'),
        _ => true,
      };
      return matchesQuery && matchesFilter;
    }).toList();

    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => context.go('/kas'),
                    child: Row(
                      children: [
                        const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'Riwayat Buku Kas',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  WorkspacePill(
                    label: ws.shortName,
                    onTap: () => context.go('/akun'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Search & Period Row
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (val) => ref.read(txSearchQueryProvider.notifier).state = val,
                      decoration: InputDecoration(
                        hintText: 'Cari transaksi (misal: kampas, servis)...',
                        hintStyle: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                        prefixIcon: const Icon(Icons.search_rounded, size: 18),
                        filled: true,
                        fillColor: AppColors.surface,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.heroDark,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Nov 2026',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 15,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Filter Chips Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip(ref, 'Semua', 'Semua (42)', filter),
                    const SizedBox(width: 6),
                    _buildFilterChip(ref, 'Kas Masuk', 'Kas Masuk (26)', filter),
                    const SizedBox(width: 6),
                    _buildFilterChip(ref, 'Kas Keluar', 'Kas Keluar (16)', filter),
                    const SizedBox(width: 6),
                    _buildFilterChip(ref, 'QRIS', 'QRIS (19)', filter),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Period Summary Dark Bar
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.heroDark,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSummaryCol(
                      'Kas Masuk (Nov)',
                      '+Rp 8.400.000',
                      AppColors.incomeEmeraldBright,
                    ),
                    Container(
                      width: 1,
                      height: 28,
                      color: AppColors.heroCardSecondary,
                    ),
                    _buildSummaryCol(
                      'Kas Keluar (Nov)',
                      '-Rp 3.550.000',
                      AppColors.expenseRoseBright,
                    ),
                    Container(
                      width: 1,
                      height: 28,
                      color: AppColors.heroCardSecondary,
                    ),
                    _buildSummaryCol(
                      'Selisih Bersih',
                      '+Rp 4.850.000',
                      Colors.white,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Hari Ini, Rabu 11 Nov 2026',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                  Text(
                    'Hari Ini: +Rp 320.000',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.incomeEmerald,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                  boxShadow: AppColors.cardShadow,
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < filtered.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      _buildHistoryRow(context, filtered[i]),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.go('/laporan'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text('Unduh PDF/Excel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => context.push('/catat-manual'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryTeal,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('+ Catat Transaksi Baru'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: UcapKasBottomNavBar(
        currentIndex: 0,
        onTabSelected: (index) {
          switch (index) {
            case 0:
              context.go('/kas');
            case 1:
              context.go('/nota');
            case 2:
              context.go('/laporan');
            case 3:
              context.go('/akun');
          }
        },
        onBicaraPressed: () => context.push('/bicara'),
      ),
    );
  }

  Widget _buildFilterChip(WidgetRef ref, String key, String label, String current) {
    final active = current == key;
    return GestureDetector(
      onTap: () => ref.read(txFilterCategoryProvider.notifier).state = key,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.heroDark : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: active ? AppColors.heroDark : AppColors.border),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCol(String label, String val, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 9, color: AppColors.darkTextMuted)),
        const SizedBox(height: 3),
        Text(
          val,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryRow(BuildContext context, CashTransaction tx) {
    final isIn = tx.isInflow;
    return ListTile(
      onTap: () => context.push(tx.notaRef != null ? '/detail-nota' : '/ubah-rincian'),
      dense: true,
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isIn ? AppColors.incomeSoft : AppColors.expenseSoft,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Icon(
          isIn ? Icons.south_west_rounded : Icons.north_east_rounded,
          size: 16,
          color: isIn ? AppColors.incomeEmerald : AppColors.expenseRose,
        ),
      ),
      title: Text(
        tx.title,
        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${tx.timeLabel} • ${tx.category} • ${tx.paymentMethod}',
        style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted),
      ),
      trailing: Text(
        RupiahFormatter.format(tx.amount, showSign: true),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: isIn ? AppColors.incomeEmerald : AppColors.expenseRose,
        ),
      ),
    );
  }
}
