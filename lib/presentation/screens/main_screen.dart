import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vibetuner/core/logging/error_reporter.dart';
import 'package:vibetuner/features/chord_library/presentation/pages/chord_library_page.dart';
import 'package:vibetuner/features/ear_training/presentation/pages/game_screen.dart';
import 'package:vibetuner/features/metronome/presentation/pages/metronome_page.dart';
import 'package:vibetuner/features/metronome/presentation/providers/metronome_provider.dart';
import 'package:vibetuner/features/tuner_engine/presentation/pages/tuner_page.dart';
import 'package:vibetuner/features/tuner_engine/presentation/providers/tuner_state_provider.dart';
import 'package:vibetuner/features/ear_training/presentation/providers/game_controller.dart';

final mainTabProvider = StateProvider<int>((ref) => 0);

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateActiveTabContext(0);
    // Initial Resource Setup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _manageResources(0);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final currentIndex = ref.read(mainTabProvider);
    if (state == AppLifecycleState.resumed) {
      _manageResources(currentIndex);
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _suspendAudioResources();
    }
  }

  void _manageResources(int index) {
    final tunerNotifier = ref.read(tunerStateProvider.notifier);
    final gameNotifier = ref.read(gameControllerProvider.notifier);
    final metronomeNotifier = ref.read(metronomeProvider.notifier);

    if (index == 0) {
      // Tuner Active
      tunerNotifier.start();
      gameNotifier.stop();
      metronomeNotifier.stop(resetBeat: false);
    } else if (index == 1) {
      // Chord Library (No Audio)
      tunerNotifier.stop();
      gameNotifier.stop();
      metronomeNotifier.stop(resetBeat: false);
    } else if (index == 2) {
      // Ear Training Active
      tunerNotifier.stop();
      gameNotifier.start();
      metronomeNotifier.stop(resetBeat: false);
    } else if (index == 3) {
      // Metronome tab
      tunerNotifier.stop();
      gameNotifier.stop();
    }
  }

  void _suspendAudioResources() {
    final tunerNotifier = ref.read(tunerStateProvider.notifier);
    final gameNotifier = ref.read(gameControllerProvider.notifier);
    final metronomeNotifier = ref.read(metronomeProvider.notifier);
    tunerNotifier.stop();
    gameNotifier.stop();
    metronomeNotifier.stop(resetBeat: false);
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(mainTabProvider);

    // Listen to tab changes to manage resources
    ref.listen(mainTabProvider, (previous, next) {
      if (previous != next) {
        _updateActiveTabContext(next);
        _manageResources(next);
      }
    });

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: const [
          TunerPage(), // Tuner
          ChordLibraryPage(), // Chords
          GameScreen(), // Ear Training
          MetronomePage(), // Metronome
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) {
          ref.read(mainTabProvider.notifier).state = index;
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.graphic_eq), label: 'Tuner'),
          BottomNavigationBarItem(
            icon: Icon(Icons.library_books),
            label: 'Chords',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.gamepad),
            label: 'Ear Training',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.music_note),
            label: 'Metronome',
          ),
        ],
      ),
    );
  }

  void _updateActiveTabContext(int index) {
    AppErrorReporter.putGlobalContext('activeTab', _tabName(index));
    AppErrorReporter.putGlobalContext('activeTabIndex', index);
  }

  String _tabName(int index) {
    return switch (index) {
      0 => 'tuner',
      1 => 'chords',
      2 => 'ear_training',
      3 => 'metronome',
      _ => 'unknown',
    };
  }
}
