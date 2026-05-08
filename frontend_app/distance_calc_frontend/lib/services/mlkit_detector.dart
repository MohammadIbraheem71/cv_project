import 'dart:math' as math;
import 'dart:ui';

import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';

import '../depth/depth_estimator.dart';
import '../depth/distance_fusion.dart';
import '../depth/known_sizes.dart';

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

  double get sortDistanceMeters {
    return estimatedDistanceMeters > 0 ? estimatedDistanceMeters : double.infinity;
  }
}

class MLKitDetector {
  ObjectDetector? _detector;
  bool _isReady = false;
  double _focalLengthPx = estimateFocalLengthPixels();
  final SizeBasedDistance _sizeBasedDistance = const SizeBasedDistance();
  final DistanceFusion _distanceFusion = const DistanceFusion();

  double get focalLengthPx => _focalLengthPx;

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
    {
    List<List<double>>? depthMap,
    DepthEstimator? depthEstimator,
    bool useDepth = false,
    double midasScale = 1.0,
  }) async {
    if (!_isReady || _detector == null) {
      return const [];
    }

    final results = await _detector!.processImage(inputImage);
    final detections =
        results
            .map(
              (object) => _convertObject(
                object,
                frameSize,
                depthMap: depthMap,
                depthEstimator: depthEstimator,
                useDepth: useDepth,
                midasScale: midasScale,
              ),
            )
            .where((detection) => detection.confidence >= 0.35)
            .toList()
          ..sort(
            (left, right) => left.sortDistanceMeters.compareTo(right.sortDistanceMeters),
          );

    return detections;
  }

  void setFocalLength(double focalLengthPx) {
    if (focalLengthPx.isFinite && focalLengthPx > 0) {
      _focalLengthPx = focalLengthPx;
    }
  }

  RearObstacleDetection _convertObject(
    DetectedObject object,
    Size frameSize, {
    List<List<double>>? depthMap,
    DepthEstimator? depthEstimator,
    bool useDepth = false,
    double midasScale = 1.0,
  }) {
    final label = object.labels.isNotEmpty
        ? object.labels.first.text
        : 'object';
    final confidence = object.labels.isNotEmpty
        ? object.labels.first.confidence
        : object.trackingId != null
        ? 0.5
        : 0.0;

    final sizeBasedDistance = _estimateSizeBasedDistance(
      box: object.boundingBox,
      label: label,
    );

    double? midasDepth;
    if (useDepth && depthMap != null && depthMap.isNotEmpty && depthEstimator != null) {
      final center = object.boundingBox.center;
      midasDepth = depthEstimator.getDepthAtPoint(
        center.dx.round(),
        center.dy.round(),
        depthMap,
      );
    }

    final distance = _distanceFusion.fuse(
      midasDepth: midasDepth,
      sizeBasedDistance: sizeBasedDistance,
      midasScale: midasScale,
    );
    final hazardDistance = distance > 0
        ? distance
        : sizeBasedDistance ?? (midasDepth != null && midasDepth > 0 ? midasScale / midasDepth : 30.0);

    final hazardScore = _hazardScore(
      box: object.boundingBox,
      frameSize: frameSize,
      distanceMeters: hazardDistance,
      confidence: confidence,
    );

    return RearObstacleDetection(
      boundingBox: object.boundingBox,
      label: label,
      confidence: confidence,
      estimatedDistanceMeters: distance,
      hazardScore: hazardScore,
      isHazard: hazardScore >= 0.55 || hazardDistance <= 4.0,
    );
  }

  double? _estimateSizeBasedDistance({
    required Rect box,
    required String label,
  }) {
    final boxHeight = math.max(box.height, 1.0);
    final distance = _sizeBasedDistance.calculate(
      label: label,
      bboxHeightPixels: boxHeight,
      focalLengthPixels: _focalLengthPx,
    );

    if (distance == null || !distance.isFinite || distance <= 0) {
      return null;
    }

    return distance.clamp(0.25, 30.0);
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

  void dispose() {
    _detector?.close();
    _detector = null;
    _isReady = false;
  }
}
