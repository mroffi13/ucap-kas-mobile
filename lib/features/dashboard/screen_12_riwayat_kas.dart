import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/rupiah_formatter.dart';
import '../../core/widgets/ucapkas_bottom_nav.dart';
import '../../core/widgets/workspace_pill.dart';
import '../../data/models/cash_transaction.dart';
import '../../state/ledger_providers.dart';

class Screen12RiwayatKas extends ConsumerStatefulWidget {
  const Screen12RiwayatKas({super.key});

  @override
  ConsumerState<Screen12RiwayatKas> createState() => _Screen12RiwayatKasState();
}

class _Screen12RiwayatKasState extends ConsumerState<Screen12RiwayatKas> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    final initialQuery = ref.read(txSearchQueryProvider);
    _searchController = TextEditingController(text: initialQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _resetSearchAndFilter() {
    HapticFeedback.selectionClick();
    _searchController.clear();
    ref.read(txSearchQueryProvider.notifier).state = '';
    ref.read(txFilterCategoryProvider.notifier).state = 'Semua';
  }

  void _showTransactionDetailSheet(BuildContext context, CashTransaction tx) {
    final isIn = tx.isInflow;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderStrong,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4.5,
                    ),
                    decoration: BoxDecoration(
                      color: isIn ? AppColors.incomeSoft : AppColors.expenseSoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isIn ? 'KAS MASUK' : 'KAS KELUAR',
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        color: isIn
                            ? AppColors.incomeEmerald
                            : AppColors.expenseRose,
                      ),
                    ),
                  ),
                  Text(
                    'Pukul ${tx.timeLabel} WIB',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                tx.title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                RupiahFormatter.format(tx.amount, showSign: true),
                style: AppTheme.numStyle(
                  fontSize: 26,
                  color: isIn ? AppColors.incomeEmerald : AppColors.expenseRose,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    _buildDetailMetaRow('Kategori Kas', tx.category),
                    const Divider(height: 18, color: AppColors.border),
                    _buildDetailMetaRow('Metode Pembayaran', tx.paymentMethod),
                    if (tx.customerName != null) ...[
                      const Divider(height: 18, color: AppColors.border),
                      _buildDetailMetaRow('Catatan / Petugas', tx.customerName!),
                    ],
                    if (tx.notaRef != null) ...[
                      const Divider(height: 18, color: AppColors.border),
                      _buildDetailMetaRow('Referensi Tagihan', tx.notaRef!),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        side: const BorderSide(color: AppColors.borderStrong),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(sheetCtx).pop();
                        context.push('/ubah-rincian');
                      },
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Ubah Rincian'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryTeal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(sheetCtx).pop();
                        if (tx.notaRef != null) {
                          context.push('/detail-nota');
                        } else {
                          context.push('/catat-manual');
                        }
                      },
                      icon: Icon(
                        tx.notaRef != null
                            ? Icons.receipt_long_outlined
                            : Icons.add_rounded,
                        size: 16,
                      ),
                      label: Text(
                        tx.notaRef != null ? 'Lihat Nota' : 'Catat Serupa',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailMetaRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ws = ref.watch(activeWorkspaceProvider);
    final query = ref.watch(txSearchQueryProvider).trim().toLowerCase();
    final filter = ref.watch(txFilterCategoryProvider);
    final allTxs = ref.watch(transactionsProvider);

    // Compute dynamic counts for each filter chip
    final inflowCount = allTxs.where((tx) => tx.isInflow).length;
    final outflowCount = allTxs.where((tx) => !tx.isInflow).length;
    final qrisCount = allTxs
        .where((tx) => tx.paymentMethod.toUpperCase().contains('QRIS'))
        .length;
    final tunaiCount = allTxs
        .where((tx) => tx.paymentMethod.toUpperCase().contains('TUNAI'))
        .length;

    // Filter transactions by search query and active chip
    final filtered = allTxs.where((tx) {
      final matchesQuery = query.isEmpty ||
          tx.title.toLowerCase().contains(query) ||
          tx.category.toLowerCase().contains(query) ||
          tx.paymentMethod.toLowerCase().contains(query) ||
          (tx.customerName?.toLowerCase().contains(query) ?? false);
      final matchesFilter = switch (filter) {
        'Kas Masuk' => tx.isInflow,
        'Kas Keluar' => !tx.isInflow,
        'QRIS' => tx.paymentMethod.toUpperCase().contains('QRIS'),
        'Tunai' => tx.paymentMethod.toUpperCase().contains('TUNAI'),
        _ => true,
      };
      return matchesQuery && matchesFilter;
    }).toList();

    // Live totals across the filtered view (or monthly workspace baseline)
    int filteredInflow = 0;
    int filteredOutflow = 0;
    for (final tx in filtered) {
      if (tx.isInflow) {
        filteredInflow += tx.amount;
      } else {
        filteredOutflow += tx.amount.abs();
      }
    }
    final filteredNet = filteredInflow - filteredOutflow;

    // Group filtered transactions by dateGroup preserving chronological order
    final Map<String, List<CashTransaction>> groupedByDate = {};
    for (final tx in filtered) {
      groupedByDate.putIfAbsent(tx.dateGroup, () => []).add(tx);
    }
    final dateKeys = groupedByDate.keys.toList();

    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 118),
          children: [
            // 1. Top Navigation & Active Workspace Pill
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => context.go('/kas'),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Icon(
                            Icons.arrow_back_rounded,
                            size: 18,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Riwayat Buku Kas',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 18.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.4,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                '${allTxs.length} catatan tersimpan · Nov 2026',
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
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                WorkspacePill(
                  label: ws.shortName,
                  onTap: () => context.go('/akun'),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 2. Dark Executive Cashflow Summary Card (Reactive to Filter & Search)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.heroDark,
                borderRadius: BorderRadius.circular(18),
                boxShadow: AppColors.heroShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          query.isEmpty && filter == 'Semua'
                              ? 'Ringkasan Mutasi Kas (${filtered.length} Catatan)'
                              : 'Hasil Filter: $filter (${filtered.length} Catatan)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.darkTextMuted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        RupiahFormatter.format(filteredNet, showSign: true),
                        style: AppTheme.numStyle(
                          fontSize: 14,
                          color: filteredNet >= 0
                              ? AppColors.incomeEmeraldBright
                              : AppColors.expenseRoseBright,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.heroCardSecondary,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.darkBorder),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildSummaryCol(
                            label: 'Total Kas Masuk',
                            val: '+${RupiahFormatter.format(filteredInflow)}',
                            color: AppColors.incomeEmeraldBright,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 28,
                          color: AppColors.darkBorder,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildSummaryCol(
                            label: 'Total Kas Keluar',
                            val: '-${RupiahFormatter.format(filteredOutflow)}',
                            color: AppColors.expenseRoseBright,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 3. Search Field with Clear Button
            TextField(
              controller: _searchController,
              onChanged: (val) =>
                  ref.read(txSearchQueryProvider.notifier).state = val,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Cari nama transaksi, kategori, atau metode bayar...',
                hintStyle: GoogleFonts.inter(
                  fontSize: 12.5,
                  color: AppColors.textMuted,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 19,
                  color: AppColors.textSecondary,
                ),
                suffixIcon: query.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchController.clear();
                          ref.read(txSearchQueryProvider.notifier).state = '';
                        },
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 17,
                          color: AppColors.textSecondary,
                        ),
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // 4. Filter Chips with Live Counts
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(
                    key: 'Semua',
                    label: 'Semua (${allTxs.length})',
                    current: filter,
                  ),
                  const SizedBox(width: 6),
                  _buildFilterChip(
                    key: 'Kas Masuk',
                    label: 'Kas Masuk ($inflowCount)',
                    current: filter,
                  ),
                  const SizedBox(width: 6),
                  _buildFilterChip(
                    key: 'Kas Keluar',
                    label: 'Kas Keluar ($outflowCount)',
                    current: filter,
                  ),
                  const SizedBox(width: 6),
                  _buildFilterChip(
                    key: 'QRIS',
                    label: 'QRIS ($qrisCount)',
                    current: filter,
                  ),
                  const SizedBox(width: 6),
                  _buildFilterChip(
                    key: 'Tunai',
                    label: 'Tunai ($tunaiCount)',
                    current: filter,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 5. Grouped Daily Ledger Sections (or Helpful Empty State)
            if (filtered.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 28,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSubtle,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.search_off_rounded,
                        size: 24,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Tidak ada transaksi yang cocok',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Coba kata kunci lain (misal: servis, oli, kampas) atau tampilkan semua kategori.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: _resetSearchAndFilter,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Reset Pencarian & Filter'),
                    ),
                  ],
                ),
              )
            else
              for (int g = 0; g < dateKeys.length; g++) ...[
                if (g > 0) const SizedBox(height: 14),
                Builder(
                  builder: (context) {
                    final groupKey = dateKeys[g];
                    final groupItems = groupedByDate[groupKey]!;
                    int daySubtotal = 0;
                    for (final item in groupItems) {
                      daySubtotal += item.amount;
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  groupKey,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                RupiahFormatter.format(
                                  daySubtotal,
                                  showSign: true,
                                ),
                                style: AppTheme.numStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: daySubtotal >= 0
                                      ? AppColors.incomeEmerald
                                      : AppColors.expenseRose,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 7),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                            boxShadow: AppColors.cardShadow,
                          ),
                          child: Column(
                            children: [
                              for (int i = 0; i < groupItems.length; i++) ...[
                                if (i > 0)
                                  const Divider(
                                    height: 1,
                                    indent: 58,
                                    endIndent: 14,
                                    color: AppColors.border,
                                  ),
                                _buildHistoryRow(context, groupItems[i]),
                              ],
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],

            const SizedBox(height: 16),

            // 6. Bottom Quick Actions (Export Report & Add Transaction)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.go('/laporan'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      backgroundColor: AppColors.surface,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      side: const BorderSide(color: AppColors.borderStrong),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.bar_chart_rounded, size: 17),
                    label: Text(
                      'Lihat Laporan',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => context.push('/catat-manual'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryTeal,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 17),
                    label: Text(
                      'Catat Kas Baru',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: const UcapKasBottomNavBar(currentIndex: 0),
    );
  }

  Widget _buildFilterChip({
    required String key,
    required String label,
    required String current,
  }) {
    final active = current == key;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        ref.read(txFilterCategoryProvider.notifier).state = key;
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppColors.heroDark : AppColors.surface,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: active ? AppColors.heroDark : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCol({
    required String label,
    required String val,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontSize: 10.5,
            color: AppColors.darkTextMuted,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          val,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTheme.numStyle(
            fontSize: 13.5,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryRow(BuildContext context, CashTransaction tx) {
    final isIn = tx.isInflow;
    return InkWell(
      key: ValueKey('history_row_${tx.id}'),
      onTap: () {
        HapticFeedback.selectionClick();
        _showTransactionDetailSheet(context, tx);
      },
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isIn ? AppColors.incomeSoft : AppColors.expenseSoft,
                borderRadius: BorderRadius.circular(11),
              ),
              alignment: Alignment.center,
              child: Icon(
                isIn ? Icons.south_west_rounded : Icons.north_east_rounded,
                size: 17,
                color: isIn ? AppColors.incomeEmerald : AppColors.expenseRose,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '${tx.timeLabel} · ${tx.category}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          tx.paymentMethod,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      if (tx.hasReceiptPhoto)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryTealSoft,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            'Foto Struk',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryTeal,
                            ),
                          ),
                        ),
                      if (tx.notaRef != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryTealSoft,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            tx.notaRef!,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryTeal,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              RupiahFormatter.format(tx.amount, showSign: true),
              style: AppTheme.numStyle(
                fontSize: 13.5,
                color: isIn ? AppColors.incomeEmerald : AppColors.expenseRose,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
