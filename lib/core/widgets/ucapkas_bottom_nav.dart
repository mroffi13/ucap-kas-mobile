import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../state/ledger_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/native_voice_recorder.dart';

enum UcapKasTab { bukuKas, notaWa, laporan, akun }

enum VoiceRecordMode {
  idle,
  tapRecording, // Klik sekali -> ngerekam suara (hands-free)
  holdPushToTalk, // Tahan (hold) -> push-to-talk ala WA, geser kemana saja untuk batal
}

class UcapKasBottomNavBar extends StatefulWidget {
  final int? currentIndex; // 0: Kas, 1: Nota, 2: Laporan, 3: Akun
  final UcapKasTab? activeTab;
  final ValueChanged<int>? onTabSelected;
  final VoidCallback? onBicaraPressed;
  final VoidCallback? onRecordCancelled;

  const UcapKasBottomNavBar({
    super.key,
    this.currentIndex,
    this.activeTab,
    this.onTabSelected,
    this.onBicaraPressed,
    this.onRecordCancelled,
  });

  @override
  State<UcapKasBottomNavBar> createState() => _UcapKasBottomNavBarState();
}

class _UcapKasBottomNavBarState extends State<UcapKasBottomNavBar> {
  static const Duration _holdThreshold = Duration(milliseconds: 240);
  static const double _cancelDragDistance = 55.0;
  static const double _cancelLeftDelta = -45.0;

  VoiceRecordMode _recordMode = VoiceRecordMode.idle;
  Timer? _holdDetectTimer;
  Timer? _recordStopwatchTimer;
  Timer? _cancelFeedbackTimer;

  bool _isPointerDown = false;
  Offset _pointerDownPos = Offset.zero;
  Offset _dragOffset = Offset.zero;
  bool _isCancelZone = false;
  bool _showCancelledBanner = false;
  int _elapsedSeconds = 1;
  int _wavePhase = 0;

  final NativeVoiceRecorder _audioRecorder = NativeVoiceRecorder();
  bool _isRecorderActive = false;
  final String _liveRecognizedText = '';

  static const List<double> _baseWaveHeights = [
    8,
    14,
    22,
    28,
    16,
    24,
    30,
    18,
    26,
    14,
    22,
    12,
    20,
    10,
    8,
  ];

  int get _effectiveIndex {
    if (widget.currentIndex != null) return widget.currentIndex!;
    switch (widget.activeTab) {
      case UcapKasTab.bukuKas:
        return 0;
      case UcapKasTab.notaWa:
        return 1;
      case UcapKasTab.laporan:
        return 2;
      case UcapKasTab.akun:
        return 3;
      case null:
        return 0;
    }
  }

  @override
  void dispose() {
    _holdDetectTimer?.cancel();
    _recordStopwatchTimer?.cancel();
    _cancelFeedbackTimer?.cancel();
    try {
      _audioRecorder.dispose();
    } catch (_) {}
    super.dispose();
  }

  void _handleTabTap(BuildContext context, int index) {
    if (_recordMode != VoiceRecordMode.idle) return;
    if (widget.onTabSelected != null) {
      widget.onTabSelected!(index);
      return;
    }
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
  }

