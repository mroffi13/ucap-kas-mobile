import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/native_file_saver.dart';
import '../../core/utils/rupiah_formatter.dart';
import '../../core/widgets/pro_badge.dart';
import '../../core/widgets/ucapkas_bottom_nav.dart';
import '../../core/widgets/ucapkas_logo.dart';
import '../../core/widgets/ucapkas_toast.dart';
import '../../core/network/api_client.dart';
import '../../data/models/workspace.dart';
import '../../data/repositories/ledger_repository.dart';
import '../../state/auth_provider.dart';
import '../../state/ledger_providers.dart';

class _TeamMember {
  final String userId;
  final String name;
  final String initials;
  final String avatarUrl;
  final String phoneOrNote;
  final String role;
  final bool isOwner;
  final bool isOnline;

  const _TeamMember({
    this.userId = '',
    required this.name,
    required this.initials,
    this.avatarUrl = '',
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
  bool _isLoadingWorkspaceMeta = false;
  String _loadedWorkspaceId = '';
  int _maxMembers = 2;
  WorkspaceInviteModel? _activeInvite;
  List<WorkspaceActivityLogModel> _activityLogs = const [];
  bool _hasMoreActivityLogs = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (!mounted) return;
      if (ref.read(authProvider).isAuthenticated) {
        await ref.read(authProvider.notifier).refreshProfile();
        if (mounted) {
          final ws = ref.read(activeWorkspaceProvider);
          await _loadMembersAndActivityLogs(ws);
        }
      }
    });
  }

  Future<void> _loadMembersAndActivityLogs(Workspace ws) async {
    if (!mounted || !ref.read(authProvider).isAuthenticated || ws.id.isEmpty) {
      return;
    }
    setState(() {
      _isLoadingWorkspaceMeta = true;
      _loadedWorkspaceId = ws.id;
    });
    final repo = ref.read(ledgerRepositoryProvider);
    try {
      final bundle = await repo.listMembers(ws.id);
      List<WorkspaceActivityLogModel> logs = const [];
      bool hasMoreLogs = false;
      if (ws.role == 'owner' || bundle.viewerRole == 'owner') {
        try {
          final page = await repo.listActivityLogs(
            ws.id,
            limit: 5,
            offset: 0,
          );
          logs = page.logs.take(5).toList();
          hasMoreLogs = page.hasMore;
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _maxMembers = bundle.maxMembers;
        _activeInvite = bundle.activeInvite;
        _activityLogs = logs;
        _hasMoreActivityLogs = hasMoreLogs;
        if (bundle.members.isNotEmpty) {
          _members
            ..clear()
            ..addAll(
              bundle.members.map(
                (m) => _TeamMember(
                  userId: m.userId,
                  name: m.isOwner ? '${m.fullName} (Pemilik)' : m.fullName,
                  initials: m.initials,
                  avatarUrl: m.avatarUrl,
                  phoneOrNote: m.isOwner
                      ? '${m.email} · Pemilik Buku Kas'
                      : '${m.email} · Catat Suara, Struk & Nota',
                  role: m.roleLabel,
                  isOwner: m.isOwner,
                  isOnline: true,
                ),
              ),
            );
        }
      });
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isLoadingWorkspaceMeta = false);
      }
    }
  }

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
      phoneOrNote: 'Admin Pembukuan · Catat Suara, Struk & Nota',
      role: 'Admin',
      isOwner: false,
      isOnline: true,
    ),
  ];

  Future<void> _handleRemoveMember(
    BuildContext context,
    Workspace activeWs,
    _TeamMember member,
  ) async {
    if (member.isOwner || member.userId.isEmpty) return;
    HapticFeedback.mediumImpact();
    try {
      final bundle = await ref.read(ledgerRepositoryProvider).removeMember(
            workspaceId: activeWs.id,
            memberUserId: member.userId,
          );
      if (!mounted) return;
      setState(() {
        _maxMembers = bundle.maxMembers;
        _members
          ..clear()
          ..addAll(
            bundle.members.map(
              (m) => _TeamMember(
                userId: m.userId,
                name: m.isOwner ? '${m.fullName} (Pemilik)' : m.fullName,
                initials: m.initials,
                avatarUrl: m.avatarUrl,
                phoneOrNote: m.isOwner
                    ? '${m.email} · Pemilik Buku Kas'
                    : '${m.email} · Catat Suara, Struk & Nota',
                role: m.roleLabel,
                isOwner: m.isOwner,
                isOnline: true,
              ),
            ),
          );
      });
      await _loadMembersAndActivityLogs(activeWs);
      if (!context.mounted) return;
      UcapKasToast.showInfo(
        context,
        headerLabel: 'Anggota Dikeluarkan',
        title: '${member.name} dihapus dari ${activeWs.shortName}',
        subtitle: 'Akses Admin anggota telah dicabut',
        badgeText: '${_members.length}/$_maxMembers',
      );
    } on ApiException catch (e) {
      if (!context.mounted) return;
      UcapKasToast.showInfo(
        context,
        headerLabel: 'Gagal Menghapus',
        title: e.message,
        badgeText: 'ERR',
      );
    }
  }

  void _showJoinWorkspaceSheet(BuildContext context) {
    final tokenCtrl = TextEditingController();
    bool isJoining = false;
    String? errorText;

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
                    'Gabung ke Buku Kas Bersama',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tempel tautan undangan WhatsApp atau kode undangan (uk-inv-...) dari pemilik Buku Kas untuk masuk sebagai Admin.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      height: 1.4,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: tokenCtrl,
                    decoration: _sheetInputDecoration(
                      hintText: 'Contoh: https://ucapkas.id/join/uk-inv-...',
                      prefixIcon: Icons.link_rounded,
                      errorText: errorText,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryTeal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: isJoining
                        ? null
                        : () async {
                            final raw = tokenCtrl.text.trim();
                            if (raw.isEmpty) {
                              setSheetState(() {
                                errorText =
                                    'Masukkan tautan atau kode undangan terlebih dahulu';
                              });
                              return;
                            }
                            if (!ref.read(authProvider).isAuthenticated) {
                              Navigator.of(sheetCtx).pop();
                              UcapKasToast.showInfo(
                                context,
                                headerLabel: 'Login Diperlukan',
                                title: 'Masuk dengan akun Google terlebih dahulu',
                                subtitle:
                                    'Agar akun Anda terdaftar sebagai Admin Buku Kas',
                              );
                              return;
                            }
                            setSheetState(() {
                              isJoining = true;
                              errorText = null;
                            });
                            try {
                              final res = await ref
                                  .read(ledgerRepositoryProvider)
                                  .joinWorkspace(raw);
                              if (res.workspaces.isNotEmpty) {
                                ref
                                    .read(authProvider.notifier)
                                    .updateWorkspaces(res.workspaces);
                                if (res.workspace != null) {
                                  final idx = res.workspaces.indexWhere(
                                    (w) => w.id == res.workspace!.id,
                                  );
                                  if (idx >= 0) {
                                    ref
                                        .read(
                                          activeWorkspaceIndexProvider.notifier,
                                        )
                                        .state = idx;
                                  }
                                }
                              }
                              if (sheetCtx.mounted) {
                                Navigator.of(sheetCtx).pop();
                              }
                              if (context.mounted) {
                                final joinedName =
                                    res.workspace?.name ?? 'Buku Kas Bersama';
                                UcapKasToast.showInfo(
                                  context,
                                  headerLabel: 'Berhasil Bergabung!',
                                  title: joinedName,
                                  subtitle:
                                      'Anda kini terdaftar sebagai Admin Buku Kas',
                                  badgeText: 'ADMIN',
                                );
                                if (res.workspace != null) {
                                  await _loadMembersAndActivityLogs(
                                    res.workspace!,
                                  );
                                }
                              }
                            } on ApiException catch (e) {
                              setSheetState(() {
                                isJoining = false;
                                errorText = e.message;
                              });
                            } catch (_) {
                              setSheetState(() {
                                isJoining = false;
                                errorText =
                                    'Gagal memproses tautan undangan. Coba lagi.';
                              });
                            }
                          },
                    icon: isJoining
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.group_add_rounded, size: 17),
                    label: Text(
                      isJoining
                          ? 'Memverifikasi Undangan...'
                          : 'Gabung Sebagai Admin',
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showInviteMemberSheet(BuildContext context, Workspace activeWs) {
    WorkspaceInviteModel? currentInvite = _activeInvite;
    bool isGenerating = false;
    String? errorMsg;

    Future<void> generateNewLink(
      void Function(void Function()) setSheetState,
    ) async {
      setSheetState(() {
        isGenerating = true;
        errorMsg = null;
      });
      if (!ref.read(authProvider).isAuthenticated) {
        const previewInv = WorkspaceInviteModel(
          token: 'uk-inv-preview24h',
          inviteUrl: 'https://ucapkas.id/join/uk-inv-preview24h',
          deepLink: 'ucapkas://join/uk-inv-preview24h',
          expiresAt: 'Besok (24 Jam)',
          waShareText:
              'Halo! Anda diundang menjadi *Admin* di Buku Kas pada aplikasi *UcapKas*.\n\nKlik tautan undangan (sekali pakai, berlaku 24 jam):\nhttps://ucapkas.id/join/uk-inv-preview24h\n\nKode undangan: *uk-inv-preview24h*',
        );
        setSheetState(() {
          currentInvite = previewInv;
          isGenerating = false;
        });
        return;
      }
      try {
        final created = await ref
            .read(ledgerRepositoryProvider)
            .createInvite(activeWs.id);
        if (mounted) {
          setState(() => _activeInvite = created);
        }
        setSheetState(() {
          currentInvite = created;
          isGenerating = false;
        });
        await _loadMembersAndActivityLogs(activeWs);
      } on ApiException catch (e) {
        setSheetState(() {
          isGenerating = false;
          errorMsg = e.message;
        });
      } catch (_) {
        setSheetState(() {
          isGenerating = false;
          errorMsg = 'Gagal membuat tautan undangan baru.';
        });
      }
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        bool triggeredInitial = false;
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            if (!triggeredInitial) {
              triggeredInitial = true;
              Future.microtask(() => generateNewLink(setSheetState));
            }
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
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primaryTealSoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.link_rounded,
                            color: AppColors.primaryTeal,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Undang Admin ke ${activeWs.shortName}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Tautan berlaku 24 jam · Hangus otomatis setelah 1 orang bergabung',
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  height: 1.35,
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
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.verified_user_outlined,
                                size: 15,
                                color: AppColors.primaryTeal,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Hak Akses: Admin (Bisa Suara AI, Foto Struk, Kas & Nota)',
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Pemakaian Suara & Struk AI oleh Admin menggunakan kuota pemilik Buku Kas dan tercatat di Log Aktivitas Anda.',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              height: 1.35,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (isGenerating)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primaryTeal,
                          ),
                        ),
                      )
                    else if (errorMsg != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.expenseSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          errorMsg!,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.expenseRose,
                          ),
                        ),
                      )
                    else if (currentInvite != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.heroDark,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SelectableText(
                                    currentInvite!.inviteUrl,
                                    style: AppTheme.numStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Kode: ${currentInvite!.token} · Sekali pakai (1 orang)',
                                    style: GoogleFonts.inter(
                                      fontSize: 10.5,
                                      color: AppColors.incomeEmeraldBright,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(text: currentInvite!.inviteUrl),
                                );
                                UcapKasToast.showInfo(
                                  context,
                                  headerLabel: 'Link Disalin',
                                  title: currentInvite!.token,
                                  subtitle:
                                      'Tempel dan kirimkan ke WhatsApp anggota Anda',
                                  badgeText: 'LINK',
                                );
                              },
                              icon: const Icon(
                                Icons.copy_rounded,
                                size: 14,
                                color: AppColors.incomeEmeraldBright,
                              ),
                              label: Text(
                                'Salin',
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.incomeEmeraldBright,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryTeal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          final inv = currentInvite!;
                          Navigator.of(sheetCtx).pop();
                          final shared = await NativeFileSaver.shareText(
                            text: inv.waShareText,
                            title: 'Undang Admin ke ${activeWs.name}',
                          );
                          if (!shared && context.mounted) {
                            await Clipboard.setData(
                              ClipboardData(text: inv.waShareText),
                            );
                            if (context.mounted) {
                              UcapKasToast.showInfo(
                                context,
                                headerLabel: 'Pesan Undangan WA Disalin',
                                title:
                                    'Tautan sekali pakai (${inv.token}) siap dikirim',
                                subtitle:
                                    'Tempel langsung di chat WhatsApp anggota Anda',
                                badgeText: 'WA',
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.send_rounded, size: 16),
                        label: Text(
                          'Kirim Link Undangan via WhatsApp',
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
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
    final initialQuickCats = Workspace.normalizeQuickCategories(
      existing?.quickCategories ??
          Workspace.defaultCategoriesForFocus(focusType),
      focusType: focusType,
    );
    final cat1Ctrl = TextEditingController(text: initialQuickCats[0]);
    final cat2Ctrl = TextEditingController(text: initialQuickCats[1]);
    final cat3Ctrl = TextEditingController(text: initialQuickCats[2]);
    String customLogoUrl = existing?.logoUrl ?? '';
    final authStateForSheet = ref.read(authProvider);
    final isProUserForSheet = authStateForSheet.isAuthenticated
        ? ((authStateForSheet.user?.isPro ?? false) ||
            (existing?.isPro ?? false))
        : (existing?.isPro ?? true);
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
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
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
                                      Flexible(
                                        child: Row(
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
                                            Flexible(
                                              child: Text(
                                                'PRATINJAU KARTU KAS & NOTA',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.inter(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: 0.6,
                                                  color: AppColors.darkTextMuted,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
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
                                                  setSheetState(() {
                                                    focusType = opt.$1;
                                                    if (!isEdit) {
                                                      final defaults = Workspace
                                                          .defaultCategoriesForFocus(
                                                        focusType,
                                                      );
                                                      cat1Ctrl.text =
                                                          defaults[0];
                                                      cat2Ctrl.text =
                                                          defaults[1];
                                                      cat3Ctrl.text =
                                                          defaults[2];
                                                    }
                                                  });
                                                },
                                                child: AnimatedContainer(
                                                  duration: const Duration(
                                                    milliseconds: 160,
                                                  ),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 6,
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
                                                        textAlign:
                                                            TextAlign.center,
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
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          'Nama Buku Kas / Nama Usaha',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
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
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          'Nama Pendek (Tampil di Pill Atas)',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
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
                            // B2. 3 Quick Categories Configuration Card
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
                                      Flexible(
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.label_outline_rounded,
                                              size: 16,
                                              color: AppColors.primaryTeal,
                                            ),
                                            const SizedBox(width: 7),
                                            Flexible(
                                              child: Text(
                                                'Kategori Pilih Cepat (Maks. 3)',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style:
                                                    GoogleFonts.plusJakartaSans(
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: () {
                                          HapticFeedback.selectionClick();
                                          final defaults = Workspace
                                              .defaultCategoriesForFocus(
                                            focusType,
                                          );
                                          setSheetState(() {
                                            cat1Ctrl.text = defaults[0];
                                            cat2Ctrl.text = defaults[1];
                                            cat3Ctrl.text = defaults[2];
                                          });
                                        },
                                        child: Text(
                                          'Reset Bawaan',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.primaryTeal,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Tampil sebagai 3 tombol pilih cepat di halaman Catat Kas agar ringkas dan tidak sumpek.',
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          key: const Key('input_quick_cat_0'),
                                          controller: cat1Ctrl,
                                          textCapitalization:
                                              TextCapitalization.words,
                                          inputFormatters: [
                                            LengthLimitingTextInputFormatter(
                                              24,
                                            ),
                                          ],
                                          onChanged: (_) => setSheetState(() {}),
                                          style: GoogleFonts.inter(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                          ),
                                          decoration: InputDecoration(
                                            labelText: 'Kategori 1',
                                            labelStyle: GoogleFonts.inter(
                                              fontSize: 11,
                                              color: AppColors.textMuted,
                                            ),
                                            isDense: true,
                                            filled: true,
                                            fillColor: AppColors.background,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 11,
                                            ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              borderSide: const BorderSide(
                                                color: AppColors.border,
                                              ),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              borderSide: const BorderSide(
                                                color: AppColors.border,
                                              ),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              borderSide: const BorderSide(
                                                color: AppColors.primaryTeal,
                                                width: 1.3,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextField(
                                          key: const Key('input_quick_cat_1'),
                                          controller: cat2Ctrl,
                                          textCapitalization:
                                              TextCapitalization.words,
                                          inputFormatters: [
                                            LengthLimitingTextInputFormatter(
                                              24,
                                            ),
                                          ],
                                          onChanged: (_) => setSheetState(() {}),
                                          style: GoogleFonts.inter(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                          ),
                                          decoration: InputDecoration(
                                            labelText: 'Kategori 2',
                                            labelStyle: GoogleFonts.inter(
                                              fontSize: 11,
                                              color: AppColors.textMuted,
                                            ),
                                            isDense: true,
                                            filled: true,
                                            fillColor: AppColors.background,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 11,
                                            ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              borderSide: const BorderSide(
                                                color: AppColors.border,
                                              ),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              borderSide: const BorderSide(
                                                color: AppColors.border,
                                              ),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              borderSide: const BorderSide(
                                                color: AppColors.primaryTeal,
                                                width: 1.3,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextField(
                                          key: const Key('input_quick_cat_2'),
                                          controller: cat3Ctrl,
                                          textCapitalization:
                                              TextCapitalization.words,
                                          inputFormatters: [
                                            LengthLimitingTextInputFormatter(
                                              24,
                                            ),
                                          ],
                                          onChanged: (_) => setSheetState(() {}),
                                          style: GoogleFonts.inter(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                          ),
                                          decoration: InputDecoration(
                                            labelText: 'Kategori 3',
                                            labelStyle: GoogleFonts.inter(
                                              fontSize: 11,
                                              color: AppColors.textMuted,
                                            ),
                                            isDense: true,
                                            filled: true,
                                            fillColor: AppColors.background,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 11,
                                            ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              borderSide: const BorderSide(
                                                color: AppColors.border,
                                              ),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              borderSide: const BorderSide(
                                                color: AppColors.border,
                                              ),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              borderSide: const BorderSide(
                                                color: AppColors.primaryTeal,
                                                width: 1.3,
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
                            const SizedBox(height: 14),
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
                                      Flexible(
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.account_balance_outlined,
                                              size: 16,
                                              color: AppColors.primaryTeal,
                                            ),
                                            const SizedBox(width: 7),
                                            Flexible(
                                              child: Text(
                                                'Rekening Tujuan Nota WA',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style:
                                                    GoogleFonts.plusJakartaSans(
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
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
                                          Icons.account_balance_outlined,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
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
                                        RegExp(r'[0-9\-\s]'),
                                      ),
                                    ],
                                    onChanged: (_) => setSheetState(() {}),
                                    style: AppTheme.numStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                    decoration: _sheetInputDecoration(
                                      hintText: 'Contoh: 8820192831',
                                      prefixIcon: Icons.credit_card_rounded,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
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
                            const SizedBox(height: 14),
                            // D. Logo & Watermark PDF Invoice Card (Starter vs Pro)
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
                                      Flexible(
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.picture_as_pdf_outlined,
                                              size: 16,
                                              color: AppColors.primaryTeal,
                                            ),
                                            const SizedBox(width: 7),
                                            Flexible(
                                              child: Text(
                                                'Logo & Watermark Invoice PDF',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style:
                                                    GoogleFonts.plusJakartaSans(
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isProUserForSheet
                                              ? AppColors.primaryTealSoft
                                              : AppColors.surfaceSubtle,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          isProUserForSheet
                                              ? 'PRO · Tanpa Watermark'
                                              : 'Paket Starter',
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: isProUserForSheet
                                                ? AppColors.primaryTeal
                                                : AppColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  if (!isProUserForSheet) ...[
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppColors.background,
                                        borderRadius: BorderRadius.circular(12),
                                        border:
                                            Border.all(color: AppColors.border),
                                      ),
                                      child: Row(
                                        children: [
                                          const UcapKasLogo(
                                            size: 36,
                                            showWordmark: false,
                                          ),
                                          const SizedBox(width: 11),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Logo UcapKas & Watermark Play Store',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        AppColors.textPrimary,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  'Upgrade ke Paket Pro untuk mengunggah Logo Custom Usaha & menghapus watermark di footer PDF.',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 11,
                                                    height: 1.35,
                                                    color: AppColors.textMuted,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          TextButton(
                                            onPressed: () {
                                              Navigator.of(sheetCtx).pop();
                                              context.push('/paket-usaha');
                                            },
                                            child: Text(
                                              'Upgrade',
                                              style: GoogleFonts.inter(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.primaryTeal,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ] else ...[
                                    Builder(
                                      builder: (_) {
                                        Uint8List? previewBytes;
                                        if (customLogoUrl.trim().isNotEmpty) {
                                          var rawB64 = customLogoUrl.trim();
                                          final idx = rawB64.indexOf('base64,');
                                          if (idx >= 0) {
                                            rawB64 = rawB64.substring(idx + 7);
                                          }
                                          try {
                                            previewBytes = base64Decode(rawB64);
                                          } catch (_) {}
                                        }
                                        return Row(
                                          children: [
                                            Container(
                                              width: 44,
                                              height: 44,
                                              decoration: BoxDecoration(
                                                color: previewBytes != null
                                                    ? AppColors.surface
                                                    : AppColors.heroDark,
                                                borderRadius:
                                                    BorderRadius.circular(11),
                                                border: Border.all(
                                                  color: AppColors.border,
                                                ),
                                              ),
                                              clipBehavior: Clip.antiAlias,
                                              alignment: Alignment.center,
                                              child: previewBytes != null
                                                  ? Image.memory(
                                                      previewBytes,
                                                      width: 44,
                                                      height: 44,
                                                      fit: BoxFit.cover,
                                                    )
                                                  : Text(
                                                      liveShort.length > 3
                                                          ? liveShort
                                                              .substring(0, 3)
                                                              .toUpperCase()
                                                          : liveShort
                                                              .toUpperCase(),
                                                      style: GoogleFonts
                                                          .plusJakartaSans(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    previewBytes != null
                                                        ? 'Logo Custom Usaha Aktif'
                                                        : 'Monogram Usaha ($liveShort)',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 12.5,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color:
                                                          AppColors.textPrimary,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'Tampil di kop PDF Invoice tanpa watermark UcapKas',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 11,
                                                      color:
                                                          AppColors.textMuted,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            if (previewBytes != null)
                                              IconButton(
                                                tooltip: 'Hapus Logo',
                                                onPressed: () {
                                                  setSheetState(
                                                    () => customLogoUrl = '',
                                                  );
                                                },
                                                icon: const Icon(
                                                  Icons.delete_outline_rounded,
                                                  size: 18,
                                                  color: AppColors.expenseRose,
                                                ),
                                              ),
                                            OutlinedButton.icon(
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor:
                                                    AppColors.primaryTeal,
                                                side: const BorderSide(
                                                  color: AppColors.primaryTeal,
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 8,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(9),
                                                ),
                                              ),
                                              onPressed: () async {
                                                final picked =
                                                    await NativeFileSaver
                                                        .pickLogoImage();
                                                if (picked != null) {
                                                  setSheetState(
                                                    () =>
                                                        customLogoUrl = picked,
                                                  );
                                                }
                                              },
                                              icon: const Icon(
                                                Icons.image_outlined,
                                                size: 15,
                                              ),
                                              label: Text(
                                                'Pilih Logo',
                                                style: GoogleFonts.inter(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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
                                        final quickCats = Workspace
                                            .normalizeQuickCategories(
                                          [
                                            cat1Ctrl.text,
                                            cat2Ctrl.text,
                                            cat3Ctrl.text,
                                          ],
                                          focusType: focusType,
                                        );

                                        final isAuth = ref
                                            .read(authProvider)
                                            .isAuthenticated;
                                        if (!isAuth) {
                                          final currentList = [
                                            ...ref.read(
                                              previewWorkspacesProvider,
                                            ),
                                          ];
                                          if (isEdit) {
                                            final idx = currentList.indexWhere(
                                              (w) => w.id == existing.id,
                                            );
                                            if (idx >= 0) {
                                              currentList[idx] =
                                                  currentList[idx].copyWith(
                                                name: name,
                                                shortName: shortName,
                                                focusType: focusType,
                                                bankName:
                                                    bankNameCtrl.text.trim(),
                                                bankAccountNumber:
                                                    bankAccCtrl.text.trim(),
                                                bankAccountHolder:
                                                    bankHolderCtrl.text.trim(),
                                                logoUrl: isProUserForSheet
                                                    ? customLogoUrl
                                                    : '',
                                                quickCategories: quickCats,
                                              );
                                            }
                                          } else {
                                            currentList.add(
                                              Workspace(
                                                id: 'ws-${DateTime.now().millisecondsSinceEpoch}',
                                                name: name,
                                                shortName: shortName,
                                                balance: 0,
                                                monthlyInflow: 0,
                                                monthlyOutflow: 0,
                                                focusType: focusType,
                                                bankName:
                                                    bankNameCtrl.text.trim(),
                                                bankAccountNumber:
                                                    bankAccCtrl.text.trim(),
                                                bankAccountHolder:
                                                    bankHolderCtrl.text.trim(),
                                                logoUrl: isProUserForSheet
                                                    ? customLogoUrl
                                                    : '',
                                                quickCategories: quickCats,
                                              ),
                                            );
                                            ref
                                                .read(
                                                  activeWorkspaceIndexProvider
                                                      .notifier,
                                                )
                                                .state = currentList.length - 1;
                                          }
                                          ref
                                              .read(
                                                previewWorkspacesProvider
                                                    .notifier,
                                              )
                                              .state = currentList;
                                          Navigator.of(sheetCtx).pop();
                                          UcapKasToast.showInfo(
                                            context,
                                            headerLabel: isEdit
                                                ? 'Pengaturan Kas Disimpan'
                                                : 'Buku Kas Baru Aktif',
                                            title: name,
                                            subtitle:
                                                'Kategori: ${quickCats.join(' · ')}',
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
                                                  logoUrl: isProUserForSheet
                                                      ? customLogoUrl
                                                      : '',
                                                  quickCategories: quickCats,
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
                                                  logoUrl: isProUserForSheet
                                                      ? customLogoUrl
                                                      : '',
                                                  quickCategories: quickCats,
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
    final aiQuota = ref.watch(aiQuotaProvider);
    final workspaces = ref.watch(workspacesProvider);
    final activeIdx = ref
        .watch(activeWorkspaceIndexProvider)
        .clamp(0, workspaces.length - 1);
    final activeWs = workspaces[activeIdx];
    final isActiveOwner = activeWs.role == 'owner';
    final txs = ref.watch(transactionsProvider);

    if (authState.isAuthenticated &&
        activeWs.id.isNotEmpty &&
        activeWs.id != _loadedWorkspaceId &&
        !_isLoadingWorkspaceMeta) {
      Future.microtask(() => _loadMembersAndActivityLogs(activeWs));
    }

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
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 116),
          children: [
            // 1. Page Header (Matched to Screen1Dashboard & Screen7DaftarNota)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
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
                ProBadge(
                  onTap: () => context.push('/paket-usaha'),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 2. Bento Executive Profile & Quota Card (Matched to Screen1Dashboard Hero Card)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.heroDark,
                borderRadius: BorderRadius.circular(22),
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
                        clipBehavior: Clip.antiAlias,
                        alignment: Alignment.center,
                        child: authUser != null &&
                                authUser.avatarUrl.trim().isNotEmpty
                            ? Image.network(
                                authUser.avatarUrl.trim(),
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Text(
                                  authUser.initials,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              )
                            : Text(
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
                                      fontSize: 16.5,
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
                            const SizedBox(height: 3),
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
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Divider(
                      color: AppColors.heroCardSecondary,
                      height: 1,
                    ),
                  ),
                  // 2-Column Quota Split (Exact same architecture as Dashboard Kas Masuk / Kas Keluar)
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.mic_none_rounded,
                                  size: 13.5,
                                  color: AppColors.primaryTealBright,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'Kuota Minggu Ini',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      color: AppColors.darkTextMuted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              (authUser?.isPro ?? false) || aiQuota.isUnlimited
                                  ? 'Tanpa Batas'
                                  : '${aiQuota.weeklyUsed}/${aiQuota.weeklyLimit} terpakai',
                              style: AppTheme.numStyle(
                                fontSize: 14.5,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 34,
                        color: AppColors.heroCardSecondary,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.auto_awesome_outlined,
                                  size: 13.5,
                                  color: AppColors.incomeEmeraldBright,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'Kuota Bulan Ini',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      color: AppColors.darkTextMuted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              (authUser?.isPro ?? false) || aiQuota.isUnlimited
                                  ? 'Unlimited AI'
                                  : '${aiQuota.monthlyUsed}/${aiQuota.monthlyLimit} terpakai',
                              style: AppTheme.numStyle(
                                fontSize: 14.5,
                                color: AppColors.incomeEmeraldBright,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Bottom Plan Status Pill (Exact same architecture as Dashboard status bar)
                  GestureDetector(
                    onTap: () => context.push('/paket-usaha'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.heroCardSecondary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primaryTealBright,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    authUser != null
                                        ? authUser.planLabel
                                        : 'Paket Usaha Tahunan · Aktif s/d Nov 2027',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.darkTextPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Kelola Paket',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryTealBright,
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(
                                Icons.chevron_right_rounded,
                                size: 15,
                                color: AppColors.primaryTealBright,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 2b. Quick Actions Row (Matched to Screen1Dashboard _QuickActionButton row)
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
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
                            subtitle:
                                'Paket Pro mendukung hingga 3 Buku Kas aktif',
                            badgeText: '3/3',
                          );
                        }
                        return;
                      }
                      _showWorkspaceFormSheet(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: AppColors.primaryTeal,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.add_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Tambah Kas',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    key: const Key('btn_join_workspace'),
                    onTap: () => _showJoinWorkspaceSheet(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                        boxShadow: AppColors.cardShadow,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.group_add_outlined,
                            size: 16,
                            color: AppColors.textPrimary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Gabung Kas',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // 3. Multi-Workspace Switcher ("Pilih Buku Kas Aktif")
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pilih Buku Kas Aktif',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Terpakai ${workspaces.length} dari ${(authUser?.isPro ?? true) ? 3 : 1} slot Buku Kas',
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
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
                boxShadow: AppColors.cardShadow,
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (int i = 0; i < workspaces.length; i++) ...[
                    if (i > 0)
                      const Divider(height: 1, color: AppColors.border),
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
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            ref
                                .read(activeWorkspaceIndexProvider.notifier)
                                .state = i;
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
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppColors.primaryTealSoft
                                            : AppColors.surfaceSubtle,
                                        borderRadius: BorderRadius.circular(11),
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            ws.name,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              height: 1.25,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            'Saldo Kas: ${RupiahFormatter.format(displayBalance)}',
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
                                  child: Divider(
                                    height: 1,
                                    color: AppColors.border,
                                  ),
                                ),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
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
                                    Expanded(
                                      child: Text(
                                        ws.bankName.isNotEmpty
                                            ? '${ws.bankName} · ${ws.bankAccountNumber}${ws.bankAccountHolder.isNotEmpty ? " a.n. ${ws.bankAccountHolder}" : ""}'
                                            : 'Rekening nota WA belum diatur',
                                        style: GoogleFonts.inter(
                                          fontSize: 11.5,
                                          height: 1.35,
                                          fontWeight: ws.bankName.isNotEmpty
                                              ? FontWeight.w600
                                              : FontWeight.w500,
                                          color: ws.bankName.isNotEmpty
                                              ? AppColors.textSecondary
                                              : AppColors.textMuted,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (ws.role == 'owner')
                                      GestureDetector(
                                        key: ValueKey(
                                          'btn_edit_workspace_${ws.id}',
                                        ),
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () {
                                          HapticFeedback.selectionClick();
                                          _showWorkspaceFormSheet(
                                            context,
                                            existing: ws,
                                          );
                                        },
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.tune_rounded,
                                              size: 13.5,
                                              color: AppColors.primaryTeal,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Atur Kas',
                                              style: GoogleFonts.inter(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.primaryTeal,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    else
                                      Text(
                                        'Akses Admin',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.label_outline_rounded,
                                      size: 13.5,
                                      color: AppColors.textMuted,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Kategori Cepat: ${ws.quickCategories.take(3).join(' · ')}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.textMuted,
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
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 4. Team Members Section ("Anggota Kas Bersama")
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Anggota ${activeWs.shortName}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Terdaftar ${_members.length} dari ${authState.isAuthenticated ? _maxMembers : ((authUser?.isPro ?? true) ? 5 : 2)} akses tim',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isActiveOwner) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _showInviteMemberSheet(context, activeWs),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '+ Undang via WA',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryTeal,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: AppColors.primaryTeal,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
                boxShadow: AppColors.cardShadow,
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (int i = 0; i < _members.length; i++) ...[
                    if (i > 0)
                      const Divider(
                        height: 1,
                        indent: 62,
                        endIndent: 14,
                        color: AppColors.border,
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: _buildMemberRow(
                        context,
                        activeWs,
                        _members[i],
                        canManageMembers: isActiveOwner,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 5. Log Aktivitas Buku Kas (HANYA tampil untuk Pemilik Buku Kas, 5 Terbaru + Paging)
            if (isActiveOwner) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Log Aktivitas ${activeWs.shortName}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Pantau pemakaian suara AI, transaksi & aktivitas anggota',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _showAllActivityLogsSheet(context, activeWs),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Lihat Semua',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryTeal,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: AppColors.primaryTeal,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                  boxShadow: AppColors.cardShadow,
                ),
                clipBehavior: Clip.antiAlias,
                child: _activityLogs.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 22,
                        ),
                        child: Center(
                          child: Text(
                            authState.isAuthenticated
                                ? 'Belum ada riwayat aktivitas tercatat di Buku Kas ini.'
                                : 'Masuk Google untuk memantau Log Aktivitas real-time.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              height: 1.4,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          for (int i = 0;
                              i < _activityLogs.take(5).length;
                              i++) ...[
                            if (i > 0)
                              const Divider(
                                height: 1,
                                indent: 58,
                                endIndent: 14,
                                color: AppColors.border,
                              ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              child: _buildActivityLogRow(_activityLogs[i]),
                            ),
                          ],
                        ],
                      ),
              ),
              const SizedBox(height: 18),
            ],

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

            // 7. App Version & Build Info Footer (Restored)
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
                  padding: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 12,
                  ),
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

  Widget _buildMemberRow(
    BuildContext context,
    Workspace activeWs,
    _TeamMember member, {
    required bool canManageMembers,
  }) {
    final authUser = ref.watch(authProvider.select((s) => s.user));
    final isCurrentUser = authUser != null &&
        member.userId.isNotEmpty &&
        member.userId == authUser.id;
    final displayName = isCurrentUser
        ? '${authUser.fullName} (Anda)'
        : (member.isOwner && authUser != null && member.userId.isEmpty
            ? '${authUser.fullName} (Anda)'
            : member.name);
    final displayInitials = isCurrentUser
        ? authUser.initials
        : (member.isOwner && authUser != null && member.userId.isEmpty
            ? authUser.initials
            : member.initials);
    final avatarUrl = member.avatarUrl.trim().isNotEmpty
        ? member.avatarUrl.trim()
        : (member.isOwner && authUser != null
            ? authUser.avatarUrl.trim()
            : '');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
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
              clipBehavior: Clip.antiAlias,
              alignment: Alignment.center,
              child: avatarUrl.isNotEmpty
                  ? Image.network(
                      avatarUrl,
                      width: 38,
                      height: 38,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Text(
                        displayInitials,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: member.isOwner
                              ? AppColors.primaryTeal
                              : AppColors.textSecondary,
                        ),
                      ),
                    )
                  : Text(
                      displayInitials,
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
              Row(
                children: [
                  Flexible(
                    child: Text(
                      displayName,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: member.isOwner
                          ? AppColors.primaryTealSoft
                          : AppColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      member.role,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: member.isOwner
                            ? AppColors.primaryTeal
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                member.phoneOrNote,
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  height: 1.3,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        if (canManageMembers && !member.isOwner && member.userId.isNotEmpty) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _handleRemoveMember(context, activeWs, member),
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.expenseSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.person_remove_outlined,
                size: 15,
                color: AppColors.expenseRose,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActivityLogRow(WorkspaceActivityLogModel log) {
    final avatar = log.actorAvatarUrl.trim();
    final isAi = log.action.startsWith('AI_');
    final isMember = log.action.startsWith('MEMBER_');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: isAi
                ? AppColors.primaryTealSoft
                : isMember
                    ? AppColors.incomeSoft
                    : AppColors.surfaceSubtle,
            borderRadius: BorderRadius.circular(10),
          ),
          clipBehavior: Clip.antiAlias,
          alignment: Alignment.center,
          child: avatar.isNotEmpty
              ? Image.network(
                  avatar,
                  width: 34,
                  height: 34,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Text(
                    log.actorInitials,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryTeal,
                    ),
                  ),
                )
              : Text(
                  log.actorInitials,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: isAi
                        ? AppColors.primaryTeal
                        : AppColors.textSecondary,
                  ),
                ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      log.title,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${log.dateGroup}, ${log.timeLabel}',
                    style: AppTheme.numStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              if (log.subtitle.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  log.subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    height: 1.35,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _showAllActivityLogsSheet(BuildContext context, Workspace activeWs) {
    const int pageSize = 15;
    final List<WorkspaceActivityLogModel> pagedLogs = [
      ..._activityLogs,
    ];
    bool isLoadingMore = false;
    bool isInitialLoading = pagedLogs.length < pageSize && _hasMoreActivityLogs;
    bool hasMore = _hasMoreActivityLogs;
    int nextOffset = pagedLogs.length;
    String? errorMsg;

    Future<void> fetchNextPage(
      void Function(void Function()) setSheetState, {
      bool reset = false,
    }) async {
      if (isLoadingMore) return;
      setSheetState(() {
        isLoadingMore = true;
        errorMsg = null;
        if (reset) {
          isInitialLoading = true;
          nextOffset = 0;
        }
      });
      try {
        final page = await ref.read(ledgerRepositoryProvider).listActivityLogs(
              activeWs.id,
              limit: pageSize,
              offset: reset ? 0 : nextOffset,
            );
        setSheetState(() {
          if (reset) {
            pagedLogs
              ..clear()
              ..addAll(page.logs);
          } else {
            final existingIds = pagedLogs.map((e) => e.id).toSet();
            for (final item in page.logs) {
              if (!existingIds.contains(item.id)) {
                pagedLogs.add(item);
              }
            }
          }
          hasMore = page.hasMore;
          nextOffset = page.nextOffset;
          isLoadingMore = false;
          isInitialLoading = false;
        });
      } on ApiException catch (e) {
        setSheetState(() {
          isLoadingMore = false;
          isInitialLoading = false;
          errorMsg = e.message;
        });
      } catch (_) {
        setSheetState(() {
          isLoadingMore = false;
          isInitialLoading = false;
          errorMsg = 'Gagal memuat halaman aktivitas berikutnya.';
        });
      }
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        bool triggeredInitial = false;
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            if (!triggeredInitial) {
              triggeredInitial = true;
              Future.microtask(
                () => fetchNextPage(setSheetState, reset: true),
              );
            }
            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.86,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 16, 14),
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24),
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
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Log Aktivitas ${activeWs.shortName}',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 16.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.3,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Pantau pemakaian suara AI, transaksi & aktivitas anggota',
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
                              icon: const Icon(
                                Icons.close_rounded,
                                size: 20,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: isInitialLoading && pagedLogs.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 48),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: AppColors.primaryTeal,
                              ),
                            ),
                          )
                        : pagedLogs.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(28),
                                child: Center(
                                  child: Text(
                                    'Belum ada riwayat aktivitas tercatat.',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              )
                            : NotificationListener<ScrollNotification>(
                                onNotification: (scrollInfo) {
                                  if (hasMore &&
                                      !isLoadingMore &&
                                      scrollInfo.metrics.pixels >=
                                          scrollInfo.metrics.maxScrollExtent -
                                              120) {
                                    fetchNextPage(setSheetState);
                                  }
                                  return false;
                                },
                                child: ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    14,
                                    20,
                                    24,
                                  ),
                                  itemCount: pagedLogs.length + 1,
                                  separatorBuilder: (_, __) => const Divider(
                                    height: 18,
                                    color: AppColors.border,
                                  ),
                                  itemBuilder: (itemCtx, idx) {
                                    if (idx < pagedLogs.length) {
                                      return _buildActivityLogRow(
                                        pagedLogs[idx],
                                      );
                                    }
                                    if (errorMsg != null) {
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: TextButton(
                                          onPressed: () =>
                                              fetchNextPage(setSheetState),
                                          child: Text(errorMsg!),
                                        ),
                                      );
                                    }
                                    if (!hasMore) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        child: Center(
                                          child: Text(
                                            'Semua riwayat aktivitas telah ditampilkan (${pagedLogs.length} data)',
                                            style: GoogleFonts.inter(
                                              fontSize: 11.5,
                                              color: AppColors.textMuted,
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor:
                                              AppColors.primaryTeal,
                                          side: const BorderSide(
                                            color: AppColors.borderStrong,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                        ),
                                        onPressed: isLoadingMore
                                            ? null
                                            : () =>
                                                fetchNextPage(setSheetState),
                                        child: Text(
                                          isLoadingMore
                                              ? 'Memuat halaman berikutnya...'
                                              : 'Muat Lebih Banyak',
                                          style: GoogleFonts.inter(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
