import 'dart:math' as math;
import 'dart:ui';

import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';


// this file contains all logic regarding the mlkit object detection and distance estimation

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
  double _focalLengthPx = 550.0;

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

  void setFocalLength(double focalLengthPx) {
    if (focalLengthPx.isFinite && focalLengthPx > 0) {
      _focalLengthPx = focalLengthPx;
    }
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

  // this function estimates the distance of the object in real world meters
  // it uses the focal length of the camera and the estimated width of the object
  double _estimateDistanceMeters({
    required Rect box,
    required Size frameSize,
    required String label,
  }) {
    final boxWidth = math.max(box.width, 1.0);  // was box.height
    final referenceWidth = _referenceWidthMeters(label);  // renamed

    final rawDistance = (_focalLengthPx * referenceWidth) / boxWidth;

    return rawDistance.clamp(1.0, 30.0);
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

  // this function returns the estimated real world width of the object based on its label
  // since we cant know the widths of EVERY object , we have to make some assumptions
  // for our use case of a rear obstacle detector for cars, we will focus on common obstacles like pedestrians, cars

  double _referenceWidthMeters(String label) {
    final normalized = label.toLowerCase();

    if (normalized.contains('person') ||
        normalized.contains('pedestrian') ||
        normalized.contains('human')) {
      return 0.5;  // shoulder width ~50cm
    }

    if (normalized.contains('car') ||
        normalized.contains('truck') ||
        normalized.contains('bus') ||
        normalized.contains('vehicle')) {
      return 1.8;  // typical car width ~180cm
    }

    if (normalized.contains('bicycle') ||
        normalized.contains('bike') ||
        normalized.contains('motorcycle')) {
      return 0.6;  // handlebar width ~60cm
    }

    if (normalized.contains('fashion')) {
      return 0.5; // person wearing clothing
    }
    if (normalized.contains('food')) {
      return 0.3;
    }
    if (normalized.contains('home')) {
      return 0.6;
    }
    if (normalized.contains('plant')) {
      return 0.4;
    }
    if (normalized.contains('place')) {
      return 1.5;
    }

    // in this case, we r not sure what this is
    // for our application of making a car rear obstacle detector
    // we will assume that it is a car
    // since it doesnt have a label, it gets the geneeric fall back value
    return 1.8;  // generic fallback
  }

  void dispose() {
    _detector?.close();
    _detector = null;
    _isReady = false;
  }
}
