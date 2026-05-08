const Map<String, double> knownObjectHeightsMeters = {
  'person': 1.70,
  'car': 1.50,
  'chair': 0.90,
  'bottle': 0.25,
  'cup': 0.12,
  'laptop': 0.30,
  'tv': 0.60,
  'tvmonitor': 0.60,
  'television': 0.60,
  'backpack': 0.50,
  'handbag': 0.30,
  'umbrella': 1.00,
  'bus': 3.20,
  'truck': 3.00,
  'motorcycle': 1.20,
  'bicycle': 1.10,
  'dog': 0.70,
  'cat': 0.30,
};

class SizeBasedDistance {
  const SizeBasedDistance();

  double? calculate({
    required String label,
    required double bboxHeightPixels,
    required double focalLengthPixels,
  }) {
    final normalizedLabel = _normalizeLabel(label);
    final knownHeight = _resolveKnownHeight(normalizedLabel);
    if (knownHeight == null || bboxHeightPixels <= 0 || focalLengthPixels <= 0) {
      // Fallback: assume a default object height (meters) when the label
      // is unknown so the UI can display an approximate distance.
      const double assumedHeightMeters = 0.50; // sensible default for small objects
      if (bboxHeightPixels > 0 && focalLengthPixels > 0) {
        return (assumedHeightMeters * focalLengthPixels) / bboxHeightPixels;
      }
      return null;
    }

    return (knownHeight * focalLengthPixels) / bboxHeightPixels;
  }

  String _normalizeLabel(String label) {
    return label.trim().toLowerCase();
  }

  double? _resolveKnownHeight(String normalizedLabel) {
    final exactMatch = knownObjectHeightsMeters[normalizedLabel];
    if (exactMatch != null) {
      return exactMatch;
    }

    for (final entry in knownObjectHeightsMeters.entries) {
      if (normalizedLabel.contains(entry.key)) {
        return entry.value;
      }
    }

    return null;
  }
}

/// Returns a focal length in pixels, falling back to a calibrated default.
double estimateFocalLengthPixels({
  double? cameraIntrinsicFocalLengthPixels,
  double defaultValue = 800.0,
}) {
  if (cameraIntrinsicFocalLengthPixels != null &&
      cameraIntrinsicFocalLengthPixels.isFinite &&
      cameraIntrinsicFocalLengthPixels > 0) {
    return cameraIntrinsicFocalLengthPixels;
  }

  return defaultValue;
}
