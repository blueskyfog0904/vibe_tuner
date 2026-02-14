import 'package:equatable/equatable.dart';

class QuizItem extends Equatable {
  final String noteName; // e.g., "A4"
  final double frequency; // e.g., 440.0

  const QuizItem({
    required this.noteName,
    required this.frequency,
  });

  @override
  List<Object?> get props => [noteName, frequency];
}

class GameSession extends Equatable {
  final int score;
  final int combo;
  final int lives;

  const GameSession({
    this.score = 0,
    this.combo = 0,
    this.lives = 3,
  });

  GameSession copyWith({
    int? score,
    int? combo,
    int? lives,
  }) {
    return GameSession(
      score: score ?? this.score,
      combo: combo ?? this.combo,
      lives: lives ?? this.lives,
    );
  }

  @override
  List<Object?> get props => [score, combo, lives];
}
