import 'package:flutter/material.dart';
import '../services/object_detector.dart';

class BoundingBoxPainter extends CustomPainter {
  final List<Detection> detections;

  BoundingBoxPainter(this.detections);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    for (var det in detections) {
      final rect = Rect.fromLTRB(
        det.xmin * size.width,
        det.ymin * size.height,
        det.xmax * size.width,
        det.ymax * size.height,
      );

      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}