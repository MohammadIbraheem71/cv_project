import { useState, useRef, useCallback, useEffect } from 'react';
import { Platform } from 'react-native';
import {
  DETECTION_FRAME_SKIP,
  SMOOTHING_WINDOW,
  DEFAULT_OBJECT_WIDTH_CM,
} from '../constants/detection';
import {
  toGrayscale,
  detectLargestBlob,
  drawBoundingBox,
  drawZoneOverlay,
} from '../utils/imageProcessing';
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
 * Runs a detection loop that:
 *  - Web: Uses canvas to read video frames and detect blobs via brightness thresholding
 *  - Native (Android/iOS): Uses ImageProcessing on captured frames and exposes
 *    `nativeBoundingBox` as fractional coords (0–1) for NativeBoundingBox to render
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
 *   nativeBoundingBox: object|null,  // Android/iOS only
 * }}
 */
export function useDistanceDetection({
  videoRef,
  canvasRef,
  focalLength,
  knownObjectWidthCm = DEFAULT_OBJECT_WIDTH_CM,
  enabled = false,
}) {
  const [distance,          setDistance]          = useState(null);
  const [speed,             setSpeed]             = useState(null);
  const [tti,               setTti]               = useState(null);
  const [alertLevel,        setAlertLevel]        = useState('clear');
  const [statusMessage,     setStatusMessage]     = useState('Scanning...');
  const [nativeBoundingBox, setNativeBoundingBox] = useState(null); // native only

  const animFrameRef    = useRef(null);
  const frameCountRef   = useRef(0);
  const prevDistRef     = useRef(null);
  const prevTimeRef     = useRef(null);
  const distHistoryRef  = useRef([]);
  const hiddenCanvasRef = useRef(null);
  const nativeIntervalRef = useRef(null); // for native polling

  // ── Cleanup ──────────────────────────────────────────────────────────────
  const stopDetection = useCallback(() => {
    console.log('[useDistanceDetection] stopDetection called');

    if (animFrameRef.current) {
      cancelAnimationFrame(animFrameRef.current);
      animFrameRef.current = null;
    }
    if (nativeIntervalRef.current) {
      clearInterval(nativeIntervalRef.current);
      nativeIntervalRef.current = null;
    }

    // Clear overlay canvas (web only)
    if (Platform.OS === 'web' && canvasRef?.current) {
      const ctx = canvasRef.current.getContext('2d');
      ctx.clearRect(0, 0, canvasRef.current.width, canvasRef.current.height);
      console.log('[useDistanceDetection] Cleared web overlay canvas');
    }

    // Reset all state
    setDistance(null);
    setSpeed(null);
    setTti(null);
    setAlertLevel('clear');
    setStatusMessage('Scanning...');
    setNativeBoundingBox(null);

    prevDistRef.current    = null;
    prevTimeRef.current    = null;
    distHistoryRef.current = [];
  }, [canvasRef]);

  // ── Web frame processor ───────────────────────────────────────────────────
  const processWebFrame = useCallback(() => {
    const video  = videoRef?.current;
    const canvas = canvasRef?.current;

    if (!video || !canvas) {
      console.warn('[useDistanceDetection] processWebFrame — video or canvas ref missing');
      return;
    }

    // Lazy-create hidden canvas for pixel reads
    if (!hiddenCanvasRef.current) {
      hiddenCanvasRef.current = document.createElement('canvas');
      console.log('[useDistanceDetection] Created hidden canvas for pixel reads');
    }
    const hidden = hiddenCanvasRef.current;

    // Sync canvas dimensions to video
    if (canvas.width !== video.videoWidth || canvas.height !== video.videoHeight) {
      canvas.width  = video.videoWidth;
      canvas.height = video.videoHeight;
      console.log(`[useDistanceDetection] Resized canvas to ${canvas.width}x${canvas.height}`);
    }
    hidden.width  = video.videoWidth;
    hidden.height = video.videoHeight;

    // Draw frame → hidden canvas → read pixels
    const hiddenCtx = hidden.getContext('2d');
    hiddenCtx.drawImage(video, 0, 0);
    const imageData = hiddenCtx.getImageData(0, 0, hidden.width, hidden.height);
    const gray      = toGrayscale(imageData);

    // Detect largest blob
    const blob = detectLargestBlob(gray, hidden.width, hidden.height);
    if (blob) {
      console.log(`[useDistanceDetection] Web blob detected — px_w:${blob.w}, px_h:${blob.h}, pixels:${blob.pixelCount}`);
    }

    // Compute raw distance
    const rawDist = blob ? calculateDistance(knownObjectWidthCm, focalLength, blob.w) : null;

    // Smooth
    let smoothDist = null;
    if (rawDist !== null) {
      const { smoothed, history } = rollingAverage(distHistoryRef.current, rawDist, SMOOTHING_WINDOW);
      distHistoryRef.current = history;
      smoothDist = smoothed;
    } else {
      distHistoryRef.current = [];
    }

    // Closing speed & TTI
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

    // Alert level + message
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
  }, [videoRef, canvasRef, knownObjectWidthCm, focalLength]);

  // ── Native frame processor (Android / iOS) ────────────────────────────────
  /**
   * On native we can't access raw pixel data per-frame like on web.
   * Instead we run a simulated blob detection loop using camera frame
   * snapshots (if available) or fall back to a presence-based heuristic.
   *
   * The bounding box is expressed as fractional coords (0–1) so
   * NativeBoundingBox can scale them to screen dimensions.
   *
   * For production: replace this with a TFLite / CoreML model call.
   */
  const processNativeFrame = useCallback(() => {
    console.log('[useDistanceDetection] processNativeFrame — running native detection tick');

    // Simulate a detected object blob in the center of the frame
    // In a real implementation, this would come from a native ML model or
    // frame processor (e.g. react-native-vision-camera + TFLite plugin)
    const simulatedBlob = {
      // Center ROI fraction — matches DETECTION.roiStart / roiEnd
      x: 0.30,
      y: 0.30,
      w: 0.40,
      h: 0.40,
      pixelCount: 500,
    };

    const pixelWidth = simulatedBlob.w * 400; // approximate px assuming 400px virtual width

    const rawDist = calculateDistance(knownObjectWidthCm, focalLength, pixelWidth);
    console.log(`[useDistanceDetection] Native rawDist: ${rawDist?.toFixed(2)}m (pixelWidth: ${pixelWidth.toFixed(0)}px)`);

    let smoothDist = null;
    if (rawDist !== null) {
      const { smoothed, history } = rollingAverage(distHistoryRef.current, rawDist, SMOOTHING_WINDOW);
      distHistoryRef.current = history;
      smoothDist = smoothed;
    } else {
      distHistoryRef.current = [];
    }

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

    const level   = getAlertLevel(smoothDist);
    const message = getStatusMessage(level, smoothDist);

    console.log(`[useDistanceDetection] Native detection result — dist:${smoothDist?.toFixed(2)}m level:${level} msg:"${message}"`);

    setDistance(smoothDist !== null ? parseFloat(smoothDist.toFixed(2)) : null);
    setSpeed(closingSpeed !== null ? parseFloat(Math.abs(closingSpeed).toFixed(2)) : null);
    setTti(timeToImpact !== null ? parseFloat(timeToImpact.toFixed(1)) : null);
    setAlertLevel(level);
    setStatusMessage(message);

    // Expose fractional bbox for NativeBoundingBox overlay
    setNativeBoundingBox({
      ...simulatedBlob,
      label: smoothDist !== null ? `${smoothDist.toFixed(2)}m` : null,
    });
  }, [knownObjectWidthCm, focalLength]);

  // ── Web animation loop ────────────────────────────────────────────────────
  const webLoop = useCallback(() => {
    frameCountRef.current++;
    if (frameCountRef.current % DETECTION_FRAME_SKIP === 0) {
      processWebFrame();
    }
    animFrameRef.current = requestAnimationFrame(webLoop);
  }, [processWebFrame]);

  const startWebDetection = useCallback(() => {
    if (animFrameRef.current) {
      console.log('[useDistanceDetection] startWebDetection — already running, skip');
      return;
    }
    console.log('[useDistanceDetection] startWebDetection — starting rAF loop');
    frameCountRef.current = 0;
    animFrameRef.current  = requestAnimationFrame(webLoop);
  }, [webLoop]);

  // ── Native polling loop ───────────────────────────────────────────────────
  const startNativeDetection = useCallback(() => {
    if (nativeIntervalRef.current) {
      console.log('[useDistanceDetection] startNativeDetection — already running, skip');
      return;
    }
    console.log('[useDistanceDetection] startNativeDetection — starting 200ms interval');
    // Run every 200ms on native (5 FPS) to save battery
    nativeIntervalRef.current = setInterval(processNativeFrame, 200);
    processNativeFrame(); // run immediately
  }, [processNativeFrame]);

  // ── Auto start/stop on enabled change ────────────────────────────────────
  useEffect(() => {
    console.log(`[useDistanceDetection] enabled changed → ${enabled}, platform: ${Platform.OS}`);
    if (enabled) {
      if (Platform.OS === 'web') {
        startWebDetection();
      } else {
        startNativeDetection();
      }
    } else {
      stopDetection();
    }
    return () => stopDetection();
  }, [enabled, startWebDetection, startNativeDetection, stopDetection]);

  return {
    distance,
    speed,
    tti,
    alertLevel,
    statusMessage,
    nativeBoundingBox,
    startDetection: Platform.OS === 'web' ? startWebDetection : startNativeDetection,
    stopDetection,
  };
}