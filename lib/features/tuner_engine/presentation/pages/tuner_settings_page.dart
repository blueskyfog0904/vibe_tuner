import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/tuner_settings.dart';
import '../providers/tuner_settings_provider.dart';
import 'error_logs_page.dart';

class TunerSettingsPage extends ConsumerWidget {
  const TunerSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(tunerSettingsProvider).valueOrNull ??
        const TunerSettings.defaults();
    final notifier = ref.read(tunerSettingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Tuner Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'A4 Reference',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SegmentedButton<double>(
            segments: const [
              ButtonSegment(value: 440.0, label: Text('440 Hz')),
              ButtonSegment(value: 432.0, label: Text('432 Hz')),
            ],
            selected: {settings.a4Reference},
            onSelectionChanged: (selection) {
              notifier.setA4Reference(selection.first);
            },
          ),
          const SizedBox(height: 20),
          const Text(
            'Sensitivity',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SegmentedButton<TunerSensitivity>(
            segments: const [
              ButtonSegment(value: TunerSensitivity.low, label: Text('Low')),
              ButtonSegment(value: TunerSensitivity.medium, label: Text('Medium')),
              ButtonSegment(value: TunerSensitivity.high, label: Text('High')),
            ],
            selected: {settings.sensitivity},
            onSelectionChanged: (selection) {
              notifier.setSensitivity(selection.first);
            },
          ),
          const SizedBox(height: 20),
          Text(
            'Noise Gate (${settings.noiseGate.toStringAsFixed(3)})',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Slider(
            min: 0.001,
            max: 0.05,
            divisions: 49,
            value: settings.noiseGate,
            onChanged: notifier.setNoiseGate,
          ),
          const SizedBox(height: 20),
          const Text(
            'Tuning Preset',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<TuningPreset>(
            initialValue: settings.tuningPreset,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: TuningPreset.values
                .map(
                  (preset) => DropdownMenuItem(
                    value: preset,
                    child: Text(_presetLabel(preset)),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) notifier.setTuningPreset(value);
            },
          ),
          const SizedBox(height: 20),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.bug_report_outlined),
            title: const Text('Error Logs'),
            subtitle: const Text('최근 에러 확인 및 복사'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ErrorLogsPage(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

String _presetLabel(TuningPreset preset) {
  return switch (preset) {
    TuningPreset.chromatic => 'Chromatic',
    TuningPreset.guitarStandard => 'Guitar Standard (EADGBE)',
    TuningPreset.ukuleleStandard => 'Ukulele Standard (GCEA)',
  };
}
