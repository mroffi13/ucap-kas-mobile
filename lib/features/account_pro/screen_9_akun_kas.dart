import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/rupiah_formatter.dart';
import '../../core/widgets/pro_badge.dart';
import '../../core/widgets/ucapkas_bottom_nav.dart';
import '../../core/widgets/ucapkas_logo.dart';
import '../../core/widgets/ucapkas_toast.dart';
import '../../core/network/api_client.dart';
import '../../data/models/workspace.dart';
import '../../state/auth_provider.dart';
import '../../state/ledger_providers.dart';

class _TeamMember {
  final String name;
  final String initials;
  final String phoneOrNote;
  final String role;
  final bool isOwner;
  final bool isOnline;

  const _TeamMember({
    required this.name,
    required this.initials,
    required this.phoneOrNote,
    required this.role,
    this.isOwner = false,
    this.isOnline = true,
  });
}

class Screen9AkunKas extends ConsumerStatefulWidget {
  const Screen9AkunKas({super.key});

  @override
  ConsumerState<Screen9AkunKas> createState() => _Screen9AkunKasState();
}

class _Screen9AkunKasState extends ConsumerState<Screen9AkunKas> {
  bool _autoCloudSync = true;
  bool _waAutoReminder = true;

  final List<_TeamMember> _members = [
    const _TeamMember(
      name: 'Pak Hendra Jaya (Anda)',
      initials: 'HJ',
      phoneOrNote: 'Pemilik Usaha · Akses Penuh Semua Kas',
      role: 'Pemilik',
      isOwner: true,
      isOnline: true,
    ),
    const _TeamMember(
      name: 'Rian Pratama',
      initials: 'RP',
      phoneOrNote: 'Kepala Mekanik · Catat Servis & Foto Struk',
      role: 'Kasir & Staf',
      isOwner: false,
      isOnline: true,
    ),
    const _TeamMember(
      name: 'Siti Aminah',
      initials: 'SA',
      phoneOrNote: 'Admin Pembukuan · Kelola Nota & Laporan',
      role: 'Admin',
      isOwner: false,
      isOnline: false,
    ),
  ];

