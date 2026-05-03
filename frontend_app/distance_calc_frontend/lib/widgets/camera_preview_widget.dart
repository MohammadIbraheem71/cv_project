import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

class CameraPreviewWidget extends StatelessWidget {
  final CameraController controller;

  const CameraPreviewWidget({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    // Camera aspect ratio (e.g. 16:9)
    final cameraAspectRatio = controller.value.aspectRatio;

    // Screen aspect ratio
    final screenAspectRatio = size.width / size.height;

    // Scale factor to make it fill screen (crop if needed)
    final scale = cameraAspectRatio / screenAspectRatio;

    return Transform.scale(
      scale: scale < 1 ? 1 / scale : scale,
      child: Center(
        child: AspectRatio(
          aspectRatio: cameraAspectRatio,
          child: CameraPreview(controller),
        ),
      ),
    );
  }
}