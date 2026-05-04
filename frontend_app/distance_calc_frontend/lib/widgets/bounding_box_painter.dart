import 'package:flutter/material.dart';
import 'dart:ui';

import '../services/mlkit_detector.dart';

class BoundingBoxPainter extends CustomPainter {
  final List<Detection> detections;

  BoundingBoxPainter(this.detections);

  @override
  void paint(Canvas canvas, Size size) {
    final paintBox = Paint()
      ..color = const Color(0xFF00FF00)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final paintTextBg = Paint()
      ..color = const Color(0xFF00FF00);

    final textStyle = const TextStyle(
      color: Colors.black,
      fontSize: 12,
      fontWeight: FontWeight.bold,
    );

    for (final d in detections) {
      final rect = d.rect;

      // Draw bounding box
      final box = Rect.fromLTRB(
        rect.left,
        rect.top,
        rect.right,
        rect.bottom,
      );

      canvas.drawRect(box, paintBox);

      // Label background
      final label = "${d.label} ${(d.confidence * 100).toStringAsFixed(0)}%";

      final textSpan = TextSpan(text: label, style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();

      final offset = Offset(rect.left, rect.top - 18);

      final backgroundRect = Rect.fromLTWH(
        offset.dx,
        offset.dy,
        textPainter.width + 6,
        textPainter.height + 4,
      );

      canvas.drawRect(backgroundRect, paintTextBg);

      textPainter.paint(
        canvas,
        Offset(offset.dx + 3, offset.dy + 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant BoundingBoxPainter oldDelegate) {
    return true; // always update for live video
  }
}