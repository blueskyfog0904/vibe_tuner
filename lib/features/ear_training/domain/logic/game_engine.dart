import 'dart:math';

enum GameDifficulty {
  easy,   // +/- 50 cents
  medium, // +/- 25 cents
  hard    // +/- 10 cents
}

class GameEngine {
  bool checkAnswer(double inputFreq, double targetFreq, GameDifficulty difficulty) {
    if (inputFreq <= 0 || targetFreq <= 0) return false;

    // Calculate Cents Difference
    // Formula: cents = 1200 * log2(f1 / f2)
    final double ratio = inputFreq / targetFreq;
    final double centsDiff = 1200 * (log(ratio) / ln2);
    final double absCents = centsDiff.abs();

    return absCents <= _getTolerance(difficulty);
  }

  double _getTolerance(GameDifficulty difficulty) {
    switch (difficulty) {
      case GameDifficulty.easy:
        return 50.0;
      case GameDifficulty.medium:
        return 25.0;
      case GameDifficulty.hard:
        return 10.0;
    }
  }
}
