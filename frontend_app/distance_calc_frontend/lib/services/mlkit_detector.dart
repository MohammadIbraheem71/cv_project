import 'dart:math' as math;
import 'dart:ui';

import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';

class RearObstacleDetection {
  final Rect boundingBox;
  final String label;
  final double confidence;
  final double estimatedDistanceMeters;
  final double hazardScore;
  final bool isHazard;

  const RearObstacleDetection({
    required this.boundingBox,
    required this.label,
    required this.confidence,
    required this.estimatedDistanceMeters,
    required this.hazardScore,
    required this.isHazard,
  });
}

class MLKitDetector {
  ObjectDetector? _detector;
  bool _isReady = false;

  Future<void> init() async {
    if (_isReady) {
      return;
    }

    final options = ObjectDetectorOptions(
      mode: DetectionMode.stream,
      classifyObjects: true,
      multipleObjects: true,
    );

    _detector = ObjectDetector(options: options);
    _isReady = true;
  }

  Future<List<RearObstacleDetection>> process(
    InputImage inputImage,
    Size frameSize,
  ) async {
    if (!_isReady || _detector == null) {
      return const [];
    }

    final results = await _detector!.processImage(inputImage);
    final detections =
        results
            .map((object) => _convertObject(object, frameSize))
            .where((detection) => detection.confidence >= 0.35)
            .toList()
          ..sort(
            (left, right) => left.estimatedDistanceMeters.compareTo(
              right.estimatedDistanceMeters,
            ),
          );

    return detections;
  }

  RearObstacleDetection _convertObject(DetectedObject object, Size frameSize) {
    final label = object.labels.isNotEmpty
        ? object.labels.first.text
        : 'object';
    final confidence = object.labels.isNotEmpty
        ? object.labels.first.confidence
        : object.trackingId != null
        ? 0.5
        : 0.0;

    final distance = _estimateDistanceMeters(
      box: object.boundingBox,
      frameSize: frameSize,
      label: label,
    );
    final hazardScore = _hazardScore(
      box: object.boundingBox,
      frameSize: frameSize,
      distanceMeters: distance,
      confidence: confidence,
    );

    return RearObstacleDetection(
      boundingBox: object.boundingBox,
      label: label,
      confidence: confidence,
      estimatedDistanceMeters: distance,
      hazardScore: hazardScore,
      isHazard: hazardScore >= 0.55 || distance <= 4.0,
    );
  }

  double _estimateDistanceMeters({
    required Rect box,
    required Size frameSize,
    required String label,
  }) {
    final boxHeight = math.max(box.height, 1.0);
    final referenceHeight = _referenceHeightMeters(label);

    const focalLengthPx = 760.0;
    final rawDistance = (focalLengthPx * referenceHeight) / boxHeight;
    final bottomBias =
        1.0 +
        ((frameSize.height - box.bottom) / frameSize.height).clamp(0.0, 1.0) *
            0.15;

    return (rawDistance * bottomBias).clamp(0.4, 30.0);
  }

  double _hazardScore({
    required Rect box,
    required Size frameSize,
    required double distanceMeters,
    required double confidence,
  }) {
    final centerX = box.center.dx / frameSize.width;
    final centerY = box.center.dy / frameSize.height;

    final centered = 1.0 - ((centerX - 0.5).abs() / 0.45).clamp(0.0, 1.0);
    final lowInFrame = ((centerY - 0.35) / 0.5).clamp(0.0, 1.0);
    final sizeFactor = (box.height / frameSize.height).clamp(0.0, 1.0);
    final proximityFactor = 1.0 - (distanceMeters / 8.0).clamp(0.0, 1.0);

    return (proximityFactor * 0.5) +
        (centered * 0.2) +
        (lowInFrame * 0.15) +
        (sizeFactor * 0.1) +
        (confidence * 0.05);
  }

  double _referenceHeightMeters(String label) {
    final normalized = label.toLowerCase();

    if (normalized.contains('person') ||
        normalized.contains('pedestrian') ||
        normalized.contains('human')) {
      return 1.7;
    }

    if (normalized.contains('car') ||
        normalized.contains('truck') ||
        normalized.contains('bus') ||
        normalized.contains('vehicle')) {
      return 1.5;
    }

    if (normalized.contains('bicycle') ||
        normalized.contains('bike') ||
        normalized.contains('motorcycle')) {
      return 1.3;
    }

    return 1.45;
  }

  void dispose() {
    _detector?.close();
    _detector = null;
    _isReady = false;
  }
}
