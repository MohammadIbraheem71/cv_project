import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

import '../services/mlkit_detector.dart';
import 'bounding_box_painter.dart';

class CameraPreviewWidget extends StatelessWidget {
  final CameraController controller;
  final List<RearObstacleDetection> detections;
  final Size frameSize;
  final bool mirror;

  const CameraPreviewWidget({
    super.key,
    required this.controller,
    required this.detections,
    required this.frameSize,
    this.mirror = false,
  });

  @override
  Widget build(BuildContext context) {
    debugPrint('[CameraPreviewWidget] Building camera preview');

    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CameraPreview(controller),
                  IgnorePointer(
                    child: CustomPaint(
                      painter: BoundingBoxPainter(
                        detections,
                        frameSize,
                        mirror: mirror,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 18,
                    right: 18,
                    bottom: 18,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.22),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Text(
                          'Rear warning zone is highlighted in red. Move forward if the nearest object enters the danger zone.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}