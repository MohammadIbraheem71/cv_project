import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../services/mlkit_detector.dart';

class BoundingBoxPainter extends CustomPainter {
  final List<RearObstacleDetection> detections;
  final Size frameSize;
  final bool mirror;

  BoundingBoxPainter(this.detections, this.frameSize, {this.mirror = false});

  @override
  void paint(Canvas canvas, Size size) {
    if (frameSize.width <= 0 || frameSize.height <= 0) {
      return;
    }

    final warningZone = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.18,
        size.height * 0.34,
        size.width * 0.64,
        size.height * 0.48,
      ),
      const Radius.circular(24),
    );

    final zonePaint = Paint()
      ..color = const Color(0xFFFF3B30).withOpacity(0.08)
      ..style = PaintingStyle.fill;

    final zoneBorderPaint = Paint()
      ..color = const Color(0xFFFF3B30).withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawRRect(warningZone, zonePaint);
    canvas.drawRRect(warningZone, zoneBorderPaint);

    final safePaint = Paint()
      ..color = const Color(0xFF00E676)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final hazardPaint = Paint()
      ..color = const Color(0xFFFF453A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;

    final paintTextBg = Paint();

    final textStyle = const TextStyle(
      color: Colors.black,
      fontSize: 12,
      fontWeight: FontWeight.bold,
    );

    for (final detection in detections) {
      final rect = _mapRect(
        detection.boundingBox,
        canvasSize: size,
      );

      final boxPaint = detection.isHazard ? hazardPaint : safePaint;
      canvas.drawRect(rect, boxPaint);

      final distanceLabel = detection.estimatedDistanceMeters > 0
          ? '${detection.estimatedDistanceMeters.toStringAsFixed(1)} m'
          : '--';
      final label =
          '${detection.label} ${(detection.confidence * 100).toStringAsFixed(0)}%  •  $distanceLabel';

      final textSpan = TextSpan(text: label, style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      final offset = Offset(
        rect.left,
        (rect.top - textPainter.height - 8).clamp(4.0, size.height - 24),
      );

      final backgroundRect = Rect.fromLTWH(
        offset.dx,
        offset.dy,
        textPainter.width + 6,
        textPainter.height + 4,
      );

      paintTextBg.color = detection.isHazard
          ? const Color(0xFFFF453A)
          : const Color(0xFF00E676);

      canvas.drawRect(backgroundRect, paintTextBg);

      textPainter.paint(canvas, Offset(offset.dx + 3, offset.dy + 2));
    }

    final guidePaint = Paint()
      ..color = const Color(0xFFFFFFFF).withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawLine(
      Offset(size.width * 0.5, size.height * 0.18),
      Offset(size.width * 0.5, size.height * 0.92),
      guidePaint,
    );
  }

  Rect _mapRect(
    Rect rect, {
    required Size canvasSize,
  }) {
    final scale = math.min(
      canvasSize.width / frameSize.width,
      canvasSize.height / frameSize.height,
    );
    final offsetX = (canvasSize.width - frameSize.width * scale) / 2;
    final offsetY = (canvasSize.height - frameSize.height * scale) / 2;

    final left = rect.left * scale + offsetX;
    final right = rect.right * scale + offsetX;
    final top = rect.top * scale + offsetY;
    final bottom = rect.bottom * scale + offsetY;

    if (!mirror) {
      return Rect.fromLTRB(left, top, right, bottom);
    }

    return Rect.fromLTRB(
      canvasSize.width - right,
      top,
      canvasSize.width - left,
      bottom,
    );
  }

  @override
  bool shouldRepaint(covariant BoundingBoxPainter oldDelegate) {
    return oldDelegate.detections != detections ||
        oldDelegate.frameSize != frameSize ||
        oldDelegate.mirror != mirror;
  }
}
