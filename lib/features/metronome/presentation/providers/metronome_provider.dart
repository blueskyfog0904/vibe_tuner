import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/metronome_state.dart';
import '../../domain/logic/metronome_engine.dart';

final metronomeProvider =
    NotifierProvider<MetronomeNotifier, MetronomeState>(MetronomeNotifier.new);

class MetronomeNotifier extends Notifier<MetronomeState> {
  late final MetronomeEngine _engine;
  AppLifecycleListener? _appLifecycleListener;

  @override
  MetronomeState build() {
    _engine = MetronomeEngine(
      onStateChanged: (s) {
        state = s;
      },
    );

    _appLifecycleListener = AppLifecycleListener(
      onStateChange: _engine.handleLifecycle,
    );

    ref.onDispose(() {
      _appLifecycleListener?.dispose();
      _engine.dispose();
    });

    return _engine.state;
  }

  void start() => _engine.start();

  void stop({bool resetBeat = true}) => _engine.stop(resetBeat: resetBeat);

  void setBpm(int bpm) => _engine.setBpm(bpm);

  void setBeatsPerMeasure(int beats) => _engine.setBeatsPerMeasure(beats);
}
