// Real-world widths in centimeters for common obstacles.
// These are used in the distance formula:
//   Distance = (knownWidth * focalLength) / pixelWidth
export const KNOWN_WIDTHS_CM = {
  car_bumper: 180,
  person:      50,
  truck:       250,
  bus:         280,
  bicycle:     60,
  custom:      45, // user-defined fallback
};

// Default object to use when no specific class is detected
export const DEFAULT_OBJECT_WIDTH_CM = KNOWN_WIDTHS_CM.custom;

// Default calibration values
export const DEFAULT_CALIBRATION = {
  focalLength:        600,  // px — overwritten after real calibration
  knownObjectWidth:   45,   // cm
  calibrationDist:    100,  // cm — how far the object was during calibration
};

// Detection thresholds
export const DETECTION = {
  // Minimum pixel area for a blob to be considered a real obstacle
  minBlobArea:        100,
  // How different a pixel must be from mean to count as foreground
  brightnessThreshold: 15,
  // Center ROI — fraction of frame to analyze (0.20 → 80% = center 60%)
  roiStart:           0.20,
  roiEnd:             0.80,
};

// Distance zones — in meters
export const ZONES = {
  danger:  1.0,   // < 1m   → red
  warning: 3.0,   // 1–3m   → amber
  safe:    6.0,   // 3–6m   → green
  // beyond 6m → no alert
};

// How many distance samples to average for smoothing
export const SMOOTHING_WINDOW = 10;

// Detection runs every Nth animation frame to save CPU
export const DETECTION_FRAME_SKIP = 3;