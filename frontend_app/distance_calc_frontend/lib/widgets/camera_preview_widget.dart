import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

import '../services/mlkit_detector.dart';
import 'bounding_box_painter.dart';

/// A widget that displays the camera feed with a detection overlay and UI instructions.
class CameraPreviewWidget extends StatelessWidget {
  final CameraController controller;
  final List<RearObstacleDetection> detections;
  final Size frameSize;
  final bool mirror;
  final bool isCalibrationMode;
  final VoidCallback? onCalibrate;
  final VoidCallback? onCancelCalibration;

  const CameraPreviewWidget({
    super.key,
    required this.controller,
    required this.detections,
    required this.frameSize,
    this.mirror = false,
    this.isCalibrationMode = false,
    this.onCalibrate,
    this.onCancelCalibration,
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
              // Standard vertical aspect ratio for the preview
              aspectRatio: 3 / 4,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Layer 1: The live camera feed
                  CameraPreview(controller),
                  
                  // Layer 2: The detection boxes (Custom Paint)
                  IgnorePointer(
                    child: CustomPaint(
                      painter: BoundingBoxPainter(
                        detections,
                        frameSize,
                        mirror: mirror,
                      ),
                    ),
                  ),
                  
                  // Layer 3: Instruction panel at the bottom
                  Positioned(
                    left: 18,
                    right: 18,
                    bottom: 18,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.22),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Dynamic instruction text based on the current mode
                            Text(
                              isCalibrationMode
                                  ? 'Calibration mode is active. Place the object in view, then capture it.'
                                  : 'Rear warning zone is highlighted in red. Move forward if the nearest object enters the danger zone.',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                height: 1.3,
                              ),
                            ),
                            
                            // Calibration buttons (only shown in Calibration Mode)
                            if (isCalibrationMode) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: FilledButton.icon(
                                      onPressed: onCalibrate,
                                      icon: const Icon(Icons.center_focus_strong),
                                      label: const Text('Calibrate'),
                                    ),
                                  ),
                                  if (onCancelCalibration != null) ...[
                                    const SizedBox(width: 8),
                                    TextButton(
                                      onPressed: onCancelCalibration,
                                      child: const Text('Cancel'),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ],
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