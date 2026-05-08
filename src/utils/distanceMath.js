// this file contains the disance calculation logics
//focal length calibration here etc

import { ZONES } from '../constants/detection';

/**
 * Core pinhole camera distance formula.
 * @param {number} knownWidthCm  - Real-world width of the object in cm
 * @param {number} focalLengthPx - Calibrated focal length in pixels
 * @param {number} pixelWidth    - Detected object width in pixels
 * @returns {number|null} Distance in meters, or null if inputs are invalid
 */
export function calculateDistance(knownWidthCm, focalLengthPx, pixelWidth) {
  if (!focalLengthPx || !pixelWidth || pixelWidth <= 0) return null;
  const distanceCm = (knownWidthCm * focalLengthPx) / pixelWidth;
  return distanceCm / 100; // convert cm → meters
}

/**
 * Calculates the focal length from a calibration snapshot.
 * @param {number} pixelWidth        - Object width in pixels at calibration
 * @param {number} realDistanceCm    - Known distance to object in cm
 * @param {number} realObjectWidthCm - Known width of object in cm
 * @returns {number} Focal length in pixels
 */
export function calculateFocalLength(pixelWidth, realDistanceCm, realObjectWidthCm) {
  return (pixelWidth * realDistanceCm) / realObjectWidthCm;
}

/**
 * Estimates closing speed between two distance readings.
 * Positive = object approaching. Negative = object receding.
 * @param {number} prevDistM  - Previous distance in meters
 * @param {number} currDistM  - Current distance in meters
 * @param {number} deltaTimeSec - Time elapsed in seconds
 * @returns {number|null} Speed in m/s, or null if delta time too small
 */
export function calculateClosingSpeed(prevDistM, currDistM, deltaTimeSec) {
  if (deltaTimeSec < 0.05) return null; // avoid division by near-zero
  return (prevDistM - currDistM) / deltaTimeSec;
}

/**
 * Estimates time to impact given current distance and closing speed.
 * @param {number} distanceM   - Current distance in meters
 * @param {number} speedMps    - Closing speed in m/s (must be positive)
 * @returns {number|null} Time in seconds, or null if not approaching
 */
export function calculateTimeToImpact(distanceM, speedMps) {
  if (!speedMps || speedMps <= 0) return null;
  return distanceM / speedMps;
}

/**
 * Returns the alert level string based on distance.
 * @param {number} distanceM
 * @returns {'danger'|'warning'|'safe'|'clear'}
 */
export function getAlertLevel(distanceM) {
  if (distanceM === null) return 'clear';
  if (distanceM < ZONES.danger)  return 'danger';
  if (distanceM < ZONES.warning) return 'warning';
  if (distanceM < ZONES.safe)    return 'safe';
  return 'clear';
}

/**
 * Returns a status message string for a given alert level.
 * @param {'danger'|'warning'|'safe'|'clear'} level
 * @param {number|null} distanceM
 * @returns {string}
 */
export function getStatusMessage(level, distanceM) {
  const d = distanceM !== null ? distanceM.toFixed(2) + 'm' : '--';
  switch (level) {
    case 'danger':  return `DANGER — Obstacle at ${d}`;
    case 'warning': return `Caution — Obstacle at ${d}`;
    case 'safe':    return `Clear — Obstacle at ${d}`;
    default:        return 'Scanning...';
  }
}

/**
 * Smooths a value by averaging over a rolling window.
 * @param {number[]} history - Array of past values
 * @param {number}   newVal  - Latest value to add
 * @param {number}   maxLen  - Max window size
 * @returns {{ smoothed: number, history: number[] }}
 */
export function rollingAverage(history, newVal, maxLen) {
  const next = [...history, newVal];
  if (next.length > maxLen) next.shift();
  const smoothed = next.reduce((a, b) => a + b, 0) / next.length;
  return { smoothed, history: next };
}