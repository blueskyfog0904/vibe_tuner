import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/utils/permission_manager.dart';
import '../../../../core/logging/error_reporter.dart';
import '../../domain/entities/tuner_settings.dart';
import '../../domain/entities/tuning_result.dart';
import '../providers/tuner_state_provider.dart';
import '../providers/tuner_settings_provider.dart';
import 'tuner_settings_page.dart';

enum TunerStability { unknown, unstable, settling, stable }

class TunerPage extends ConsumerStatefulWidget {
  const TunerPage({super.key});

  @override
  ConsumerState<TunerPage> createState() => _TunerPageState();
}

class _TunerPageState extends ConsumerState<TunerPage> with WidgetsBindingObserver {
  final Queue<double> _recentCents = Queue<double>();
  bool _isPermissionGranted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _requestPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermission();
    }
  }

  Future<void> _checkPermission() async {
    try {
      final granted = await PermissionManager().isMicrophonePermissionGranted();
      if (mounted) {
        setState(() => _isPermissionGranted = granted);
      }
    } catch (error, stackTrace) {
      AppErrorReporter.reportNonFatal(
        error,
        stackTrace,
        source: 'tuner_page.check_permission',
      );
    }
  }

  Future<void> _requestPermission() async {
    try {
      final result = await PermissionManager().requestMicrophonePermission();
      if (result.isRight() && mounted) {
        setState(() => _isPermissionGranted = true);
      }
    } catch (error, stackTrace) {
      AppErrorReporter.reportNonFatal(
        error,
        stackTrace,
        source: 'tuner_page.request_permission',
      );
    }
  }

  void _pushCentsHistory(TuningResult result) {
    if (result.status == TuningStatus.noSignal) {
      _recentCents.clear();
      return;
    }
    _recentCents.add(result.cents);
    while (_recentCents.length > 12) {
      _recentCents.removeFirst();
    }
  }

  @override
  Widget build(BuildContext context) {
    final result =
        _isPermissionGranted ? ref.watch(tunerStateProvider) : TuningResult.noSignal();
    final settings = ref.watch(tunerSettingsProvider).valueOrNull ??
        const TunerSettings.defaults();

    _pushCentsHistory(result);
    final stability = assessStability(_recentCents.toList(growable: false));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tuner'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const TunerSettingsPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: _isPermissionGranted
            ? Padding(
                padding: const EdgeInsets.all(20),
                child: TunerReadout(
                  result: result,
                  stability: stability,
                  tuningPresetLabel: tuningPresetLabel(settings.tuningPreset),
                ),
              )
            : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('마이크 권한이 필요합니다.'),
                    const SizedBox(height: 4),
                    const Text(
                      '실시간 음정 분석을 위해 마이크 접근이 필요합니다.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _requestPermission,
                      child: const Text('권한 요청'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: openAppSettings,
                      child: const Text('설정 열기'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class TunerReadout extends StatelessWidget {
  final TuningResult result;
  final TunerStability stability;
  final String tuningPresetLabel;

  const TunerReadout({
    super.key,
    required this.result,
    required this.stability,
    required this.tuningPresetLabel,
  });

  @override
  Widget build(BuildContext context) {
    final presentation = presentationForStatus(result.status);
    final noteLabel = result.status == TuningStatus.noSignal
        ? '--'
        : '${result.noteName}${result.octave}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          noteLabel,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 88,
            fontWeight: FontWeight.w800,
            color: presentation.color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          presentation.label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: presentation.color,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          tuningPresetLabel,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _ValueCard(
              title: 'Current',
              value: result.status == TuningStatus.noSignal
                  ? '--'
                  : '${result.frequency.toStringAsFixed(1)} Hz',
            ),
            _ValueCard(
              title: 'Target',
              value: result.status == TuningStatus.noSignal
                  ? '--'
                  : '${result.targetFrequency.toStringAsFixed(1)} Hz',
            ),
            _ValueCard(
              title: 'Cents',
              value: result.status == TuningStatus.noSignal
                  ? '--'
                  : '${result.cents >= 0 ? '+' : ''}${result.cents.toStringAsFixed(1)}',
            ),
          ],
        ),
        const SizedBox(height: 24),
        TuningMeter(
          cents: result.status == TuningStatus.noSignal ? 0 : result.cents,
          markerColor: presentation.color,
        ),
        const SizedBox(height: 16),
        _StabilityBadge(stability: stability),
      ],
    );
  }
}

class TuningMeter extends StatelessWidget {
  final double cents;
  final Color markerColor;

  const TuningMeter({
    super.key,
    required this.cents,
    required this.markerColor,
  });

  @override
  Widget build(BuildContext context) {
    const maxRange = 50.0;
    final normalized = (cents.clamp(-maxRange, maxRange) + maxRange) / (2 * maxRange);

    return Column(
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('-50'),
            Text('0'),
            Text('+50'),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final markerLeft = (width * normalized).clamp(0.0, width);
            return SizedBox(
              height: 24,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      height: 6,
                      margin: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Positioned(
                    left: width / 2 - 1,
                    top: 2,
                    bottom: 2,
                    child: Container(width: 2, color: Colors.black87),
                  ),
                  Positioned(
                    left: markerLeft - 8,
                    top: 4,
                    child: Icon(Icons.arrow_drop_up, color: markerColor, size: 20),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ValueCard extends StatelessWidget {
  final String title;
  final String value;

  const _ValueCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 92),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _StabilityBadge extends StatelessWidget {
  final TunerStability stability;

  const _StabilityBadge({required this.stability});

  @override
  Widget build(BuildContext context) {
    final label = stabilityLabel(stability);
    final color = switch (stability) {
      TunerStability.stable => Colors.green,
      TunerStability.settling => Colors.orange,
      TunerStability.unstable => Colors.red,
      TunerStability.unknown => Colors.grey,
    };

    return Align(
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color),
        ),
        child: Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class TunerStatusPresentation {
  final String label;
  final Color color;

  const TunerStatusPresentation(this.label, this.color);
}

TunerStatusPresentation presentationForStatus(TuningStatus status) {
  return switch (status) {
    TuningStatus.perfect => const TunerStatusPresentation('In Tune', Colors.green),
    TuningStatus.tooLow => const TunerStatusPresentation('Too Low', Colors.orange),
    TuningStatus.tooHigh => const TunerStatusPresentation('Too High', Colors.orange),
    TuningStatus.noSignal => const TunerStatusPresentation('No Signal', Colors.grey),
  };
}

TunerStability assessStability(List<double> centsHistory) {
  if (centsHistory.length < 4) return TunerStability.unknown;

  final mean =
      centsHistory.reduce((a, b) => a + b) / centsHistory.length;
  var variance = 0.0;
  for (final cents in centsHistory) {
    final diff = cents - mean;
    variance += diff * diff;
  }
  final stdDev = math.sqrt(variance / centsHistory.length);

  if (stdDev <= 2.0) return TunerStability.stable;
  if (stdDev <= 5.0) return TunerStability.settling;
  return TunerStability.unstable;
}

String stabilityLabel(TunerStability stability) {
  return switch (stability) {
    TunerStability.stable => 'STABLE',
    TunerStability.settling => 'SETTLING',
    TunerStability.unstable => 'UNSTABLE',
    TunerStability.unknown => 'ANALYZING',
  };
}

String tuningPresetLabel(TuningPreset preset) {
  return switch (preset) {
    TuningPreset.chromatic => 'Preset: Chromatic',
    TuningPreset.guitarStandard => 'Preset: Guitar Standard',
    TuningPreset.ukuleleStandard => 'Preset: Ukulele Standard',
  };
}
