import 'dart:convert';
import 'package:flutter/services.dart';
import '../../domain/entities/chord_entity.dart';
import '../models/chord_model.dart';

abstract class ChordRepository {
  Future<void> initialize();
  List<ChordEntity> getChords({
    required InstrumentType instrument,
    String? root,
    String? quality,
  });
}

class ChordRepositoryImpl implements ChordRepository {
  List<ChordModel> _chords = [];
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    final String response = await rootBundle.loadString('assets/data/chord_db.json');
    final data = json.decode(response);
    _chords = (data['chords'] as List).map((e) => ChordModel.fromJson(e)).toList();
    _initialized = true;
  }

  @override
  List<ChordEntity> getChords({
    required InstrumentType instrument,
    String? root,
    String? quality,
  }) {
    return _chords.where((chord) {
      bool match = chord.instrument == instrument;
      if (root != null) match = match && chord.root == root;
      if (quality != null) match = match && chord.quality == quality;
      return match;
    }).toList();
  }
}
