import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/theme/app_theme.dart';

enum _TimerMode { countdown, countUp }

class CountdownScreen extends StatefulWidget {
  const CountdownScreen({super.key});
  @override
  State<CountdownScreen> createState() => _CountdownScreenState();
}

class _CountdownScreenState extends State<CountdownScreen> with WidgetsBindingObserver {
  static const _presets = [15, 25, 45, 60];

  int _plannedSeconds = 25 * 60;
  _TimerMode _mode = _TimerMode.countdown;

  // The core fix for "timer breaks when app is backgrounded": we never
  // decrement a counter on a tick. We record wall-clock timestamps and
  // always recompute elapsed/remaining from DateTime.now() minus those
  // timestamps, so background time is naturally accounted for.
  DateTime? _startedAt;
  Duration _accumulatedBeforePause = Duration.zero;
  bool _running = false;
  bool _completed = false;
  Timer? _uiTicker;
  bool _warned = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _uiTicker?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // No special handling needed for correctness — elapsed time is always
    // derived from timestamps — but we do stop the redundant UI ticker
    // while backgrounded to save battery, and restart it on resume.
    if (state == AppLifecycleState.paused) {
      _uiTicker?.cancel();
    } else if (state == AppLifecycleState.resumed && _running) {
      _startTicker();
      setState(() {});
    }
  }

  Duration get _elapsed {
    if (_startedAt == null) return _accumulatedBeforePause;
    if (!_running) return _accumulatedBeforePause;
    return _accumulatedBeforePause + DateTime.now().difference(_startedAt!);
  }

  Duration get _remaining {
    final r = Duration(seconds: _plannedSeconds) - _elapsed;
    return r.isNegative ? Duration.zero : r;
  }

  bool get _isOvertime => _mode == _TimerMode.countdown && _elapsed.inSeconds > _plannedSeconds;

  void _startTicker() {
    _uiTicker?.cancel();
    _uiTicker = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      setState(() {});
      if (_mode == _TimerMode.countdown &&
          !_warned &&
          _remaining.inSeconds <= 60 &&
          _remaining.inSeconds > 0) {
        _warned = true;
        HapticFeedback.mediumImpact();
      }
      if (_mode == _TimerMode.countdown && _remaining == Duration.zero && !_completed) {
        _completed = true;
        HapticFeedback.heavyImpact();
      }
    });
  }

  void _start() {
    setState(() {
      _startedAt = DateTime.now();
      _running = true;
      _completed = false;
      _warned = false;
    });
    WakelockPlus.enable();
    _startTicker();
  }

  void _pause() {
    setState(() {
      _accumulatedBeforePause = _elapsed;
      _startedAt = null;
      _running = false;
    });
    _uiTicker?.cancel();
    WakelockPlus.disable();
  }

  void _reset() {
    setState(() {
      _startedAt = null;
      _accumulatedBeforePause = Duration.zero;
      _running = false;
      _completed = false;
      _warned = false;
    });
    _uiTicker?.cancel();
    WakelockPlus.disable();
  }

  void _adjust(int minutes) {
    setState(() {
      _plannedSeconds = (_plannedSeconds + minutes * 60).clamp(60, 6 * 60 * 60);
    });
  }

  String _fmt(Duration d) {
    final neg = d.isNegative;
    final abs = d.abs();
    final h = abs.inHours;
    final m = abs.inMinutes.remainder(60);
    final s = abs.inSeconds.remainder(60);
    final str = h > 0
        ? '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
        : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return neg ? '+$str' : str;
  }

  @override
  Widget build(BuildContext context) {
    final display = _mode == _TimerMode.countdown
        ? (_isOvertime ? _elapsed - Duration(seconds: _plannedSeconds) : _remaining)
        : _elapsed;
    final overtimeLabel = _isOvertime;

    return Theme(
      data: AppTheme.dark(const Color(0xFF3B82F6)),
      child: Scaffold(
        backgroundColor: AppTheme.countdownBackground,
        appBar: AppBar(
          backgroundColor: AppTheme.countdownBackground,
          foregroundColor: AppTheme.countdownText,
          title: const Text('Focus timer'),
          actions: [
            IconButton(
              icon: Icon(_mode == _TimerMode.countdown ? Icons.timer : Icons.timer_outlined),
              tooltip: 'Toggle count-up / countdown',
              onPressed: _running
                  ? null
                  : () => setState(() =>
                      _mode = _mode == _TimerMode.countdown ? _TimerMode.countUp : _TimerMode.countdown),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              const Spacer(),
              if (overtimeLabel)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text('OVERTIME', style: TextStyle(color: Colors.redAccent, letterSpacing: 2)),
                ),
              Text(
                _fmt(display),
                style: TextStyle(
                  color: overtimeLabel ? Colors.redAccent : AppTheme.countdownText,
                  fontSize: 72,
                  fontWeight: FontWeight.w200,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    iconSize: 64,
                    color: Colors.white,
                    icon: Icon(_running ? Icons.pause_circle_filled : Icons.play_circle_fill),
                    onPressed: _running ? _pause : _start,
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    iconSize: 40,
                    color: Colors.white54,
                    icon: const Icon(Icons.replay),
                    onPressed: _reset,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (!_running)
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  children: [
                    _adjustChip('+5m', () => _adjust(5)),
                    _adjustChip('+1m', () => _adjust(1)),
                    _adjustChip('-1m', () => _adjust(-1)),
                  ],
                ),
              const Spacer(),
              if (!_running)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Wrap(
                    spacing: 10,
                    alignment: WrapAlignment.center,
                    children: _presets.map((m) {
                      final selected = _plannedSeconds == m * 60;
                      return ChoiceChip(
                        label: Text('$m min'),
                        selected: selected,
                        onSelected: (_) => setState(() => _plannedSeconds = m * 60),
                        labelStyle: TextStyle(color: selected ? Colors.black : Colors.white70),
                        backgroundColor: const Color(0xFF1D1F23),
                        selectedColor: Colors.white,
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _adjustChip(String label, VoidCallback onTap) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white24),
      ),
      child: Text(label),
    );
  }
}