  void _startStopwatch() {
    _recordStopwatchTimer?.cancel();
    _elapsedSeconds = 1;
    _wavePhase = 0;
    _recordStopwatchTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsedSeconds++;
        _wavePhase = (_wavePhase + 1) % _baseWaveHeights.length;
      });
    });
  }

  Future<void> _startNativeSpeechListening() async {
    try {
      final hasPerm = await _audioRecorder.hasPermission();
      if (!hasPerm || !mounted || _recordMode == VoiceRecordMode.idle) return;
      final startedPath = await _audioRecorder.start();
      _isRecorderActive = startedPath != null && startedPath.isNotEmpty;
    } catch (_) {
      // Safe fallback in widget tests or emulators without hardware mic
      _isRecorderActive = false;
    }
  }

  Future<String?> _stopNativeSpeechListening({bool cancel = false}) async {
    try {
      if (_isRecorderActive) {
        _isRecorderActive = false;
        if (cancel) {
          await _audioRecorder.cancel();
          return null;
        }
        return await _audioRecorder.stopAndEncodeBase64();
      }
    } catch (_) {}
    return null;
  }

  void _enterTapRecording() {
    HapticFeedback.lightImpact();
    _cancelFeedbackTimer?.cancel();
    setState(() {
      _showCancelledBanner = false;
      _recordMode = VoiceRecordMode.tapRecording;
      _dragOffset = Offset.zero;
      _isCancelZone = false;
    });
    _startStopwatch();
    _startNativeSpeechListening();
  }

  void _enterHoldPushToTalk() {
    HapticFeedback.mediumImpact();
    _cancelFeedbackTimer?.cancel();
    setState(() {
      _showCancelledBanner = false;
      _recordMode = VoiceRecordMode.holdPushToTalk;
    });
    _startStopwatch();
    _startNativeSpeechListening();
  }

  void _cancelRecording() {
    _holdDetectTimer?.cancel();
    _recordStopwatchTimer?.cancel();
    _cancelFeedbackTimer?.cancel();
    _stopNativeSpeechListening(cancel: true);
    HapticFeedback.vibrate();
    setState(() {
      _recordMode = VoiceRecordMode.idle;
      _isPointerDown = false;
      _dragOffset = Offset.zero;
      _isCancelZone = false;
      _showCancelledBanner = true;
    });
    widget.onRecordCancelled?.call();
    _cancelFeedbackTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _showCancelledBanner = false;
      });
    });
  }

  Future<void> _finishAndProcessRecording() async {
    final wasPtt = _recordMode == VoiceRecordMode.holdPushToTalk;
    final recordedSec = _elapsedSeconds < 2 ? 4 : _elapsedSeconds;

    _holdDetectTimer?.cancel();
    _recordStopwatchTimer?.cancel();
    HapticFeedback.mediumImpact();

    setState(() {
      _recordMode = VoiceRecordMode.idle;
      _isPointerDown = false;
      _dragOffset = Offset.zero;
      _isCancelZone = false;
      _showCancelledBanner = false;
    });

    final fallbackTranscript = widget.currentIndex == 1
        ? VoiceRecordingSession.sampleInvoiceSpeech
        : VoiceRecordingSession.sampleKasSpeech;

    ProviderContainer? container;
    try {
      container = ProviderScope.containerOf(context, listen: false);
    } catch (_) {
      // Ignore when tested standalone without ProviderScope
    }

    // Stop hardware audio recorder and attach base64 audio for Whisper / 9Router STT
    final audioB64 = await _stopNativeSpeechListening(cancel: false);
    final hasRealAudio = audioB64 != null && audioB64.isNotEmpty;

    if (container != null) {
      container.read(lastVoiceSessionProvider.notifier).state =
          VoiceRecordingSession(
        durationSeconds: recordedSec,
        isPushToTalk: wasPtt,
        transcript: hasRealAudio ? '' : fallbackTranscript,
        audioBase64: hasRealAudio ? audioB64 : '',
        mimeType: 'audio/mp4',
      );
    }

    if (!mounted) return;
    if (widget.onBicaraPressed != null) {
      widget.onBicaraPressed!();
      return;
    }
    context.push('/bicara');
  }

  void _onMicPointerDown(PointerDownEvent event) {
    _isPointerDown = true;
    _pointerDownPos = event.position;
    _dragOffset = Offset.zero;
    _isCancelZone = false;

    if (_recordMode == VoiceRecordMode.idle) {
      _holdDetectTimer?.cancel();
      _holdDetectTimer = Timer(_holdThreshold, () {
        if (mounted && _isPointerDown && _recordMode == VoiceRecordMode.idle) {
          _enterHoldPushToTalk();
        }
      });
    }
  }

  void _onMicPointerMove(PointerMoveEvent event) {
    if (!_isPointerDown) return;
    final delta = event.position - _pointerDownPos;

    // If user starts dragging significantly while holding before timer fires,
    // immediately promote to Push-to-Talk mode so drag-to-cancel feels instant.
    if (_recordMode == VoiceRecordMode.idle && delta.distance > 14.0) {
      _holdDetectTimer?.cancel();
      _enterHoldPushToTalk();
    }

    if (_recordMode == VoiceRecordMode.holdPushToTalk ||
        _recordMode == VoiceRecordMode.tapRecording) {
      final shouldCancel =
          delta.dx <= _cancelLeftDelta || delta.distance >= _cancelDragDistance;
      if (shouldCancel != _isCancelZone) {
        HapticFeedback.selectionClick();
      }
      setState(() {
        _dragOffset = delta;
        _isCancelZone = shouldCancel;
        _wavePhase = (_wavePhase + 1) % _baseWaveHeights.length;
      });
    }
  }

  void _onMicPointerUp(PointerUpEvent event) {
    if (!_isPointerDown) return;
    _isPointerDown = false;
    _holdDetectTimer?.cancel();

    if (_recordMode == VoiceRecordMode.idle) {
      // Quick click/tap (< 240ms) -> start hands-free voice recording!
      _enterTapRecording();
      return;
    }

    if (_recordMode == VoiceRecordMode.holdPushToTalk) {
      if (_isCancelZone) {
        _cancelRecording();
      } else {
        _finishAndProcessRecording();
      }
      return;
    }

    if (_recordMode == VoiceRecordMode.tapRecording) {
      if (_isCancelZone) {
        _cancelRecording();
      } else {
        // Clicking the active mic button again in tap-recording mode finishes it
        _finishAndProcessRecording();
      }
    }
  }

  void _onMicPointerCancel(PointerCancelEvent event) {
    _holdDetectTimer?.cancel();
    if (_recordMode == VoiceRecordMode.holdPushToTalk) {
      _cancelRecording();
    } else {
      setState(() {
        _isPointerDown = false;
        _dragOffset = Offset.zero;
        _isCancelZone = false;
      });
    }
  }

  String get _formattedTimer {
    final mins = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final idx = _effectiveIndex;
    final isRecording = _recordMode != VoiceRecordMode.idle;
    final isPtt = _recordMode == VoiceRecordMode.holdPushToTalk;

    return SizedBox(
      height: 110,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // Floating Cancelled Feedback Pill
          if (_showCancelledBanner && !isRecording)
            Positioned(
              bottom: 100,
              child: Container(
                key: const Key('voice_cancelled_banner'),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: AppColors.heroDark,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.darkBorder),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1E0B1220),
                      blurRadius: 14,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: AppColors.expenseRoseBright,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Rekaman suara dibatalkan',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Floating Live Recording HUD Card (Compact Nordic Ledger Voice Strip)
          if (isRecording)
            Positioned(
              bottom: 100,
              left: 16,
              right: 16,
              child: _buildFloatingRecordingHud(),
            ),

          // Bottom Bar Container (94px at bottom; top 16px left & right is 100% transparent)
          Container(
            height: 94,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              border: Border(
                top: BorderSide(
                  color: AppColors.border,
                  width: 1,
                ),
              ),
            ),
            padding:
                const EdgeInsets.only(top: 10, bottom: 14, left: 16, right: 16),
            child: isRecording
                ? _buildActiveRecordingBottomRow(isPtt: isPtt)
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _NavTabItem(
                        label: 'Kas',
                        icon: Icons.home_outlined,
                        isActive: idx == 0,
                        onTap: () => _handleTabTap(context, 0),
                      ),
                      _NavTabItem(
                        label: 'Nota',
                        icon: Icons.description_outlined,
                        isActive: idx == 1,
                        onTap: () => _handleTabTap(context, 1),
                      ),
                      const SizedBox(width: 64),
                      _NavTabItem(
                        label: 'Laporan',
                        icon: Icons.bar_chart_rounded,
                        isActive: idx == 2,
                        width: 64,
                        onTap: () => _handleTabTap(context, 2),
                      ),
                      _NavTabItem(
                        label: 'Akun',
                        icon: Icons.person_outline_rounded,
                        isActive: idx == 3,
                        onTap: () => _handleTabTap(context, 3),
                      ),
                    ],
                  ),
          ),

          // Center Floating 56x56 Mic Button
          Positioned(
            top: 0,
            child: Transform.translate(
              offset: isRecording
                  ? Offset(
                      _dragOffset.dx.clamp(-135.0, 135.0),
                      _dragOffset.dy.clamp(-110.0, 20.0),
                    )
                  : Offset.zero,
              child: Listener(
                key: const Key('btn_bicara_mic'),
                behavior: HitTestBehavior.translucent,
                onPointerDown: _onMicPointerDown,
                onPointerMove: _onMicPointerMove,
                onPointerUp: _onMicPointerUp,
                onPointerCancel: _onMicPointerCancel,
                child: SizedBox(
                  width: 68,
                  height: 80,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: isRecording ? 58 : 56,
                        height: isRecording ? 58 : 56,
                        decoration: BoxDecoration(
                          color: _isCancelZone
                              ? AppColors.expenseRose
                              : (isRecording
                                  ? AppColors.primaryTeal
                                  : AppColors.heroDark),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.surface,
                            width: 3.5,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x220B1220),
                              blurRadius: 14,
                              offset: Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Icon(
                          _isCancelZone
                              ? Icons.delete_outline_rounded
                              : (isRecording
                                  ? (isPtt
                                      ? Icons.mic_rounded
                                      : Icons.stop_rounded)
                                  : Icons.mic_none_rounded),
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _isCancelZone
                            ? 'Batal'
                            : (isRecording
                                ? (isPtt ? 'Lepas Kirim' : 'Berhenti')
                                : 'Bicara'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: _isCancelZone
                              ? AppColors.expenseRose
                              : (isRecording
                                  ? AppColors.primaryTeal
                                  : AppColors.textPrimary),
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
    );
  }

  Widget _buildActiveRecordingBottomRow({required bool isPtt}) {
    if (isPtt) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isCancelZone
                      ? Icons.delete_outline_rounded
                      : Icons.chevron_left_rounded,
                  size: 18,
                  color: _isCancelZone
                      ? AppColors.expenseRose
                      : AppColors.textMuted,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    _isCancelZone
                        ? 'Lepas untuk Batal!'
                        : '« Geser untuk batal',
                    key: const Key('ptt_slide_cancel_hint'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _isCancelZone
                          ? AppColors.expenseRose
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 68),
          Flexible(
            child: Text(
              'Lepas jari untuk simpan',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      );
    }

    // Mode Klik (Hands-Free): Clean Batal button on Left, Mic in Center, Selesai button on Right
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          key: const Key('btn_voice_cancel'),
          onTap: _cancelRecording,
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.close_rounded,
                  size: 15,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Batal',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 72),
        GestureDetector(
          key: const Key('btn_voice_done'),
          onTap: _finishAndProcessRecording,
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.heroDark,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_rounded,
                  size: 15,
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
                Text(
                  'Selesai',
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
      ],
    );
  }

  Widget _buildFloatingRecordingHud() {
    final hasLiveText = _liveRecognizedText.trim().isNotEmpty;
    final placeholderPrompt = widget.currentIndex == 1
        ? 'Contoh: "Tagih Pak Reza 500 ribu tempo minggu depan"'
        : 'Contoh: "Beli bensin 35 ribu tunai"';

    return Container(
      key: const Key('voice_recording_hud'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.heroDark,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _isCancelZone
              ? AppColors.expenseRose.withValues(alpha: 0.5)
              : AppColors.darkBorder,
          width: 1,
        ),
        boxShadow: AppColors.heroShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Row 1: Live Dot + Timer + Status + Minimal Equalizer + Mode Tag
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _isCancelZone
                      ? AppColors.expenseRoseBright
                      : AppColors.incomeEmeraldBright,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formattedTimer,
                style: AppTheme.numStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _isCancelZone ? 'LEPAS UNTUK BATAL' : 'Mendengarkan...',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _isCancelZone
                        ? AppColors.expenseRoseBright
                        : AppColors.darkTextMuted,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Compact 7-bar minimal waveform inline
              SizedBox(
                height: 18,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(7, (i) {
                    final shiftedIndex =
                        (i * 2 + _wavePhase) % _baseWaveHeights.length;
                    final rawH = _baseWaveHeights[shiftedIndex];
                    final h = _isCancelZone
                        ? 4.0
                        : (rawH * 0.65).clamp(4.0, 18.0);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1.5),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        width: 2.5,
                        height: h,
                        decoration: BoxDecoration(
                          color: _isCancelZone
                              ? AppColors.expenseRoseBright
                              : (i.isEven
                                  ? AppColors.primaryTealBright
                                  : AppColors.darkTextMuted),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.darkBorder),
          const SizedBox(height: 10),

          // Row 2: Clean single-surface live transcript or natural hint
          if (_isCancelZone)
            Row(
              children: [
                const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.expenseRoseBright,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Lepaskan jari sekarang untuk membatalkan rekaman suara.',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            )
          else
            Text(
              hasLiveText ? '"$_liveRecognizedText"' : placeholderPrompt,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.5,
                fontWeight: hasLiveText ? FontWeight.w600 : FontWeight.w500,
                height: 1.4,
                color: hasLiveText ? Colors.white : AppColors.darkTextMuted,
              ),
            ),
        ],
      ),
    );
  }
}

class _NavTabItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final double width;
  final VoidCallback onTap;

  const _NavTabItem({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
    this.width = 56,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.primaryTeal : AppColors.textMuted;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: width,
        height: 56,
        decoration: BoxDecoration(
          color: isActive ? AppColors.primaryTealSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
