import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

class CameraPreviewWidget extends StatelessWidget {
  final CameraController controller;

  const CameraPreviewWidget({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    debugPrint('[CameraPreviewWidget] Building camera preview');
    debugPrint('[CameraPreviewWidget] Camera aspect ratio: ${controller.value.aspectRatio}');

    return LayoutBuilder(
      builder: (context, constraints) {
        debugPrint('[CameraPreviewWidget] Available size: ${constraints.maxWidth}x${constraints.maxHeight}');

        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.center,
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: constraints.maxWidth,
                  height: constraints.maxWidth * (1 / controller.value.aspectRatio),
                  child: CameraPreview(controller),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}