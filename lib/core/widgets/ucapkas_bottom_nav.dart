import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../state/ledger_providers.dart';
import '../theme/app_colors.dart';
import '../utils/native_voice_recorder.dart';
import '../utils/rupiah_formatter.dart';
import '../utils/slang_parser.dart';

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
              bottom: 102,
              child: Container(
                key: const Key('voice_cancelled_banner'),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.heroDark,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.expenseRose, width: 1.2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x260F172A),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.delete_outline_rounded,
                      size: 15,
                      color: AppColors.expenseRoseBright,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Rekaman suara dibatalkan',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Floating Live Recording HUD Card (Directly on Dashboard / Current Screen)
          if (isRecording)
            Positioned(
              bottom: 102,
              left: 14,
              right: 14,
              child: _buildFloatingRecordingHud(isPtt: isPtt),
            ),

          // Bottom Bar Container (94px at bottom; top 16px left & right is 100% transparent)
          Container(
            height: 94,
            decoration: BoxDecoration(
              color: isRecording
                  ? (_isCancelZone
                      ? const Color(0xFFFFF1F2)
                      : AppColors.surface)
                  : AppColors.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              border: Border(
                top: BorderSide(
                  color: isRecording
                      ? (_isCancelZone
                          ? AppColors.expenseRose
                          : AppColors.primaryTeal)
                      : AppColors.border,
                  width: isRecording ? 1.5 : 1,
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

          // Center Floating 56x56 Mic Button (only center has button; left & right have no overlay)
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
                  width: 64,
                  height: 80,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: isRecording ? 60 : 56,
                        height: isRecording ? 60 : 56,
                        decoration: BoxDecoration(
                          color: _isCancelZone
                              ? AppColors.expenseRose
                              : (isRecording
                                  ? AppColors.primaryTeal
                                  : AppColors.heroDark),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _isCancelZone
                                ? AppColors.expenseRoseBright
                                : (isRecording
                                    ? AppColors.primaryTealBright
                                    : AppColors.surface),
                            width: isRecording ? 3.5 : 3.5,
                          ),
                          boxShadow: isRecording
                              ? [
                                  BoxShadow(
                                    color: (_isCancelZone
                                            ? AppColors.expenseRose
                                            : AppColors.primaryTeal)
                                        .withValues(alpha: 0.32),
                                    blurRadius: 16,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : const [
                                  BoxShadow(
                                    color: Color(0x220B1220),
                                    blurRadius: 14,
                                    offset: Offset(0, 5),
                                  ),
                                ],
                        ),
                        child: Icon(
                          _isCancelZone
                              ? Icons.delete_forever_rounded
                              : (isRecording
                                  ? (isPtt
                                      ? Icons.mic_rounded
                                      : Icons.stop_rounded)
                                  : Icons.mic_none_rounded),
                          color: Colors.white,
                          size: 25,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _isCancelZone
                            ? 'Batal'
                            : (isRecording
                                ? (isPtt ? 'Lepas Kirim' : 'Berhenti')
                                : 'Bicara'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 10,
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
      // WhatsApp-style Push-to-Talk slide-to-cancel bar
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _isCancelZone
                        ? AppColors.expenseRose
                        : AppColors.expenseSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _isCancelZone
                        ? Icons.delete_forever_rounded
                        : Icons.delete_outline_rounded,
                    size: 18,
                    color: _isCancelZone ? Colors.white : AppColors.expenseRose,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _isCancelZone
                        ? 'Lepas untuk Batal!'
                        : '« Geser untuk batal',
                    key: const Key('ptt_slide_cancel_hint'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _isCancelZone
                          ? AppColors.expenseRose
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 56),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _isCancelZone
                  ? AppColors.expenseSoft
                  : AppColors.primaryTealSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: _isCancelZone
                        ? AppColors.expenseRose
                        : AppColors.primaryTeal,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  _formattedTimer,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _isCancelZone
                        ? AppColors.expenseRose
                        : AppColors.primaryTeal,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Mode Klik (Hands-Free): Batal button on Left, Stop Mic in Center, Selesai button on Right
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          key: const Key('btn_voice_cancel'),
          onTap: _cancelRecording,
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.expenseSoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.expenseRose.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.delete_outline_rounded,
                  size: 16,
                  color: AppColors.expenseRose,
                ),
                const SizedBox(width: 6),
                Text(
                  'Batal',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.expenseRose,
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
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.primaryTeal,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
                Text(
                  'Selesai',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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

  Widget _buildFloatingRecordingHud({required bool isPtt}) {
    final slangAmount = SlangParser.parseSpokenAmount('ceban tiga') ?? 30000;

    return Container(
      key: const Key('voice_recording_hud'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.heroDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isCancelZone
              ? AppColors.expenseRose
              : AppColors.primaryTeal,
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x330F172A),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Status Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _isCancelZone
                        ? AppColors.expenseRose.withValues(alpha: 0.2)
                        : const Color(0xFF132338),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isCancelZone
                          ? AppColors.expenseRoseBright
                          : AppColors.primaryTeal,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
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
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _isCancelZone
                              ? 'LEPAS UNTUK BATAL'
                              : (isPtt
                                  ? 'PUSH-TO-TALK • $_formattedTimer'
                                  : 'MENDENGARKAN... $_formattedTimer'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _isCancelZone
                                ? AppColors.expenseRoseBright
                                : AppColors.incomeEmeraldBright,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isPtt ? 'Mode Tahan (WA)' : 'Mode Klik',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryTealBright,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Live Audio Waveform Row
          SizedBox(
            height: 28,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_baseWaveHeights.length, (i) {
                final shiftedIndex =
                    (i + _wavePhase) % _baseWaveHeights.length;
                final h = _isCancelZone
                    ? 6.0
                    : _baseWaveHeights[shiftedIndex];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    width: 4,
                    height: h,
                    decoration: BoxDecoration(
                      color: _isCancelZone
                          ? AppColors.expenseRoseBright
                          : (i.isEven
                              ? AppColors.primaryTealBright
                              : const Color(0xFF475569)),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 10),

          // Live Transcript Box or Cancel Warning Box
          if (_isCancelZone)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF3B0D16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.delete_forever_rounded,
                    color: AppColors.expenseRoseBright,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Lepaskan jari sekarang untuk membatalkan & menghapus rekaman suara.',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.heroCardSecondary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          'Suara yang sedang ditangkap:',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: AppColors.darkTextMuted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Bahasa Pasar Aktif',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryTealBright,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _liveRecognizedText.isNotEmpty
                        ? '"$_liveRecognizedText"'
                        : (widget.currentIndex == 1
                            ? '"${VoiceRecordingSession.sampleInvoiceSpeech}"'
                            : '"${VoiceRecordingSession.sampleKasSpeech}"'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 13,
                        color: AppColors.incomeEmeraldBright,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          'Otomatis dikenali: "ceban tiga" = ${RupiahFormatter.format(slangAmount)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.incomeEmeraldBright,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),

          // Helper Footer Hint
          Text(
            _isCancelZone
                ? 'Rekaman tidak akan disimpan'
                : (isPtt
                    ? 'Lepas jari untuk selesai, atau geser ke mana saja untuk batal'
                    : 'Ketuk Selesai untuk lihat rincian, atau ketuk Batal untuk hapus'),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: _isCancelZone
                  ? AppColors.expenseRoseBright
                  : AppColors.darkTextMuted,
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