  void _showInviteMemberSheet(BuildContext context, String workspaceName) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String selectedRole = 'Kasir & Staf';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 14, 20, bottomInset + 24),
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
                  Text(
                    'Undang Anggota ke $workspaceName',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Anggota dapat mencatat kas lewat suara atau foto struk dari HP masing-masing.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nama Anggota / Karyawan',
                      hintText: 'Contoh: Mas Dimas',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Nomor WhatsApp',
                      hintText: 'Contoh: 0812-3456-7890',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Hak Akses',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final roleOption in ['Kasir & Staf', 'Admin']) ...[
                        if (roleOption != 'Kasir & Staf')
                          const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setSheetState(
                              () => selectedRole = roleOption,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: selectedRole == roleOption
                                    ? AppColors.primaryTealSoft
                                    : AppColors.background,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: selectedRole == roleOption
                                      ? AppColors.primaryTeal
                                      : AppColors.border,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  roleOption,
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: selectedRole == roleOption
                                        ? AppColors.primaryTeal
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    onPressed: () {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) return;
                      final parts = name.split(' ');
                      final initials = parts.length >= 2
                          ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
                          : name.substring(0, 1).toUpperCase();
                      setState(() {
                        _members.add(
                          _TeamMember(
                            name: name,
                            initials: initials,
                            phoneOrNote: selectedRole == 'Admin'
                                ? 'Admin Pembukuan · Kelola Nota & Laporan'
                                : 'Staf Lapangan · Catat Kas & Foto Struk',
                            role: selectedRole,
                            isOnline: true,
                          ),
                        );
                      });
                      Navigator.of(sheetCtx).pop();
                      UcapKasToast.showInfo(
                        context,
                        headerLabel: 'Undangan Terkirim',
                        title: 'Undangan dikirim ke $name',
                        subtitle: 'Hak akses: $selectedRole · via WhatsApp',
                        badgeText: 'WA',
                      );
                    },
                    icon: const Icon(Icons.send_rounded, size: 16),
                    label: const Text('Kirim Undangan via WhatsApp'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showStarterQuotaSheet(BuildContext context, Workspace currentWs) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
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
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.heroDark,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: AppColors.heroShadow,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.primaryTeal.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.workspace_premium_rounded,
                          size: 22,
                          color: AppColors.incomeEmeraldBright,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Kuota Buku Kas Starter (1/1)',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Upgrade ke Pro untuk membuat hingga 3 Buku Kas terpisah',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                color: AppColors.darkTextMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Pada Paket Starter Gratis, Anda memiliki 1 Buku Kas utama yang bebas diubah nama, fokus pembukuan, maupun rekening banknya kapan saja.\n\nDengan Paket Pro, Anda dapat memisahkan hingga 3 Buku Kas (misal: Kas Bengkel + Kas Dapur Rumah + Kas Tabungan).',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          side: const BorderSide(color: AppColors.borderStrong),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(sheetCtx).pop();
                          _showWorkspaceFormSheet(context, existing: currentWs);
                        },
                        icon: const Icon(Icons.tune_rounded, size: 16),
                        label: Text(
                          'Atur Kas Saat Ini',
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
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryTeal,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(sheetCtx).pop();
                          context.push('/paket-usaha');
                        },
                        icon: const Icon(
                          Icons.workspace_premium_rounded,
                          size: 16,
                        ),
                        label: Text(
                          'Lihat Paket Pro',
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
        );
      },
    );
  }

  static String _autoDeriveShortName(String fullName) {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return 'Kas Utama';
    final words = trimmed.split(RegExp(r'\s+'));
    if (words.length >= 2) {
      final candidate = '${words[0]} ${words[1]}';
      if (candidate.length <= 18) return candidate;
    }
    return trimmed.length > 16 ? trimmed.substring(0, 16) : trimmed;
  }

  void _showWorkspaceFormSheet(BuildContext context, {Workspace? existing}) {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final shortCtrl = TextEditingController(text: existing?.shortName ?? '');
    final bankNameCtrl = TextEditingController(text: existing?.bankName ?? '');
    final bankAccCtrl =
        TextEditingController(text: existing?.bankAccountNumber ?? '');
    final bankHolderCtrl =
        TextEditingController(text: existing?.bankAccountHolder ?? '');
    String focusType = existing?.focusType ?? 'umkm';
    bool isSaving = false;
    String? nameErrorText;

    const focusOptions = [
      ('umkm', 'Usaha / UMKM', Icons.storefront_rounded),
      ('rumah_tangga', 'Rumah Tangga', Icons.home_work_outlined),
      ('komunitas', 'Komunitas', Icons.groups_2_outlined),
    ];

    const presetBanks = [
      'BCA',
      'BRI',
      'Mandiri',
      'BNI',
      'BSI',
      'SeaBank',
      'GoPay',
      'DANA',
    ];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
            final liveName = nameCtrl.text.trim().isEmpty
                ? (focusType == 'rumah_tangga'
                    ? 'Dapur Rumah Tangga'
                    : focusType == 'komunitas'
                        ? 'Kas Komunitas'
                        : 'Usaha Saya (UMKM)')
                : nameCtrl.text.trim();
            final liveShort = shortCtrl.text.trim().isEmpty
                ? _autoDeriveShortName(liveName)
                : shortCtrl.text.trim();
            final liveBankName = bankNameCtrl.text.trim();
            final liveBankAcc = bankAccCtrl.text.trim();
            final liveBankHolder = bankHolderCtrl.text.trim();

            final IconData focusIcon = switch (focusType) {
              'rumah_tangga' => Icons.home_work_outlined,
              'komunitas' => Icons.groups_2_outlined,
              _ => Icons.storefront_rounded,
            };

            return Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.90,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Sticky Top Header Bar
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 12, 16, 14),
                      decoration: const BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                        border: Border(
                          bottom: BorderSide(color: AppColors.border),
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppColors.borderStrong,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryTealSoft,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  isEdit
                                      ? Icons.tune_rounded
                                      : Icons.add_business_rounded,
                                  size: 20,
                                  color: AppColors.primaryTeal,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isEdit
                                          ? 'Pengaturan Buku Kas'
                                          : 'Tambah Buku Kas Baru',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.3,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isEdit
                                          ? 'Sesuaikan identitas kas & rekening tujuan nota WA'
                                          : 'Pisahkan pembukuan usaha, rumah tangga, atau komunitas',
                                      style: GoogleFonts.inter(
                                        fontSize: 11.5,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.of(sheetCtx).pop(),
                                style: IconButton.styleFrom(
                                  backgroundColor: AppColors.surfaceSubtle,
                                  minimumSize: const Size(38, 38),
                                ),
                                icon: const Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // 2. Scrollable Form Body
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // A. Live Preview Card (Dark Executive Preview)
                            Container(
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                color: AppColors.heroDark,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: AppColors.heroShadow,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration: const BoxDecoration(
                                              color:
                                                  AppColors.incomeEmeraldBright,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'PRATINJAU KARTU KAS & NOTA',
                                            style: GoogleFonts.inter(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.6,
                                              color: AppColors.darkTextMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3.5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.heroCardSecondary,
                                          borderRadius:
                                              BorderRadius.circular(99),
                                          border: Border.all(
                                            color: AppColors.darkBorder,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.bookmark_outline_rounded,
                                              size: 11,
                                              color:
                                                  AppColors.primaryTealBright,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              liveShort,
                                              style: GoogleFonts.inter(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 11),
                                  Row(
                                    children: [
                                      Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryTeal
                                              .withValues(alpha: 0.24),
                                          borderRadius:
                                              BorderRadius.circular(11),
                                        ),
                                        child: Icon(
                                          focusIcon,
                                          size: 19,
                                          color: AppColors.incomeEmeraldBright,
                                        ),
                                      ),
                                      const SizedBox(width: 11),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              liveName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style:
                                                  GoogleFonts.plusJakartaSans(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              liveBankName.isNotEmpty ||
                                                      liveBankAcc.isNotEmpty
                                                  ? '${liveBankName.isEmpty ? "Bank" : liveBankName} · ${liveBankAcc.isEmpty ? "No. Rek belum diisi" : liveBankAcc}${liveBankHolder.isNotEmpty ? " a.n. $liveBankHolder" : ""}'
                                                  : 'Rekening tujuan nota WA belum diatur (opsional)',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                color: liveBankName
                                                            .isNotEmpty ||
                                                        liveBankAcc.isNotEmpty
                                                    ? AppColors
                                                        .incomeEmeraldBright
                                                    : AppColors.darkTextMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // B. Section Card 1: Identitas & Fokus Buku Kas
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
                                    children: [
                                      const Icon(
                                        Icons.menu_book_rounded,
                                        size: 16,
                                        color: AppColors.primaryTeal,
                                      ),
                                      const SizedBox(width: 7),
                                      Text(
                                        'Identitas Buku Kas',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // Fokus Pembukuan Selector (3 Icon Cards)
                                  Text(
                                    'Fokus Pembukuan',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      for (int f = 0;
                                          f < focusOptions.length;
                                          f++) ...[
                                        if (f > 0) const SizedBox(width: 8),
                                        Expanded(
                                          child: Builder(
                                            builder: (_) {
                                              final opt = focusOptions[f];
                                              final selected =
                                                  focusType == opt.$1;
                                              return GestureDetector(
                                                onTap: () {
                                                  HapticFeedback
                                                      .selectionClick();
                                                  setSheetState(
                                                    () => focusType = opt.$1,
                                                  );
                                                },
                                                child: AnimatedContainer(
                                                  duration: const Duration(
                                                    milliseconds: 160,
                                                  ),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 8,
                                                    vertical: 10,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: selected
                                                        ? AppColors
                                                            .primaryTealSoft
                                                        : AppColors.background,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      12,
                                                    ),
                                                    border: Border.all(
                                                      color: selected
                                                          ? AppColors
                                                              .primaryTeal
                                                          : AppColors.border,
                                                      width:
                                                          selected ? 1.4 : 1.0,
                                                    ),
                                                  ),
                                                  child: Column(
                                                    children: [
                                                      Icon(
                                                        opt.$3,
                                                        size: 19,
                                                        color: selected
                                                            ? AppColors
                                                                .primaryTeal
                                                            : AppColors
                                                                .textSecondary,
                                                      ),
                                                      const SizedBox(height: 5),
                                                      Text(
                                                        opt.$2,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style:
                                                            GoogleFonts.inter(
                                                          fontSize: 11,
                                                          fontWeight: selected
                                                              ? FontWeight.w700
                                                              : FontWeight.w500,
                                                          color: selected
                                                              ? AppColors
                                                                  .primaryTeal
                                                              : AppColors
                                                                  .textSecondary,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 14),

                                  // Nama Lengkap Buku Kas
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Nama Buku Kas / Nama Usaha',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      Text(
                                        'Wajib',
                                        style: GoogleFonts.inter(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primaryTeal,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: nameCtrl,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    textInputAction: TextInputAction.next,
                                    onChanged: (v) {
                                      setSheetState(() {
                                        if (nameErrorText != null &&
                                            v.trim().isNotEmpty) {
                                          nameErrorText = null;
                                        }
                                      });
                                    },
                                    style: GoogleFonts.inter(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                    decoration: _sheetInputDecoration(
                                      hintText:
                                          'Misal: Bengkel Motor Jaya / Dapur Rumah',
                                      prefixIcon: Icons.storefront_outlined,
                                      errorText: nameErrorText,
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // Nama Pendek di Header
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Nama Pendek (Tampil di Pill Atas)',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      Text(
                                        'Otomatis jika kosong',
                                        style: GoogleFonts.inter(
                                          fontSize: 10.5,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: shortCtrl,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    textInputAction: TextInputAction.next,
                                    inputFormatters: [
                                      LengthLimitingTextInputFormatter(20),
                                    ],
                                    onChanged: (_) => setSheetState(() {}),
                                    style: GoogleFonts.inter(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                    decoration: _sheetInputDecoration(
                                      hintText:
                                          'Misal: ${_autoDeriveShortName(liveName)}',
                                      prefixIcon: Icons.badge_outlined,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // C. Section Card 2: Rekening Bank / E-Wallet (Untuk Kop Nota WA)
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
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.account_balance_outlined,
                                            size: 16,
                                            color: AppColors.primaryTeal,
                                          ),
                                          const SizedBox(width: 7),
                                          Text(
                                            'Rekening Tujuan Nota WA',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceSubtle,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'Opsional',
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Dicantumkan otomatis saat Anda mengirim tagihan/nota ke WhatsApp pelanggan.',
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // Quick-Select Bank Pills
                                  Text(
                                    'Pilih Cepat Bank / E-Wallet',
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 7),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        for (final bank in presetBanks) ...[
                                          Builder(
                                            builder: (_) {
                                              final isBankSelected =
                                                  liveBankName.toUpperCase() ==
                                                      bank.toUpperCase();
                                              return Padding(
                                                padding: const EdgeInsets.only(
                                                  right: 6,
                                                ),
                                                child: GestureDetector(
                                                  onTap: () {
                                                    HapticFeedback
                                                        .selectionClick();
                                                    setSheetState(() {
                                                      bankNameCtrl.value =
                                                          TextEditingValue(
                                                        text: bank,
                                                        selection: TextSelection
                                                            .collapsed(
                                                          offset: bank.length,
                                                        ),
                                                      );
                                                    });
                                                  },
                                                  child: AnimatedContainer(
                                                    duration: const Duration(
                                                      milliseconds: 140,
                                                    ),
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 11,
                                                      vertical: 6,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: isBankSelected
                                                          ? AppColors.heroDark
                                                          : AppColors
                                                              .background,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                        9,
                                                      ),
                                                      border: Border.all(
                                                        color: isBankSelected
                                                            ? AppColors.heroDark
                                                            : AppColors.border,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      bank,
                                                      style: GoogleFonts.inter(
                                                        fontSize: 11.5,
                                                        fontWeight:
                                                            isBankSelected
                                                                ? FontWeight
                                                                    .w700
                                                                : FontWeight
                                                                    .w500,
                                                        color: isBankSelected
                                                            ? Colors.white
                                                            : AppColors
                                                                .textSecondary,
                                                      ),
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
                                  const SizedBox(height: 12),

                                  // Nama Bank / E-Wallet
                                  Text(
                                    'Nama Bank / E-Wallet',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: bankNameCtrl,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    textInputAction: TextInputAction.next,
                                    onChanged: (_) => setSheetState(() {}),
                                    style: GoogleFonts.inter(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                    decoration: _sheetInputDecoration(
                                      hintText:
                                          'Ketik nama bank (misal: BCA, BRI, Mandiri)',
                                      prefixIcon:
                                          Icons.account_balance_rounded,
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // Nomor Rekening
                                  Text(
                                    'Nomor Rekening / Nomor E-Wallet',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: bankAccCtrl,
                                    keyboardType: TextInputType.number,
                                    textInputAction: TextInputAction.next,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                        RegExp(r'[0-9\- ]'),
                                      ),
                                      LengthLimitingTextInputFormatter(32),
                                    ],
                                    onChanged: (_) => setSheetState(() {}),
                                    style: AppTheme.numStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                    decoration: _sheetInputDecoration(
                                      hintText: 'Contoh: 8720192811',
                                      prefixIcon: Icons.credit_card_rounded,
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // Atas Nama Rekening
                                  Text(
                                    'Atas Nama Pemilik Rekening',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: bankHolderCtrl,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    textInputAction: TextInputAction.done,
                                    onChanged: (_) => setSheetState(() {}),
                                    style: GoogleFonts.inter(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                    decoration: _sheetInputDecoration(
                                      hintText: 'Contoh: Budi Santoso',
                                      prefixIcon: Icons.person_outline_rounded,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 3. Sticky Bottom Action Bar
                    Container(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                      decoration: const BoxDecoration(
                        color: AppColors.surface,
                        border: Border(
                          top: BorderSide(color: AppColors.border),
                        ),
                      ),
                      child: SafeArea(
                        top: false,
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.textSecondary,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  side: const BorderSide(
                                    color: AppColors.borderStrong,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                ),
                                onPressed: isSaving
                                    ? null
                                    : () => Navigator.of(sheetCtx).pop(),
                                child: Text(
                                  'Batal',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 5,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryTeal,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                ),
                                onPressed: isSaving
                                    ? null
                                    : () async {
                                        final name = nameCtrl.text.trim();
                                        if (name.isEmpty) {
                                          HapticFeedback.heavyImpact();
                                          setSheetState(() {
                                            nameErrorText =
                                                'Nama Buku Kas tidak boleh kosong';
                                          });
                                          return;
                                        }
                                        final shortName =
                                            shortCtrl.text.trim().isEmpty
                                                ? _autoDeriveShortName(name)
                                                : shortCtrl.text.trim();

                                        final isAuth = ref
                                            .read(authProvider)
                                            .isAuthenticated;
                                        if (!isAuth) {
                                          Navigator.of(sheetCtx).pop();
                                          UcapKasToast.showInfo(
                                            context,
                                            headerLabel: 'Mode Pratinjau',
                                            title: name,
                                            subtitle:
                                                'Masuk Google untuk menyimpan ke Cloud',
                                            badgeText: shortName,
                                          );
                                          return;
                                        }

                                        setSheetState(() => isSaving = true);
                                        try {
                                          final repo = ref
                                              .read(ledgerRepositoryProvider);
                                          final res = isEdit
                                              ? await repo.updateWorkspace(
                                                  workspaceId: existing.id,
                                                  name: name,
                                                  shortName: shortName,
                                                  focusType: focusType,
                                                  bankName:
                                                      bankNameCtrl.text.trim(),
                                                  bankAccountNumber:
                                                      bankAccCtrl.text.trim(),
                                                  bankAccountHolder:
                                                      bankHolderCtrl.text
                                                          .trim(),
                                                )
                                              : await repo.createWorkspace(
                                                  name: name,
                                                  shortName: shortName,
                                                  focusType: focusType,
                                                  bankName:
                                                      bankNameCtrl.text.trim(),
                                                  bankAccountNumber:
                                                      bankAccCtrl.text.trim(),
                                                  bankAccountHolder:
                                                      bankHolderCtrl.text
                                                          .trim(),
                                                );

                                          if (res.workspaces.isNotEmpty) {
                                            ref
                                                .read(authProvider.notifier)
                                                .updateWorkspaces(
                                                  res.workspaces,
                                                );
                                            if (!isEdit) {
                                              ref
                                                  .read(
                                                    activeWorkspaceIndexProvider
                                                        .notifier,
                                                  )
                                                  .state = res.workspaces
                                                      .length -
                                                  1;
                                            }
                                          }
                                          if (sheetCtx.mounted) {
                                            Navigator.of(sheetCtx).pop();
                                          }
                                          if (context.mounted) {
                                            final bankSummary = bankNameCtrl
                                                    .text
                                                    .trim()
                                                    .isNotEmpty
                                                ? '${bankNameCtrl.text.trim()} · ${bankAccCtrl.text.trim()}'
                                                : 'Tersinkron ke Cloud PostgreSQL';
                                            UcapKasToast.showInfo(
                                              context,
                                              headerLabel: isEdit
                                                  ? 'Pengaturan Kas Disimpan'
                                                  : 'Buku Kas Baru Aktif',
                                              title: name,
                                              subtitle: bankSummary,
                                              badgeText: shortName,
                                            );
                                          }
                                        } on ApiException catch (e) {
                                          setSheetState(() => isSaving = false);
                                          if (sheetCtx.mounted) {
                                            Navigator.of(sheetCtx).pop();
                                          }
                                          if (context.mounted) {
                                            UcapKasToast.show(
                                              context,
                                              type: UcapKasToastType.kasKeluar,
                                              headerLabel: 'Gagal Menyimpan',
                                              title: e.message,
                                              amountText: '!',
                                            );
                                          }
                                        } catch (_) {
                                          setSheetState(() => isSaving = false);
                                        }
                                      },
                                icon: isSaving
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.check_circle_outline_rounded,
                                        size: 18,
                                      ),
                                label: Text(
                                  isSaving
                                      ? 'Menyimpan ke Cloud...'
                                      : (isEdit
                                          ? 'Simpan Pengaturan Kas'
                                          : 'Buat Buku Kas Baru'),
                                  style: GoogleFonts.inter(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                  ),
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
            );
          },
        );
      },
    );
  }

  InputDecoration _sheetInputDecoration({
    required String hintText,
    required IconData prefixIcon,
    String? errorText,
  }) {
    return InputDecoration(
      hintText: hintText,
      errorText: errorText,
      hintStyle: GoogleFonts.inter(
        fontSize: 12.5,
        fontWeight: FontWeight.w400,
        color: AppColors.textMuted,
      ),
      prefixIcon: Icon(
        prefixIcon,
        size: 18,
        color: AppColors.textSecondary,
      ),
      isDense: true,
      filled: true,
      fillColor: AppColors.background,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: AppColors.primaryTeal,
          width: 1.4,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: AppColors.expenseRose,
          width: 1.2,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: AppColors.expenseRose,
          width: 1.4,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final authUser = authState.user;
    final workspaces = ref.watch(workspacesProvider);
    final activeIdx = ref
        .watch(activeWorkspaceIndexProvider)
        .clamp(0, workspaces.length - 1);
    final activeWs = workspaces[activeIdx];
    final txs = ref.watch(transactionsProvider);

    // Compute live net delta from recorded transactions for the first workspace
    int txDelta = 0;
    for (final tx in txs) {
      txDelta += tx.amount;
    }
    const seededDelta = 450000 - 180000 - 45000 + 95000 + 1250000 - 320000;

    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
          children: [
            // 1. Page Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Akun & Kas Bersama',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Kelola profil usaha, buku kas, dan akses tim',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const ProBadge(label: 'Paket Usaha Aktif'),
              ],
            ),
            const SizedBox(height: 14),

            // 2. Owner Profile & Active Plan Card (Dark Slate Executive Card)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.heroDark,
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppColors.heroShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.primaryTeal,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.16),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          authUser != null ? authUser.initials : 'HJ',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    authUser != null
                                        ? authUser.fullName
                                        : 'Hendra Jaya',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.verified_rounded,
                                  size: 15,
                                  color: AppColors.incomeEmeraldBright,
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              authUser != null
                                  ? '${authUser.email} · Terhubung ke Google'
                                  : 'Mode Pratinjau · Masuk Google untuk simpan ke Cloud',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                color: AppColors.darkTextMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: () => context.push('/paket-usaha'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.heroCardSecondary,
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: AppColors.darkBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.primaryTeal.withValues(
                                alpha: 0.22,
                              ),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: const Icon(
                              Icons.workspace_premium_rounded,
                              size: 17,
                              color: AppColors.incomeEmeraldBright,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  authUser != null
                                      ? authUser.planLabel
                                      : 'Paket Usaha Tahunan · Aktif s/d Nov 2027',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Suara tanpa batas, OCR struk & 5 anggota tim',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: AppColors.darkTextMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Kelola',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.incomeEmeraldBright,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 16,
                            color: AppColors.incomeEmeraldBright,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 3. Multi-Workspace Switcher ("Pilih Buku Kas Aktif")
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'Pilih Buku Kas Aktif (${workspaces.length}/${(authUser?.isPro ?? true) ? 3 : 1})',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  key: const Key('btn_add_workspace'),
                  onTap: () {
                    final isProUser = authUser?.isPro ?? false;
                    final maxQuota = isProUser ? 3 : 1;
                    if (authState.isAuthenticated &&
                        workspaces.length >= maxQuota) {
                      if (!isProUser) {
                        _showStarterQuotaSheet(context, activeWs);
                      } else {
                        UcapKasToast.showInfo(
                          context,
                          headerLabel: 'Kuota Buku Kas Penuh',
                          title: 'Maksimal 3 Buku Kas telah tercapai',
                          subtitle: 'Paket Pro mendukung hingga 3 Buku Kas aktif',
                          badgeText: '3/3',
                        );
                      }
                      return;
                    }
                    _showWorkspaceFormSheet(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryTealSoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '+ Tambah Kas',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryTeal,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (int i = 0; i < workspaces.length; i++) ...[
              Builder(
                builder: (context) {
                  final ws = workspaces[i];
                  final isSelected = i == activeIdx;
                  final displayBalance = authState.isAuthenticated
                      ? ws.balance
                      : (i == 0
                          ? ws.balance + (txDelta - seededDelta)
                          : ws.balance);
                  final isBusiness =
                      ws.id == 'ws-bengkel' || ws.focusType == 'umkm';

                  return GestureDetector(
                    key: ValueKey('workspace_card_${ws.id}'),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      ref.read(activeWorkspaceIndexProvider.notifier).state = i;
                      UcapKasToast.showInfo(
                        context,
                        headerLabel: 'Buku Kas Aktif',
                        title: ws.name,
                        subtitle:
                            'Saldo: ${RupiahFormatter.format(displayBalance)}',
                        badgeText: ws.shortName,
                        duration: const Duration(milliseconds: 1600),
                      );
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primaryTeal
                              : AppColors.border,
                          width: isSelected ? 1.6 : 1.0,
                        ),
                        boxShadow: AppColors.cardShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primaryTealSoft
                                      : AppColors.surfaceSubtle,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  ws.focusType == 'komunitas'
                                      ? Icons.groups_2_outlined
                                      : isBusiness
                                          ? Icons.storefront_rounded
                                          : Icons.home_work_outlined,
                                  size: 20,
                                  color: isSelected
                                      ? AppColors.primaryTeal
                                      : AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      ws.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Saldo Kas: ${RupiahFormatter.format(displayBalance)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTheme.numStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: isSelected
                                            ? AppColors.primaryTeal
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primaryTeal
                                      : AppColors.surfaceSubtle,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isSelected) ...[
                                      const Icon(
                                        Icons.check_rounded,
                                        size: 13,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 3),
                                    ],
                                    Text(
                                      isSelected ? 'Aktif' : 'Pilih',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? Colors.white
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Divider(height: 1, color: AppColors.border),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Icon(
                                      ws.bankName.isNotEmpty
                                          ? Icons.account_balance_outlined
                                          : Icons.info_outline_rounded,
                                      size: 14,
                                      color: ws.bankName.isNotEmpty
                                          ? AppColors.primaryTeal
                                          : AppColors.textMuted,
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        ws.bankName.isNotEmpty
                                            ? '${ws.bankName} · ${ws.bankAccountNumber}${ws.bankAccountHolder.isNotEmpty ? " a.n. ${ws.bankAccountHolder}" : ""}'
                                            : 'Rekening nota WA belum diatur',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          fontSize: 11.5,
                                          fontWeight: ws.bankName.isNotEmpty
                                              ? FontWeight.w600
                                              : FontWeight.w500,
                                          color: ws.bankName.isNotEmpty
                                              ? AppColors.textSecondary
                                              : AppColors.textMuted,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                key: ValueKey('btn_edit_workspace_${ws.id}'),
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  _showWorkspaceFormSheet(
                                    context,
                                    existing: ws,
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.background,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppColors.borderStrong,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.tune_rounded,
                                        size: 13.5,
                                        color: AppColors.textPrimary,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        'Atur Kas',
                                        style: GoogleFonts.inter(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
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
              const SizedBox(height: 10),
            ],

            // 4. Team Members Section ("Anggota Kas Bersama")
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'Anggota ${activeWs.shortName} (${_members.length}/5)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _showInviteMemberSheet(context, activeWs.shortName),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryTealSoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '+ Undang via WA',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryTeal,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
                boxShadow: AppColors.cardShadow,
              ),
              child: Column(
                children: [
                  for (int i = 0; i < _members.length; i++) ...[
                    if (i > 0)
                      const Divider(height: 20, color: AppColors.border),
                    _buildMemberRow(_members[i]),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 5. Preferences & Cloud Backup Section
            Text(
              'Pengaturan Pembukuan & Suara',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
                boxShadow: AppColors.cardShadow,
              ),
              child: Column(
                children: [
                  _buildSwitchSettingRow(
                    icon: Icons.cloud_done_outlined,
                    title: 'Cadangan Otomatis (Cloud)',
                    subtitle: 'Tersinkron real-time ke akun Google Anda',
                    value: _autoCloudSync,
                    onChanged: (v) => setState(() => _autoCloudSync = v),
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  _buildSwitchSettingRow(
                    icon: Icons.mark_chat_unread_outlined,
                    title: 'Pengingat Tagihan WA Otomatis',
                    subtitle: 'Ingatkan pelanggan H-1 sebelum jatuh tempo',
                    value: _waAutoReminder,
                    onChanged: (v) => setState(() => _waAutoReminder = v),
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  _buildActionSettingRow(
                    icon: Icons.record_voice_over_outlined,
                    title: 'Kamus Suara Bahasa Pasar',
                    trailingLabel: 'Aktif (ID)',
                    isLast: true,
                    onTap: () {
                      UcapKasToast.showInfo(
                        context,
                        headerLabel: 'Kamus Suara Aktif',
                        title: 'Mengenali bahasa pasar otomatis',
                        subtitle: 'ceban, gocap, seket, juta, ribu',
                        badgeText: 'ID',
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 6. Sign Out / Switch Account Button
            OutlinedButton.icon(
              key: const Key('btn_logout_account'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.expenseRose,
                backgroundColor: AppColors.surface,
                padding: const EdgeInsets.symmetric(vertical: 13),
                side: BorderSide(
                  color: AppColors.expenseRose.withValues(alpha: 0.35),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () async {
                await ref.read(authProvider.notifier).signOut();
                ref.read(activeWorkspaceIndexProvider.notifier).state = 0;
                if (context.mounted) {
                  context.go('/onboarding');
                }
              },
              icon: const Icon(Icons.logout_rounded, size: 17),
              label: Text(
                'Keluar / Ganti Akun Usaha',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 18),

            // 7. App Version & Build Info Footer
            Center(
              child: GestureDetector(
                key: const Key('app_version_footer'),
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticFeedback.selectionClick();
                  UcapKasToast.showInfo(
                    context,
                    headerLabel: 'Informasi Aplikasi',
                    title: 'UcapKas v1.0.0 (Build 1)',
                    subtitle: 'Nordic Ledger Engine • Versi Terbaru',
                    badgeText: 'v1.0.0',
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                  child: Column(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const UcapKasLogo(
                            size: 18,
                            showWordmark: false,
                          ),
                          const SizedBox(width: 7),
                          Text(
                            'UcapKas Versi 1.0.0 (Build 1)',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Buku Kas Suara & Nota WA • Sudah Versi Terbaru',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar:
          const UcapKasBottomNavBar(activeTab: UcapKasTab.akun),
    );
  }

  Widget _buildMemberRow(_TeamMember member) {
    return Row(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: member.isOwner
                    ? AppColors.primaryTealSoft
                    : AppColors.surfaceSubtle,
                borderRadius: BorderRadius.circular(11),
              ),
              alignment: Alignment.center,
              child: Text(
                member.initials,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: member.isOwner
                      ? AppColors.primaryTeal
                      : AppColors.textSecondary,
                ),
              ),
            ),
            if (member.isOnline)
              Positioned(
                right: -1,
                bottom: -1,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppColors.incomeEmerald,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface, width: 1.8),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                member.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                member.phoneOrNote,
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: member.isOwner
                ? AppColors.primaryTealSoft
                : AppColors.surfaceSubtle,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            member.role,
            style: GoogleFonts.inter(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: member.isOwner
                  ? AppColors.primaryTeal
                  : AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchSettingRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 1.5),
                Text(
                  subtitle,
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
          Switch.adaptive(
            value: value,
            activeTrackColor: AppColors.primaryTeal,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildActionSettingRow({
    required IconData icon,
    required String title,
    required String trailingLabel,
    required VoidCallback onTap,
    bool isLast = true,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: isLast
          ? const BorderRadius.vertical(bottom: Radius.circular(18))
          : BorderRadius.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.surfaceSubtle,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: AppColors.textSecondary),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              trailingLabel,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryTeal,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
