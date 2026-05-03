import { useState, useCallback } from 'react';
import { Alert } from 'react-native';
import { DEFAULT_CALIBRATION } from '../constants/detection';
import { calculateFocalLength } from '../utils/distanceMath';
import { toGrayscale, detectLargestBlob } from '../utils/imageProcessing';

/**
 * useCalibration
 * Manages the calibration workflow:
 *  1. User enters known object width + distance
 *  2. User taps "Capture" while object is in frame
 *  3. Hook detects the object's pixel width from the video frame
 *  4. Computes and stores focal length
 *
 * @returns {{
 *   isCalibrated, focalLength,
 *   knownObjectWidth, setKnownObjectWidth,
 *   calibrationDist, setCalibrationDist,
 *   captureCalibration,
 *   resetCalibration
 * }}
 */
export function useCalibration() {
  const [isCalibrated,      setIsCalibrated]      = useState(false);
  const [focalLength,       setFocalLength]        = useState(DEFAULT_CALIBRATION.focalLength);
  const [knownObjectWidth,  setKnownObjectWidth]   = useState(DEFAULT_CALIBRATION.knownObjectWidth);
  const [calibrationDist,   setCalibrationDist]    = useState(DEFAULT_CALIBRATION.calibrationDist);

  /**
   * Captures a single frame from the provided video element,
   * detects the largest blob in the center ROI,
   * and computes the focal length.
   *
   * @param {HTMLVideoElement} videoEl - The live video element (web only)
   * @param {HTMLCanvasElement} canvasEl - Hidden canvas for pixel reading
   */
  const captureCalibration = useCallback((videoEl, canvasEl) => {
    if (!videoEl || !canvasEl) {
      Alert.alert('Error', 'Camera not ready. Open the camera first.');
      return;
    }

    // Draw current frame onto hidden canvas
    const w = videoEl.videoWidth;
    const h = videoEl.videoHeight;
    canvasEl.width  = w;
    canvasEl.height = h;
    const ctx = canvasEl.getContext('2d');
    ctx.drawImage(videoEl, 0, 0, w, h);

    // Read pixel data and convert to grayscale
    const imageData = ctx.getImageData(0, 0, w, h);
    const gray      = toGrayscale(imageData);

    // Find the largest foreground blob
    const blob = detectLargestBlob(gray, w, h);

    if (!blob || blob.w < 10) {
      Alert.alert(
        'Calibration failed',
        'Could not detect an object. Ensure:\n• Good lighting\n• Object is centered in frame\n• Object contrasts with background'
      );
      return;
    }

    // Compute focal length from detected pixel width
    const fl = calculateFocalLength(blob.w, calibrationDist, knownObjectWidth);
    const flRounded = Math.round(fl);

    setFocalLength(flRounded);
    setIsCalibrated(true);

    Alert.alert(
      'Calibration successful',
      `Focal length: ${flRounded}px\nDetected object width: ${blob.w}px`
    );
  }, [calibrationDist, knownObjectWidth]);

  const resetCalibration = useCallback(() => {
    setIsCalibrated(false);
    setFocalLength(DEFAULT_CALIBRATION.focalLength);
    setKnownObjectWidth(DEFAULT_CALIBRATION.knownObjectWidth);
    setCalibrationDist(DEFAULT_CALIBRATION.calibrationDist);
  }, []);

  return {
    isCalibrated,
    focalLength,
    knownObjectWidth,
    setKnownObjectWidth,
    calibrationDist,
    setCalibrationDist,
    captureCalibration,
    resetCalibration,
  };
}