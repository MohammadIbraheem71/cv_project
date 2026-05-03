import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

class CameraPreviewWidget extends StatelessWidget {
  final CameraController controller;

  const CameraPreviewWidget({super.key, required this.controller});

  // @override
  // Widget build(BuildContext context) {
  //   final screenSize = MediaQuery.of(context).size;
  //   final screenW = screenSize.width;
  //   final screenH = screenSize.height;

  //   // Camera gives width/height in landscape terms
  //   // For portrait phones we need to flip the ratio
  //   final previewSize = controller.value.previewSize!;
  //   final cameraW = previewSize.height; // flipped for portrait
  //   final cameraH = previewSize.width;  // flipped for portrait
  //   final cameraRatio = cameraW / cameraH;

  //   debugPrint('[CameraPreviewWidget] Screen: ${screenW}x${screenH}');
  //   debugPrint('[CameraPreviewWidget] Camera preview size: ${previewSize.width}x${previewSize.height}');
  //   debugPrint('[CameraPreviewWidget] Adjusted camera ratio: $cameraRatio');

  //   // Scale camera to fill screen without stretching
  //   double scale;
  //   if (screenW / screenH > cameraRatio) {
  //     // Screen is wider than camera — fit by width
  //     scale = screenW / (cameraRatio * screenH);
  //   } else {
  //     // Screen is taller than camera — fit by height
  //     scale = screenH * cameraRatio / screenW;
  //   }

  //   debugPrint('[CameraPreviewWidget] Scale factor: $scale');

  //   return ClipRect(
  //     child: Transform.scale(
  //       scale: scale,
  //       child: Center(
  //         child: AspectRatio(
  //           aspectRatio: cameraRatio,
  //           child: CameraPreview(controller),
  //         ),
  //       ),
  //     ),
  //   );
  // }

  // 4/3 aspect ratio code here
  @override
  Widget build(BuildContext context) {
    debugPrint('[CameraPreviewWidget] Building camera preview');

    return Center(
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: CameraPreview(controller),
      ),
    );
  }
}