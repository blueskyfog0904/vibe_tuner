import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/tuner_settings.dart';
import '../providers/tuner_settings_provider.dart';
import 'error_logs_page.dart';

class TunerSettingsPage extends ConsumerWidget {
  const TunerSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings =
        ref.watch(tunerSettingsProvider).valueOrNull ??
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
              ButtonSegment(
                value: TunerSensitivity.medium,
                label: Text('Medium'),
              ),
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
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Low Latency Tuner'),
            subtitle: const Text(
              'Faster response, less lingering after note-off',
            ),
            value: settings.lowLatencyMode,
            onChanged: notifier.setLowLatencyMode,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: notifier.applyIphone11ProGuitarPreset,
            icon: const Icon(Icons.phone_iphone),
            label: const Text('Apply iPhone 11 Pro Guitar Preset'),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: notifier.applyIndoorQuietGuitarPreset,
            icon: const Icon(Icons.music_note),
            label: const Text('Apply Indoor Quiet Guitar Preset'),
          ),
          const SizedBox(height: 24),
          const Text(
            'Per-String Sensitivity (1-6)',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Higher value = more sensitive',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 8),
          for (int stringNumber = 1; stringNumber <= 6; stringNumber++) ...[
            Text(
              '${stringSensitivityLabel(stringNumber)} '
              '(${settings.sensitivityForString(stringNumber).toStringAsFixed(2)})',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Sensitivity (${settings.sensitivityForString(stringNumber).toStringAsFixed(2)})',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            Text(
              'Range: ${minStringSensitivity.toStringAsFixed(1)} ~ ${maxStringSensitivity.toStringAsFixed(1)}',
              style: const TextStyle(fontSize: 11, color: Colors.black45),
            ),
            Slider(
              min: minStringSensitivity,
              max: maxStringSensitivity,
              divisions: 45,
              value: settings.sensitivityForString(stringNumber),
              onChanged: (value) {
                notifier.setStringSensitivity(stringNumber, value);
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'min ${minStringSensitivity.toStringAsFixed(1)}',
                  style: const TextStyle(fontSize: 11, color: Colors.black45),
                ),
                Text(
                  'max ${maxStringSensitivity.toStringAsFixed(1)}',
                  style: const TextStyle(fontSize: 11, color: Colors.black45),
                ),
              ],
            ),
            Text(
              'Sustain Hold (${settings.holdMsForString(stringNumber)} ms)',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            Text(
              'Range: $minStringHoldMs ~ $maxStringHoldMs ms',
              style: const TextStyle(fontSize: 11, color: Colors.black45),
            ),
            Slider(
              min: minStringHoldMs.toDouble(),
              max: maxStringHoldMs.toDouble(),
              divisions: (maxStringHoldMs - minStringHoldMs) ~/ 20,
              value: settings.holdMsForString(stringNumber).toDouble(),
              onChanged: (value) {
                notifier.setStringHoldMs(stringNumber, value.round());
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'min $minStringHoldMs ms',
                  style: const TextStyle(fontSize: 11, color: Colors.black45),
                ),
                Text(
                  'max $maxStringHoldMs ms',
                  style: const TextStyle(fontSize: 11, color: Colors.black45),
                ),
              ],
            ),
            Text(
              'Stability (${settings.stabilityWindowForString(stringNumber)})',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            Text(
              'Range: $minStringStabilityWindow ~ $maxStringStabilityWindow',
              style: const TextStyle(fontSize: 11, color: Colors.black45),
            ),
            Slider(
              min: minStringStabilityWindow.toDouble(),
              max: maxStringStabilityWindow.toDouble(),
              divisions: maxStringStabilityWindow - minStringStabilityWindow,
              value: settings.stabilityWindowForString(stringNumber).toDouble(),
              onChanged: (value) {
                notifier.setStringStabilityWindow(stringNumber, value.round());
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'min $minStringStabilityWindow',
                  style: const TextStyle(fontSize: 11, color: Colors.black45),
                ),
                Text(
                  'max $maxStringStabilityWindow',
                  style: const TextStyle(fontSize: 11, color: Colors.black45),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          const SizedBox(height: 20),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.bug_report_outlined),
            title: const Text('Error Logs'),
            subtitle: const Text('최근 에러 확인 및 복사'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const ErrorLogsPage()));
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
