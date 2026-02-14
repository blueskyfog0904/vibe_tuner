import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/permission_manager.dart';
import '../../domain/entities/tuning_result.dart';
import '../providers/tuner_state_provider.dart';

class TunerTestUI extends ConsumerStatefulWidget {
  const TunerTestUI({super.key});

  @override
  ConsumerState<TunerTestUI> createState() => _TunerTestUIState();
}

class _TunerTestUIState extends ConsumerState<TunerTestUI> with WidgetsBindingObserver {
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
    final granted = await PermissionManager().isMicrophonePermissionGranted();
    if (mounted) {
      setState(() => _isPermissionGranted = granted);
    }
  }

  Future<void> _requestPermission() async {
    final result = await PermissionManager().requestMicrophonePermission();
    if (result.isRight() && mounted) {
      setState(() => _isPermissionGranted = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tuningResult = _isPermissionGranted ? ref.watch(tunerStateProvider) : TuningResult.noSignal();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text("Phase 2: Pitch Engine Test")),
      body: Center(
        child: _isPermissionGranted 
            ? _buildTunerDisplay(tuningResult)
            : ElevatedButton(
                onPressed: _requestPermission, 
                child: const Text("마이크 권한 요청")
              ),
      ),
    );
  }

  Widget _buildTunerDisplay(TuningResult result) {
    Color statusColor;
    String statusText;

    switch (result.status) {
      case TuningStatus.perfect:
        statusColor = Colors.green;
        statusText = "PERFECT";
        break;
      case TuningStatus.tooHigh:
        statusColor = Colors.orange;
        statusText = "Too High (낮추세요)";
        break;
      case TuningStatus.tooLow:
        statusColor = Colors.orange;
        statusText = "Too Low (높이세요)";
        break;
      case TuningStatus.noSignal:
        statusColor = Colors.grey;
        statusText = "No Signal";
        break;
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          result.noteName,
          style: TextStyle(
            fontSize: 120, 
            fontWeight: FontWeight.bold, 
            color: statusColor
          ),
        ),
        Text(
          "Octave: ${result.octave}",
          style: const TextStyle(color: Colors.white70, fontSize: 24),
        ),
        const SizedBox(height: 32),
        Text(
          "${result.frequency.toStringAsFixed(1)} Hz",
          style: const TextStyle(color: Colors.white, fontSize: 32),
        ),
        const SizedBox(height: 16),
        Text(
          "Error: ${result.cents.toStringAsFixed(1)} cents",
          style: TextStyle(color: statusColor, fontSize: 24),
        ),
        const SizedBox(height: 48),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: statusColor, width: 2),
          ),
          child: Text(
            statusText,
            style: TextStyle(color: statusColor, fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
