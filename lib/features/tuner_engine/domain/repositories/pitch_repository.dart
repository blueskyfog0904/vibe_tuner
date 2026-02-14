import '../entities/tuning_result.dart';
import '../entities/tuner_processing_config.dart';

abstract class PitchRepository {
  Stream<TuningResult> get pitchStream;
  Future<void> initialize();
  void updateProcessingConfig(TunerProcessingConfig config);
  void addAudioData(List<double> buffer);
  void dispose();
}
