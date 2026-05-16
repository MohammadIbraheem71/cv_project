import 'dart:math' as math;
import 'dart:ui';

import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';


/// A model class that represents a single detected object behind the car.
class RearObstacleDetection {
  final Rect boundingBox;
  final String label;
  final double confidence;
  final double estimatedDistanceMeters;
  final double hazardScore; // 0.0 to 1.0
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

/// The service responsible for object detection and distance calculation.
class MLKitDetector {
  ObjectDetector? _detector;
  bool _isReady = false;
  
  // Default focal length (can be updated via calibration)
  // This varies by phone model.
  double _focalLengthPx = 550.0;

  /// Sets up the ML Kit Object Detector with streaming options.
  Future<void> init() async {
    if (_isReady) return;

    final options = ObjectDetectorOptions(
      mode: DetectionMode.stream,
      classifyObjects: true,
      multipleObjects: true,
    );

    _detector = ObjectDetector(options: options);
    _isReady = true;
  }

  /// Processes a camera frame and returns a list of detected objects with distances.
  Future<List<RearObstacleDetection>> process(
    InputImage inputImage,
    Size frameSize,
  ) async {
    if (!_isReady || _detector == null) return const [];

    final results = await _detector!.processImage(inputImage);
    
    final detections = results
        .map((object) => _convertObject(object, frameSize))
        // Filter out low-confidence detections
        .where((detection) => detection.confidence >= 0.35)
        .toList()
      // Sort by distance so the closest object is always first in the list
      ..sort(
        (left, right) => left.estimatedDistanceMeters.compareTo(
          right.estimatedDistanceMeters,
        ),
      );

    return detections;
  }

  /// Updates the camera's focal length after calibration.
  void setFocalLength(double focalLengthPx) {
    if (focalLengthPx.isFinite && focalLengthPx > 0) {
      _focalLengthPx = focalLengthPx;
    }
  }

  /// Helper to convert a raw ML Kit DetectedObject into our custom model.
  RearObstacleDetection _convertObject(DetectedObject object, Size frameSize) {
    final label = object.labels.isNotEmpty ? object.labels.first.text : 'object';
    final confidence = object.labels.isNotEmpty
        ? object.labels.first.confidence
        : (object.trackingId != null ? 0.5 : 0.0);

    // Calculate distance and hazard risk
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
      // Object is a hazard if it's high-score or dangerously close (< 4m)
      isHazard: hazardScore >= 0.55 || distance <= 4.0,
    );
  }

  /// Estimates distance in meters using the Pinhole Camera Model formula:
  /// Distance = (Focal Length * Real World Width) / Object Width in Pixels
  double _estimateDistanceMeters({
    required Rect box,
    required Size frameSize,
    required String label,
  }) {
    final boxWidth = math.max(box.width, 1.0);
    final referenceWidth = _referenceWidthMeters(label);

    final rawDistance = (_focalLengthPx * referenceWidth) / boxWidth;

    // Clamp to reasonable ranges to avoid glitches
    return rawDistance.clamp(1.0, 30.0);
  }

  /// Calculates a hazard probability score based on multiple factors.
  double _hazardScore({
    required Rect box,
    required Size frameSize,
    required double distanceMeters,
    required double confidence,
  }) {
    final centerX = box.center.dx / frameSize.width;
    final centerY = box.center.dy / frameSize.height;

    // Is the object in the middle of our lane?
    final centered = 1.0 - ((centerX - 0.5).abs() / 0.45).clamp(0.0, 1.0);
    
    // Is it low in the frame (closer to the ground/wheels)?
    final lowInFrame = ((centerY - 0.35) / 0.5).clamp(0.0, 1.0);
    
    // How much of the screen does it take up?
    final sizeFactor = (box.height / frameSize.height).clamp(0.0, 1.0);
    
    // Simple proximity factor
    final proximityFactor = 1.0 - (distanceMeters / 8.0).clamp(0.0, 1.0);

    // Weighted average of all risk factors
    return (proximityFactor * 0.5) +
        (centered * 0.2) +
        (lowInFrame * 0.15) +
        (sizeFactor * 0.1) +
        (confidence * 0.05);
  }

  /// Returns the estimated real-world width of an object in meters based on its AI label.
  double _referenceWidthMeters(String label) {
    final normalized = label.toLowerCase();

    if (normalized.contains('person') ||
        normalized.contains('pedestrian') ||
        normalized.contains('human') ||
        normalized.contains('fashion')) {
      return 0.5; // Average shoulder width
    }

    if (normalized.contains('car') ||
        normalized.contains('truck') ||
        normalized.contains('bus') ||
        normalized.contains('vehicle')) {
      return 1.8; // Average car width
    }

    if (normalized.contains('bicycle') ||
        normalized.contains('bike') ||
        normalized.contains('motorcycle')) {
      return 0.6; // Handlebar width
    }

    if (normalized.contains('food')) return 0.3;
    if (normalized.contains('home')) return 0.6;
    if (normalized.contains('plant')) return 0.4;
    if (normalized.contains('place')) return 1.5;

    // Generic fallback for unknown objects
    return 1.8;
  }

  /// Closes the ML Kit engine to free up memory.
  void dispose() {
    _detector?.close();
    _detector = null;
    _isReady = false;
  }
}
