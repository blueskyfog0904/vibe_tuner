import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import '../../domain/entities/quiz_item.dart';
import '../../domain/logic/game_engine.dart';
import '../../data/sources/tone_generator.dart';
import '../../../tuner_engine/domain/entities/tuning_result.dart';
import '../../../tuner_engine/presentation/providers/tuner_state_provider.dart';
import '../../../tuner_engine/domain/repositories/pitch_repository.dart';
import '../../../audio_processing/data/datasources/audio_stream_source.dart';
import '../../../audio_processing/presentation/providers/audio_state_provider.dart';
import 'package:audio_session/audio_session.dart';

enum GameStatus { idle, playingTone, listening, success, fail }

class GameState {
  final GameStatus status;
  final QuizItem? currentQuiz;
  final int score;
  final int combo;
  final GameDifficulty difficulty;
  final String? feedbackMessage;
  final double? currentInputFreq; // For debug/visual feedback
  final String? currentInputNote; // For debug/visual feedback

  const GameState({
    this.status = GameStatus.idle,
    this.currentQuiz,
    this.score = 0,
    this.combo = 0,
    this.difficulty = GameDifficulty.easy,
    this.feedbackMessage,
    this.currentInputFreq,
    this.currentInputNote,
  });

  GameState copyWith({
    GameStatus? status,
    QuizItem? currentQuiz,
    int? score,
    int? combo,
    GameDifficulty? difficulty,
    String? feedbackMessage,
    double? currentInputFreq,
    String? currentInputNote,
  }) {
    return GameState(
      status: status ?? this.status,
      currentQuiz: currentQuiz ?? this.currentQuiz,
      score: score ?? this.score,
      combo: combo ?? this.combo,
      difficulty: difficulty ?? this.difficulty,
      feedbackMessage: feedbackMessage ?? this.feedbackMessage,
      currentInputFreq: currentInputFreq ?? this.currentInputFreq,
      currentInputNote: currentInputNote ?? this.currentInputNote,
    );
  }
}

final gameControllerProvider = StateNotifierProvider.autoDispose<GameController, GameState>((ref) {
  final toneGenerator = ToneGenerator();
  toneGenerator.initialize();
  
  final gameEngine = GameEngine();
  final pitchRepo = ref.watch(pitchRepositoryProvider);
  final audioSource = ref.watch(audioSourceProvider);
  
  return GameController(toneGenerator, gameEngine, pitchRepo, audioSource);
});

class GameController extends StateNotifier<GameState> {
  final ToneGenerator _toneGenerator;
  final GameEngine _gameEngine;
  final PitchRepository _pitchRepo;
  final AudioStreamSource _audioSource;
  
  StreamSubscription? _pitchSubscription;
  StreamSubscription? _audioSubscription;
  final _logger = Logger('GameController');
  final Random _random = Random();

  // Simple note map for quiz generation (A4 scale)
  final Map<String, double> _noteMap = {
    'C4': 261.63, 'D4': 293.66, 'E4': 329.63, 
    'F4': 349.23, 'G4': 392.00, 'A4': 440.00, 'B4': 493.88
  };

  GameController(this._toneGenerator, this._gameEngine, this._pitchRepo, this._audioSource)
      : super(const GameState()) {
    // start(); // Auto-start for now, but MainScreen will control it.
  }

  Future<void> start() async {
    if (_audioSubscription != null) return; // Already started

    // 0. Configure Audio Session (Vital for iOS PlayAndRecord)
    final session = await AudioSession.instance;
    await session.configure(AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
      avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.defaultToSpeaker | AVAudioSessionCategoryOptions.allowBluetooth | AVAudioSessionCategoryOptions.allowAirPlay,
      avAudioSessionMode: AVAudioSessionMode.defaultMode,
      avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
      avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
      androidAudioAttributes: const AndroidAudioAttributes(
        contentType: AndroidAudioContentType.music,
        flags: AndroidAudioFlags.none,
        usage: AndroidAudioUsage.game,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      androidWillPauseWhenDucked: true,
    ));

    // 1. Initialize Pitch Repo
    await _pitchRepo.initialize();
    
    // 2. Connect Audio Source to Pitch Repo
    _audioSubscription = _audioSource.audioStream.listen((buffer) {
      _pitchRepo.addAudioData(buffer);
    });

    // 3. Start Audio Capture
    final result = await _audioSource.startCapture();
    result.fold(
      (failure) => _logger.warning("Failed to start audio capture: ${failure.message}"),
      (_) => _logger.info("Audio capture started for Ear Training")
    );
  }

