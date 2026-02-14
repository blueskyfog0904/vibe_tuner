import 'package:iirjdart/butterworth.dart';

class BandpassFilter {
  late Butterworth _butterworth;
  final int sampleRate;
  final double lowCutoff;
  final double highCutoff;

  BandpassFilter({
    required this.sampleRate,
    this.lowCutoff = 70.0,
    this.highCutoff = 1100.0,
  }) {
    _butterworth = Butterworth();
    // bandPass(int order, double samplingRate, double centerFrequency, double widthFrequency)
    // iirjdart's bandPass takes center and width.
    // Center = (High + Low) / 2
    // Width = High - Low
    // However, typical Butterworth implementation might vary.
    // Let's check typical iirjdart usage or assume standard parameters.
    // Actually, standard iirjdart usually provides:
    // bandPass(int order, double sampleRate, double centerFreq, double widthFreq)
    
    double centerFreq = (highCutoff + lowCutoff) / 2;
    double widthFreq = highCutoff - lowCutoff;
    
    _butterworth.bandPass(4, sampleRate.toDouble(), centerFreq, widthFreq);
  }

  /// Process a block of audio samples
  /// This modifies the input list or returns a new one.
  List<double> process(List<double> input) {
    // IIR filters are stateful. We process sample by sample.
    List<double> output = List<double>.filled(input.length, 0.0);
    for (int i = 0; i < input.length; i++) {
      output[i] = _butterworth.filter(input[i]);
    }
    return output;
  }
}
