import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/game_controller.dart';
import '../../domain/logic/game_engine.dart';

class GameScreen extends ConsumerWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameControllerProvider);
    final controller = ref.read(gameControllerProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Ear Training"),
        backgroundColor: Colors.transparent,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text(
                "Score: ${gameState.score}",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          )
        ],
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Difficulty Selector
          if (gameState.status == GameStatus.idle)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SegmentedButton<GameDifficulty>(
                segments: const [
                  ButtonSegment(value: GameDifficulty.easy, label: Text("Easy")),
                  ButtonSegment(value: GameDifficulty.hard, label: Text("Hard")),
                ],
                selected: {gameState.difficulty},
                onSelectionChanged: (Set<GameDifficulty> newSelection) {
                  controller.setDifficulty(newSelection.first);
                },
              ),
            ),

          const Spacer(),

          // Central Visual Cue
          _buildVisualCue(gameState),

          const SizedBox(height: 32),
          
          // Feedback Message
          Text(
            gameState.feedbackMessage ?? "Press Start to Play",
            style: const TextStyle(fontSize: 24, color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 10),
          // Debug / Real-time Feedback
          if (gameState.status == GameStatus.listening)
             Column(
               children: [
                 Text(
                   "Input: ${gameState.currentInputFreq?.toStringAsFixed(1) ?? '...'} Hz (${gameState.currentInputNote ?? '?'})",
                   style: const TextStyle(fontSize: 16, color: Colors.grey),
                 ),
                 const SizedBox(height: 20),
                 ElevatedButton.icon(
                   onPressed: () {
                     controller.replayTone();
                   }, 
                   icon: const Icon(Icons.replay),
                   label: const Text("Replay Tone"),
                 ),
               ],
             ),
          
          if (gameState.combo > 1)
            Text(
              "${gameState.combo} Combo!",
              style: const TextStyle(fontSize: 20, color: Colors.amber, fontWeight: FontWeight.bold),
            ),

          const Spacer(),

          // Control Button
          if (gameState.status == GameStatus.idle || gameState.status == GameStatus.fail)
            Padding(
              padding: const EdgeInsets.only(bottom: 48.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                  backgroundColor: Colors.deepPurple,
                ),
                onPressed: () {
                  controller.startGame();
                },
                child: const Text("START GAME", style: TextStyle(fontSize: 20)),
              ),
            ),
             
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildVisualCue(GameState state) {
    Color iconColor = Colors.grey;
    IconData iconData = Icons.hearing;
    double scale = 1.0;

    switch (state.status) {
      case GameStatus.playingTone:
        iconColor = Colors.blueAccent;
        iconData = Icons.volume_up;
        scale = 1.2;
        break;
      case GameStatus.listening:
        iconColor = Colors.orangeAccent;
        iconData = Icons.mic;
        scale = 1.1; // Pulse logic would be better with AnimationController
        break;
      case GameStatus.success:
        iconColor = Colors.greenAccent;
        iconData = Icons.check_circle;
        scale = 1.5;
        break;
      case GameStatus.fail:
        iconColor = Colors.redAccent;
        iconData = Icons.cancel;
        break;
      case GameStatus.idle:
        break;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      alignment: Alignment.center,
      child: Transform.scale(
        scale: scale,
        child: Icon(
          iconData,
          size: 120,
          color: iconColor,
        ),
      ),
    );
  }
}