  Future<void> stop() async {
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    await _pitchSubscription?.cancel();
    _pitchSubscription = null;
    await _audioSource.stopCapture();
    await _toneGenerator.stop();
  }

  @override
  void dispose() {
    stop();
    _toneGenerator.dispose();
    super.dispose();
  }

  void setDifficulty(GameDifficulty difficulty) {
    state = state.copyWith(difficulty: difficulty);
  }

  Future<void> startGame() async {
    _logger.info("Starting Game...");
    // Reset Score
    state = state.copyWith(score: 0, combo: 0, status: GameStatus.idle);
    await _nextLevel();
  }

  Future<void> _nextLevel() async {
    // 1. Generate Quiz
    final keys = _noteMap.keys.toList();
    final randomKey = keys[_random.nextInt(keys.length)];
    final targetFreq = _noteMap[randomKey]!;
    
    final quiz = QuizItem(noteName: randomKey, frequency: targetFreq);
    
    // 2. State -> Playing Tone
    state = state.copyWith(
      status: GameStatus.playingTone,
      currentQuiz: quiz,
      feedbackMessage: "Listen carefully...",
    );

    // 3. Play Tone (Ignore Input implicitly by not listening yet)
    // Play for 2 seconds
    await _toneGenerator.playTone(targetFreq, duration: const Duration(milliseconds: 1500));
    
    // Wait a bit for fade out
    await Future.delayed(const Duration(milliseconds: 1600));

    // 4. Start Listening
    _startListening();
  }

  Future<void> replayTone() async {
    if (state.currentQuiz != null) {
        // Temporarily ignore input? Or just play over it? 
        // Let's pause listening briefly to avoid self-feedback loop if volume is loud
        final previousStatus = state.status;
        state = state.copyWith(status: GameStatus.playingTone, feedbackMessage: "Listen again...");
        
        await _toneGenerator.playTone(state.currentQuiz!.frequency, duration: const Duration(seconds: 1));
        await Future.delayed(const Duration(milliseconds: 1100));
        
        state = state.copyWith(status: previousStatus, feedbackMessage: "Now, play the note!");
    }
  }

  void _startListening() {
    if (!mounted) return;
    
    state = state.copyWith(
      status: GameStatus.listening,
      feedbackMessage: "Now, play the note!",
    );

    _pitchSubscription?.cancel();
    _pitchSubscription = _pitchRepo.pitchStream.listen((result) {
      if (!mounted) return;
      if (state.status != GameStatus.listening) return;
      
      // Ignore 'No Signal'
      if (result.status == TuningStatus.noSignal || result.frequency <= 0) return;

      // Update State for Visual Feedback
      state = state.copyWith(
        currentInputFreq: result.frequency,
        currentInputNote: "${result.noteName}${result.octave}",
      );

      // Check Answer
      final isCorrect = _gameEngine.checkAnswer(
        result.frequency, 
        state.currentQuiz!.frequency, 
        state.difficulty
      );

      if (isCorrect) {
        _handleSuccess();
      }
    });
  }

  void _handleSuccess() {
    _pitchSubscription?.cancel(); // Stop listening
    
    final newScore = state.score + 10 + (state.combo * 2);
    final newCombo = state.combo + 1;
    
    state = state.copyWith(
      status: GameStatus.success,
      score: newScore,
      combo: newCombo,
      feedbackMessage: "Correct! That was ${state.currentQuiz!.noteName}",
    );

    // Play Success Sound (Optional, re-using tone generator for now needs distinct sound)
    // For now, just wait and go next
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _nextLevel();
    });
  }
}
