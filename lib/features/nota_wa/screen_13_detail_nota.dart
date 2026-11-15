import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/invoice_pdf_generator.dart';
import '../../core/utils/native_file_saver.dart';
import '../../core/utils/rupiah_formatter.dart';
import '../../core/widgets/ucapkas_toast.dart';
import '../../data/models/cash_transaction.dart';
import '../../data/models/nota_invoice.dart';
import '../../data/models/workspace.dart';
import '../../state/auth_provider.dart';
import '../../state/ledger_providers.dart';

class Screen13DetailNota extends ConsumerStatefulWidget {
  const Screen13DetailNota({super.key});

  @override
  ConsumerState<Screen13DetailNota> createState() => _Screen13DetailNotaState();
}

class _Screen13DetailNotaState extends ConsumerState<Screen13DetailNota> {
  bool _isDownloadingPdf = false;
  SavedPdfResult? _lastSavedPdf;

  Future<SavedPdfResult?> _prepareAndSavePdf({
    required NotaInvoice nota,
    required Workspace ws,
  }) async {
    setState(() => _isDownloadingPdf = true);
    try {
      Uint8List pdfBytes;
      final safeNumber = nota.number
          .replaceAll('/', '-')
          .replaceAll('\\', '-')
          .replaceAll(' ', '_');
      final filename = '$safeNumber.pdf';

      final isAuth = ref.read(authProvider).isAuthenticated;
      if (isAuth && ws.id.isNotEmpty && nota.id.isNotEmpty) {
        try {
          pdfBytes = await ref
              .read(invoiceRepositoryProvider)
              .downloadInvoicePdf(
                workspaceId: ws.id,
                invoiceId: nota.id,
              );
        } catch (_) {
          final generated = InvoicePdfGenerator.generate(
            nota: nota,
            workspace: ws,
          );
          pdfBytes = generated.bytes;
        }
      } else {
        final generated = InvoicePdfGenerator.generate(
          nota: nota,
          workspace: ws,
        );
        pdfBytes = generated.bytes;
      }

      final saved = await NativeFileSaver.savePdf(
        bytes: pdfBytes,
        filename: filename,
      );
      if (mounted) {
        setState(() => _lastSavedPdf = saved);
      }
      return saved;
    } finally {
      if (mounted) {
        setState(() => _isDownloadingPdf = false);
      }
    }
  }

  Future<void> _handleDownloadPdf({
    required NotaInvoice nota,
    required Workspace ws,
    required String waMessage,
  }) async {
    if (_isDownloadingPdf) return;
    HapticFeedback.lightImpact();

    try {
      final saved = await _prepareAndSavePdf(nota: nota, ws: ws);
      if (!mounted || saved == null) return;

      _showPdfSavedSheet(
        context: context,
        nota: nota,
        saved: saved,
        waMessage: waMessage,
      );
    } catch (e) {
      if (!mounted) return;
      UcapKasToast.showInfo(
        context,
        headerLabel: 'Gagal Mengunduh PDF',
        title: nota.number,
        subtitle: e.toString(),
        badgeText: 'ERR',
      );
    }
  }

  Future<void> _handleShareViaWhatsApp({
    required NotaInvoice nota,
    required Workspace ws,
    required String waMessage,
  }) async {
    if (_isDownloadingPdf) return;
    HapticFeedback.lightImpact();

    final saved = _lastSavedPdf ??
        await _prepareAndSavePdf(
          nota: nota,
          ws: ws,
        );
    if (!mounted) return;

    if (saved != null) {
      final shared = await NativeFileSaver.sharePdf(
        saved: saved,
        text: waMessage,
        title: 'Kirim ${nota.number} ke WhatsApp',
      );
      if (shared) return;
    }

    await Clipboard.setData(ClipboardData(text: waMessage));
    if (!mounted) return;
    UcapKasToast.showInfo(
      context,
      headerLabel: 'Siap Dikirim ke WhatsApp',
      title: '${nota.number} · ${nota.clientName}',
      subtitle: 'Pesan tagihan & PDF siap dibagikan ke pelanggan',
      badgeText: 'WA',
    );
  }

