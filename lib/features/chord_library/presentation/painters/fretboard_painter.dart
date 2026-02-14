import 'package:flutter/material.dart';
import '../../domain/entities/chord_entity.dart';

class FretboardPainter extends CustomPainter {
  final ChordEntity chord;
  final bool isUkulele;

  FretboardPainter({
    required this.chord,
  }) : isUkulele = chord.instrument == InstrumentType.ukulele;

  @override
  void paint(Canvas canvas, Size size) {
    final int stringCount = isUkulele ? 4 : 6;
    final int fretCount = 5; // Standard chord box shows 5 frets

    // Layout Constants (Relative)
    final double topPadding = size.height * 0.15; // Space for X/O markers
    final double fretboardHeight = size.height - topPadding;
    final double stringGap = size.width / (stringCount - 1);
    final double fretGap = fretboardHeight / fretCount;

    // Paints
    final Paint stringPaint = Paint()
      ..color = Colors.grey
      ..strokeWidth = 1.0;

    final Paint fretPaint = Paint()
      ..color = Colors.grey
      ..strokeWidth = 1.0;

    final Paint nutPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4.0 // Thicker nut
      ..strokeCap = StrokeCap.square;

    final Paint markerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final Paint barrePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final Paint capoPaint = Paint()
      ..color = Colors.lightBlueAccent
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round;

    // 1. Draw Strings (Vertical Lines)
    for (int i = 0; i < stringCount; i++) {
      double x = i * stringGap;
      canvas.drawLine(
        Offset(x, topPadding),
        Offset(x, size.height),
        stringPaint,
      );
    }

    // 2. Draw Frets (Horizontal Lines)
    for (int i = 0; i <= fretCount; i++) {
      double y = topPadding + (i * fretGap);
      
      // Nut (Fret 0) is thicker
      if (i == 0) {
        canvas.drawLine(
          Offset(0 - (stringPaint.strokeWidth / 2), y), 
          Offset(size.width + (stringPaint.strokeWidth / 2), y), 
          nutPaint
        );
      } else {
        canvas.drawLine(
          Offset(0, y), 
          Offset(size.width, y), 
          fretPaint
        );
      }
    }

    // 3. Draw Capo
    if (chord.capo > 0) {
      final double capoY = topPadding + (fretGap * 0.18);
      canvas.drawLine(Offset(0, capoY), Offset(size.width, capoY), capoPaint);

      final TextPainter capoText = TextPainter(
        text: TextSpan(
          text: "Capo ${chord.capo}",
          style: TextStyle(
            color: Colors.lightBlueAccent,
            fontSize: size.width * 0.09,
            fontWeight: FontWeight.w700,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();
      capoText.paint(
        canvas,
        Offset((size.width - capoText.width) / 2, 2),
      );
    }

    // 4. Draw Barre
    final barreDisplayFret = FretboardRenderUtils.displayFretForCapo(
      fret: chord.barre?.fret ?? -1,
      capo: chord.capo,
    );
    if (chord.barre != null && barreDisplayFret > 0) {
      final normalizedBarre = FretboardRenderUtils.normalizeBarreRange(
        startString: chord.barre!.startString,
        endString: chord.barre!.endString,
        stringCount: stringCount,
      );
      if (normalizedBarre != null) {
        final int leftStringIndex = stringCount - normalizedBarre.startString;
        final int rightStringIndex = stringCount - normalizedBarre.endString;
        final double leftX = leftStringIndex * stringGap;
        final double rightX = rightStringIndex * stringGap;
        final double y = topPadding + (barreDisplayFret * fretGap) - (fretGap / 2);
        final Rect barreRect = Rect.fromLTRB(
          leftX - stringGap * 0.2,
          y - fretGap * 0.22,
          rightX + stringGap * 0.2,
          y + fretGap * 0.22,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(barreRect, Radius.circular(fretGap * 0.2)),
          barrePaint,
        );
      }
    }

    // 5. Draw Positions & Markers
    for (final position in chord.positions) {
      // Calculate string index (0 is Leftmost/Low Pitch)
      // Guitar: String 6 (Low E) is Left -> Index 0
      // Ukulele: String 4 (G) is Left -> Index 0
      // Formula: index = numStrings - position.string
      int stringIndex = stringCount - position.string;
      
      double x = stringIndex * stringGap;

      final int displayFret = FretboardRenderUtils.displayFretForCapo(
        fret: position.fret,
        capo: chord.capo,
      );

      // Handle Mute/Open (Above Nut)
      if (displayFret <= 0) {
        double y = topPadding * 0.5; // Center in padding area
        
        // Mute (X) or Open (O)
        String label = displayFret == -1 ? "X" : "O";
        
        // If finger is > 0 even on fret 0 (unlikely for standard chords but possible data), 
        // we normally don't show finger number for open strings.
        
        // Draw Label
        TextSpan span = TextSpan(
          text: label,
          style: TextStyle(
            color: displayFret == -1 ? Colors.redAccent : Colors.white,
            fontSize: size.width * 0.1, // Responsive font size
            fontWeight: FontWeight.bold,
          ),
        );
        TextPainter tp = TextPainter(
          text: span,
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        );
        tp.layout();
        tp.paint(canvas, Offset(x - (tp.width / 2), y - (tp.height / 2)));
      } else {
        // Draw Finger Position (Circle on Fret)
        // Y is user-friendly fret center
        double y = topPadding + (displayFret * fretGap) - (fretGap / 2);
        
        // Circle Radius based on string gap
        double radius = stringGap * 0.35;
        if (radius > fretGap * 0.35) radius = fretGap * 0.35; // Clamp

        canvas.drawCircle(Offset(x, y), radius, markerPaint);

        // Draw Finger Number
        if (position.finger > 0) {
          TextSpan span = TextSpan(
            text: position.finger.toString(),
            style: TextStyle(
              color: Colors.black, // Contrast text color
              fontSize: radius * 1.2,
              fontWeight: FontWeight.bold,
            ),
          );
          TextPainter tp = TextPainter(
            text: span,
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
          );
          tp.layout();
          tp.paint(canvas, Offset(x - (tp.width / 2), y - (tp.height / 2)));
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant FretboardPainter oldDelegate) {
    return oldDelegate.chord != chord;
  }
}

class NormalizedBarreRange {
  final int startString;
  final int endString;

  const NormalizedBarreRange({
    required this.startString,
    required this.endString,
  });
}

class FretboardRenderUtils {
  static int displayFretForCapo({required int fret, required int capo}) {
    if (fret < 0) return -1;
    if (fret == 0) return 0;
    if (capo <= 0) return fret;
    final relative = fret - capo;
    if (relative <= 0) return 0;
    return relative;
  }

  static NormalizedBarreRange? normalizeBarreRange({
    required int startString,
    required int endString,
    required int stringCount,
  }) {
    if (stringCount <= 0) return null;
    final min = startString < endString ? startString : endString;
    final max = startString > endString ? startString : endString;
    if (min < 1 || max > stringCount) return null;
    return NormalizedBarreRange(startString: max, endString: min);
  }
}
