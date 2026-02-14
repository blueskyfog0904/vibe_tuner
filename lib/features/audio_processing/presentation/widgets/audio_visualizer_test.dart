import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart'; // Import to use openAppSettings
import '../../../../core/utils/permission_manager.dart';
import '../providers/audio_state_provider.dart';

class AudioVisualizerTest extends ConsumerStatefulWidget {
  const AudioVisualizerTest({super.key});

  @override
  ConsumerState<AudioVisualizerTest> createState() => _AudioVisualizerTestState();
}

class _AudioVisualizerTestState extends ConsumerState<AudioVisualizerTest> with WidgetsBindingObserver {
  bool _isPermissionGranted = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Automatically request permission on launch to show native dialog
    _requestPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermission();
    }
  }

  Future<void> _checkPermission() async {
    final granted = await PermissionManager().isMicrophonePermissionGranted();
    if (mounted) {
      setState(() {
        _isPermissionGranted = granted;
        _isLoading = false;
      });
      if (!granted) {
        // If not granted, try requesting once automatically
        // But only if we haven't permanently denied it? 
        // Let's just update state and let user press button if needed.
        // Or we can try request:
        // _requestPermission(); // Let's avoid loop, user triggers it or initial calls.
      }
    }
  }

  Future<void> _requestPermission() async {
    setState(() => _isLoading = true);
    final result = await PermissionManager().requestMicrophonePermission();
    result.fold(
      (failure) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("권한 오류: ${failure.message}")));
           setState(() => _isLoading = false);
        }
      },
      (granted) {
        if (mounted) {
          setState(() {
            _isPermissionGranted = true;
            _isLoading = false;
          });
        }
      } 
    );
  }

  @override
  Widget build(BuildContext context) {
    // Only watch the provider if permission is granted
    final AsyncValue<List<double>>? streamAsync = _isPermissionGranted 
        ? ref.watch(processedAudioStreamProvider) 
        : null;
        
    final controlIsFocusMode = ref.watch(audioControlProvider.select((s) => s.isFocusMode));
    
    return Scaffold(
      appBar: AppBar(title: const Text("VibeTuner - 클린 이어 테스트")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("포커스 모드 (대역통과 필터)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Switch(
                  value: controlIsFocusMode, 
                  onChanged: (v) {
                    ref.read(audioControlProvider.notifier).toggleFocusMode();
                  }
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: Container(
              color: Colors.black,
              width: double.infinity,
              child: _buildBody(streamAsync),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(AsyncValue<List<double>>? streamAsync) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_isPermissionGranted) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("마이크 권한이 필요합니다.", style: TextStyle(color: Colors.white, fontSize: 18)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _requestPermission,
              child: const Text("권한 요청"),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: openAppSettings,
              child: const Text("설정 열기", style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      );
    }

    // Permission granted, stream should be active
    return streamAsync!.when(
      data: (data) => CustomPaint(
        painter: WaveformPainter(data),
        size: Size.infinite,
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text("오류: $err", style: const TextStyle(color: Colors.red))),
    );
  }
}

class WaveformPainter extends CustomPainter {
  final List<double> data;
  
  WaveformPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final Paint paint = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final Path path = Path();
    final double width = size.width;
    final double height = size.height;
    final double midHeight = height / 2;

    // data contains samples. 
    // If [0.0], we just draw a straight line.
    
    final int step = (data.length / width).ceil().coerceAtLeast(1); 

    path.moveTo(0, midHeight + (data[0] * midHeight * 0.8));

    for (int i = 0; i < data.length; i += step) {
      final double x = (i / data.length) * width;
      final double sample = data[i]; 
      final double y = midHeight + (sample * midHeight * 0.8); 
      
      path.lineTo(x, y);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) {
    return true; 
  }
}

extension CoerceInt on int {
  int coerceAtLeast(int min) => this < min ? min : this;
}
