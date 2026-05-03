import { useState, useRef, useCallback, useEffect } from 'react';
import { DETECTION_FRAME_SKIP, SMOOTHING_WINDOW, DEFAULT_OBJECT_WIDTH_CM } from '../constants/detection';
import { toGrayscale, detectLargestBlob, drawBoundingBox, drawZoneOverlay } from '../utils/imageProcessing';
import {
  calculateDistance,
  calculateClosingSpeed,
  calculateTimeToImpact,
  getAlertLevel,
  getStatusMessage,
  rollingAverage,
} from '../utils/distanceMath';

/**
 * useDistanceDetection
 * Runs a requestAnimationFrame loop that:
 *  1. Reads the current video frame onto a canvas
 *  2. Detects the largest blob
 *  3. Calculates distance, speed, and TTI
 *  4. Draws bounding box + zone overlay onto the visible canvas
 *  5. Exposes the latest metrics as state
 *
 * @param {{
 *   videoRef: React.RefObject,
 *   canvasRef: React.RefObject,
 *   focalLength: number,
 *   knownObjectWidthCm: number,
 *   enabled: boolean
 * }} options
 *
 * @returns {{
 *   distance: number|null,
 *   speed: number|null,
 *   tti: number|null,
 *   alertLevel: string,
 *   statusMessage: string,
 *   startDetection,
 *   stopDetection,
 * }}
 */
export function useDistanceDetection({
  videoRef,
  canvasRef,
  focalLength,
  knownObjectWidthCm = DEFAULT_OBJECT_WIDTH_CM,
  enabled = false,
}) {
  const [distance,      setDistance]      = useState(null);
  const [speed,         setSpeed]         = useState(null);
  const [tti,           setTti]           = useState(null);
  const [alertLevel,    setAlertLevel]    = useState('clear');
  const [statusMessage, setStatusMessage] = useState('Scanning...');

  const animFrameRef    = useRef(null);
  const frameCountRef   = useRef(0);
  const prevDistRef     = useRef(null);
  const prevTimeRef     = useRef(null);
  const distHistoryRef  = useRef([]);
  const hiddenCanvasRef = useRef(null); // off-screen canvas for pixel reads

  const stopDetection = useCallback(() => {
    if (animFrameRef.current) {
      cancelAnimationFrame(animFrameRef.current);
      animFrameRef.current = null;
    }
    // Clear overlay canvas
    const canvas = canvasRef?.current;
    if (canvas) {
      const ctx = canvas.getContext('2d');
      ctx.clearRect(0, 0, canvas.width, canvas.height);
    }
    // Reset state
    setDistance(null);
    setSpeed(null);
    setTti(null);
    setAlertLevel('clear');
    setStatusMessage('Scanning...');
    prevDistRef.current    = null;
    prevTimeRef.current    = null;
    distHistoryRef.current = [];
  }, [canvasRef]);

  const processFrame = useCallback(() => {
    const video  = videoRef?.current;
    const canvas = canvasRef?.current;
    if (!video || !canvas) return;

    // Lazy-create hidden canvas for pixel reads (avoids flickering)
    if (!hiddenCanvasRef.current) {
      hiddenCanvasRef.current = document.createElement('canvas');
    }
    const hidden = hiddenCanvasRef.current;

    // Sync canvas dimensions to video
    if (canvas.width !== video.videoWidth || canvas.height !== video.videoHeight) {
      canvas.width  = video.videoWidth;
      canvas.height = video.videoHeight;
    }
    hidden.width  = video.videoWidth;
    hidden.height = video.videoHeight;

    // Draw frame to hidden canvas and read pixels
    const hiddenCtx = hidden.getContext('2d');
    hiddenCtx.drawImage(video, 0, 0);
    const imageData = hiddenCtx.getImageData(0, 0, hidden.width, hidden.height);
    const gray      = toGrayscale(imageData);

    // Detect blob
    const blob = detectLargestBlob(gray, hidden.width, hidden.height);

    // Compute distance
    const rawDist = blob
      ? calculateDistance(knownObjectWidthCm, focalLength, blob.w)
      : null;

    // Smooth distance with rolling average
    let smoothDist = null;
    if (rawDist !== null) {
      const { smoothed, history } = rollingAverage(
        distHistoryRef.current,
        rawDist,
        SMOOTHING_WINDOW
      );
      distHistoryRef.current = history;
      smoothDist = smoothed;
    } else {
      distHistoryRef.current = [];
    }

    // Compute speed and TTI
    const now = Date.now();
    let closingSpeed = null;
    let timeToImpact = null;

    if (smoothDist !== null && prevDistRef.current !== null && prevTimeRef.current !== null) {
      const dt = (now - prevTimeRef.current) / 1000;
      closingSpeed = calculateClosingSpeed(prevDistRef.current, smoothDist, dt);
      if (closingSpeed !== null && closingSpeed > 0.05) {
        timeToImpact = calculateTimeToImpact(smoothDist, closingSpeed);
      }
    }

    if (smoothDist !== null) {
      prevDistRef.current = smoothDist;
      prevTimeRef.current = now;
    }

    // Determine alert level
    const level   = getAlertLevel(smoothDist);
    const message = getStatusMessage(level, smoothDist);

    // Update state
    setDistance(smoothDist !== null ? parseFloat(smoothDist.toFixed(2)) : null);
    setSpeed(closingSpeed !== null ? parseFloat(Math.abs(closingSpeed).toFixed(2)) : null);
    setTti(timeToImpact !== null ? parseFloat(timeToImpact.toFixed(1)) : null);
    setAlertLevel(level);
    setStatusMessage(message);

    // Draw overlays onto visible canvas
    const overlayCtx = canvas.getContext('2d');
    overlayCtx.clearRect(0, 0, canvas.width, canvas.height);
    drawZoneOverlay(overlayCtx, canvas.width, canvas.height);
    if (blob && smoothDist !== null) {
      const label = smoothDist.toFixed(2) + 'm';
      drawBoundingBox(overlayCtx, blob, label, level);
    }
  }, [videoRef, canvasRef, focalLength, knownObjectWidthCm]);

  const loop = useCallback(() => {
    frameCountRef.current++;
    if (frameCountRef.current % DETECTION_FRAME_SKIP === 0) {
      processFrame();
    }
    animFrameRef.current = requestAnimationFrame(loop);
  }, [processFrame]);

  const startDetection = useCallback(() => {
    if (animFrameRef.current) return; // already running
    frameCountRef.current = 0;
    animFrameRef.current  = requestAnimationFrame(loop);
  }, [loop]);

  // Auto start/stop when enabled changes
  useEffect(() => {
    if (enabled) {
      startDetection();
    } else {
      stopDetection();
    }
    return () => stopDetection();
  }, [enabled, startDetection, stopDetection]);

  return {
    distance,
    speed,
    tti,
    alertLevel,
    statusMessage,
    startDetection,
    stopDetection,
  };
}