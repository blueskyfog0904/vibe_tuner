import 'package:flutter/widgets.dart';

import 'chord_library_test_page.dart';

/// Production route entry for the chord library tab.
/// Keeps compatibility while reusing the existing chord UI implementation.
class ChordLibraryPage extends StatelessWidget {
  const ChordLibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ChordLibraryTestPage();
  }
}
