class DistanceFusion {
  const DistanceFusion();

  double fuse({
    required double? midasDepth,
    required double? sizeBasedDistance,
    required double midasScale,
  }) {
    final hasMidasDepth = midasDepth != null && midasDepth.isFinite && midasDepth > 0;
    final hasSizeBasedDistance =
        sizeBasedDistance != null && sizeBasedDistance.isFinite && sizeBasedDistance > 0;

    if (hasMidasDepth && hasSizeBasedDistance) {
      return 0.60 * (midasScale / midasDepth) + 0.40 * sizeBasedDistance;
    }

    if (hasMidasDepth) {
      return midasScale / midasDepth;
    }

    if (hasSizeBasedDistance) {
      return sizeBasedDistance;
    }

    return -1.0;
  }

  /// TODO: calibrate midasScale per device and scene using real ground-truth samples.
  double calibrateScale({
    required List<double> knownGroundTruthDistances,
    required List<double> correspondingMidasValues,
  }) {
    final sampleCount = knownGroundTruthDistances.length < correspondingMidasValues.length
        ? knownGroundTruthDistances.length
        : correspondingMidasValues.length;

    if (sampleCount == 0) {
      return 1.0;
    }

    double weightedSum = 0.0;
    int validSamples = 0;

    for (var index = 0; index < sampleCount; index++) {
      final distance = knownGroundTruthDistances[index];
      final midasValue = correspondingMidasValues[index];
      if (distance <= 0 || midasValue <= 0 || !distance.isFinite || !midasValue.isFinite) {
        continue;
      }

      weightedSum += distance * midasValue;
      validSamples++;
    }

    if (validSamples == 0) {
      return 1.0;
    }

    return weightedSum / validSamples;
  }
}
