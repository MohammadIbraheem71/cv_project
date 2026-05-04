import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'dart:ui';

class Detection {
  final Rect rect;
  final String label;
  final double confidence;

  Detection({
    required this.rect,
    required this.label,
    required this.confidence,
  });
}

class MLKitDetector {
  late ObjectDetector _detector;

  Future<void> init() async {
    final options = ObjectDetectorOptions(
      mode: DetectionMode.stream,
      classifyObjects: true,
      multipleObjects: true,
    );

    _detector = ObjectDetector(options: options);
  }

  Future<List<Detection>> process(InputImage inputImage) async {
    final results = await _detector.processImage(inputImage);

    return results.map((obj) {
      return Detection(
        rect: obj.boundingBox,
        label: obj.labels.isNotEmpty ? obj.labels.first.text : "object",
        confidence: obj.labels.isNotEmpty ? obj.labels.first.confidence : 0,
      );
    }).toList();
  }

  void dispose() {
    _detector.close();
  }
}