  void _showPdfSavedSheet({
    required BuildContext context,
    required NotaInvoice nota,
    required SavedPdfResult saved,
    required String waMessage,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderStrong,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.incomeSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.picture_as_pdf_rounded,
                        color: AppColors.primaryTeal,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Invoice PDF Berhasil Diunduh',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${nota.number} · ${nota.clientName}',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.folder_outlined,
                        size: 16,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          saved.displayLocation,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.numStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.of(sheetCtx).pop();
                          final opened = await NativeFileSaver.openPdf(saved);
                          if (!opened && context.mounted) {
                            UcapKasToast.showInfo(
                              context,
                              headerLabel: 'File PDF Tersimpan',
                              title: saved.displayLocation,
                              subtitle:
                                  'Buka melalui aplikasi File Manager / Downloads',
                              badgeText: 'PDF',
                            );
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: const BorderSide(color: AppColors.borderStrong),
                          minimumSize: const Size.fromHeight(46),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.open_in_new_rounded, size: 16),
                        label: Text(
                          'Buka PDF',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.of(sheetCtx).pop();
                          final shared = await NativeFileSaver.sharePdf(
                            saved: saved,
                            text: waMessage,
                            title: 'Kirim ${nota.number} via WhatsApp',
                          );
                          if (!shared && context.mounted) {
                            UcapKasToast.showInfo(
                              context,
                              headerLabel: 'PDF Siap Dibagikan',
                              title: saved.displayLocation,
                              subtitle: 'Lampirkan file PDF ke chat WhatsApp',
                              badgeText: 'WA',
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryTeal,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          minimumSize: const Size.fromHeight(46),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.share_rounded, size: 16),
                        label: Text(
                          'Bagikan / WA',
                          style: GoogleFonts.inter(
                            fontSize: 13,
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final nota = ref.watch(selectedNotaProvider);
    final ws = ref.watch(activeWorkspaceProvider);
    final isPaid = nota.status == NotaStatus.lunas;

    final (Color badgeBg, Color badgeFg, String badgeText) =
        switch (nota.status) {
      NotaStatus.jatuhTempo => (
          AppColors.expenseSoft,
          AppColors.expenseRose,
          'Lewat Jatuh Tempo',
        ),
      NotaStatus.menunggu => (
          AppColors.warningSoft,
          AppColors.warningAmber,
          'Menunggu Pembayaran',
        ),
      NotaStatus.lunas => (
          AppColors.incomeSoft,
          AppColors.incomeEmerald,
          'Lunas',
        ),
    };

    final displayItems = nota.items.isNotEmpty
        ? nota.items
        : [
            TransactionLineItem(
              name: nota.clientName,
              quantity: 1,
              unitPrice: nota.amount,
            ),
          ];

    final waMessage = isPaid
        ? 'Halo ${nota.clientName.split("—").first.trim()}, berikut bukti pelunasan ${nota.number} dari ${ws.shortName} sebesar ${RupiahFormatter.format(nota.amount)}. Terima kasih atas kerja samanya.'
        : 'Halo ${nota.clientName.split("—").first.trim()}, izin mengirimkan rincian tagihan ${nota.number} dari ${ws.shortName} sebesar ${RupiahFormatter.format(nota.amount)} (${nota.dueDateLabel}). Pembayaran dapat melalui transfer atau QRIS toko. Terima kasih.';

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
          'Rincian Invoice',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: TextButton.icon(
              onPressed: _isDownloadingPdf
                  ? null
                  : () => _handleDownloadPdf(
                        nota: nota,
                        ws: ws,
                        waMessage: waMessage,
                      ),
              icon: _isDownloadingPdf
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primaryTeal,
                      ),
                    )
                  : const Icon(
                      Icons.download_rounded,
                      size: 16,
                      color: AppColors.primaryTeal,
                    ),
              label: Text(
                _isDownloadingPdf ? 'Mengunduh...' : 'Unduh PDF',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryTeal,
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 32),
        children: [
          // 1. Printable Digital Invoice Sheet Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
              boxShadow: AppColors.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Invoice Header: Usaha & Status Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ws.name,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Dokumen ${nota.number}',
                            style: AppTheme.numStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4.5,
                      ),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        badgeText,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: badgeFg,
                        ),
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(height: 1, color: AppColors.border),
                ),

                // Recipient & Dates Metadata
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ditagihkan Kepada',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            nota.clientName,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            nota.clientContact,
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Batas Pembayaran',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          nota.dueDateLabel,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: nota.status == NotaStatus.jatuhTempo
                                ? AppColors.expenseRose
                                : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Terbit: ${nota.dateIssued}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(height: 1, color: AppColors.border),
                ),

                // Line Items Table Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Rincian Barang / Jasa',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                    Text(
                      'Subtotal',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Line Items
                for (int i = 0; i < displayItems.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _buildLineItemRow(displayItems[i]),
                ],

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(height: 1, color: AppColors.border),
                ),

                // Grand Total Box
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          'Total Tagihan Invoice',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        RupiahFormatter.format(nota.amount),
                        style: AppTheme.numStyle(
                          fontSize: 20,
                          color: isPaid
                              ? AppColors.incomeEmerald
                              : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 2. Pratinjau Pesan WhatsApp
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
              boxShadow: AppColors.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Pesan Pengantar WhatsApp',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: waMessage));
                        UcapKasToast.showInfo(
                          context,
                          headerLabel: 'Teks Disalin',
                          title: 'Pesan pengantar WhatsApp disalin',
                          subtitle: 'Siap ditempel di chat pelanggan',
                          badgeText: 'WA',
                        );
                      },
                      child: Text(
                        'Salin Teks',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryTeal,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    waMessage,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      height: 1.45,
                      color: AppColors.textSecondary,
                    ),
                  ),
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
          child: isPaid
              ? ElevatedButton.icon(
                  onPressed: () => _handleShareViaWhatsApp(
                    nota: nota,
                    ws: ws,
                    waMessage: waMessage,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryTeal,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: Text(
                    'Kirim Bukti Lunas via WhatsApp',
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              : Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: OutlinedButton(
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          ref
                              .read(notaListProvider.notifier)
                              .markAsPaid(
                                nota.id.isNotEmpty ? nota.id : nota.number,
                              );
                          context.go('/nota');
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: const BorderSide(color: AppColors.borderStrong),
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Tandai Lunas',
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
                      child: ElevatedButton.icon(
                        onPressed: () => _handleShareViaWhatsApp(
                          nota: nota,
                          ws: ws,
                          waMessage: waMessage,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.heroDark,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.send_rounded, size: 16),
                        label: Text(
                          'Kirim via WhatsApp',
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
  }

  Widget _buildLineItemRow(TransactionLineItem item) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${item.quantity}x @ ${RupiahFormatter.format(item.unitPrice)}',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          RupiahFormatter.format(item.subtotal),
          style: AppTheme.numStyle(
            fontSize: 13.5,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
