/**
 * modelDetection.js
 * Wraps COCO-SSD inference for use in the distance detection pipeline.
 *
 * Depends on two globals injected by web/index.html:
 *   window.tf       — TensorFlow.js core
 *   window.cocoSsd  — COCO-SSD model package
 *
 * These are loaded via CDN script tags before the app bundle.
 */

// ---------------------------------------------------------------------------
// Known real-world widths in centimetres per detectable class.
// Used in: Distance = (realWidthCm * focalLength) / bboxPixelWidth
// ---------------------------------------------------------------------------
export const KNOWN_WIDTHS_CM = {
  // Everyday objects — good for calibration
  person:     50,
  bottle:     8,
  cup:        10,
  book:       22,
  laptop:     35,
  backpack:   40,
  chair:      50,
  cell_phone: 7,
  // Obstacle classes
  car:        180,
  truck:      250,
  bus:        280,
  motorcycle: 100,
  bicycle:    60,
};

// Classes the app actively cares about — everything else is filtered out
const ALLOWED_CLASSES = new Set(Object.keys(KNOWN_WIDTHS_CM).map(k => k.replace('_', ' ')));

// Minimum confidence score (0–1) to accept a detection
export const MIN_CONFIDENCE = 0.55;

// Singleton model instance — loaded once, reused every frame
let modelInstance = null;
let loadPromise   = null;

// ---------------------------------------------------------------------------
// loadModel
// ---------------------------------------------------------------------------
/**
 * Loads the COCO-SSD model from CDN and caches it as a singleton.
 * Safe to call multiple times — returns the cached instance after first load.
 *
 * Uses 'lite_mobilenet_v2' base for best speed on mobile browsers.
 *
 * @returns {Promise<object|null>} Loaded model, or null on failure
 */
export async function loadModel() {
  // Return cached instance immediately
  if (modelInstance) return modelInstance;

  // If already loading, wait for the same promise
  if (loadPromise) return loadPromise;

  // Check that CDN globals are available
  if (typeof window === 'undefined' || !window.tf || !window.cocoSsd) {
    console.error(
      'modelDetection: window.tf or window.cocoSsd not found.\n' +
      'Ensure the CDN script tags are in web/index.html before the app bundle.'
    );
    return null;
  }

  loadPromise = (async () => {
    try {
      await window.tf.ready();
      const model = await window.cocoSsd.load({ base: 'lite_mobilenet_v2' });
      modelInstance = model;
      console.log('COCO-SSD model ready');
      return model;
    } catch (err) {
      console.error('COCO-SSD load error:', err);
      loadPromise = null; // allow retry
      return null;
    }
  })();

  return loadPromise;
}

// ---------------------------------------------------------------------------
// detectObjects
// ---------------------------------------------------------------------------
/**
 * Runs COCO-SSD inference on a live video element.
 * Returns only detections whose class is in ALLOWED_CLASSES
 * and whose confidence meets MIN_CONFIDENCE.
 *
 * Each returned detection is enriched with `realWidthCm` so the
 * distance formula can be applied immediately without a lookup elsewhere.
 *
 * @param {HTMLVideoElement} videoEl
 * @returns {Promise<Array<{
 *   class:       string,   // e.g. "car"
 *   score:       number,   // 0–1 confidence
 *   bbox:        [x, y, w, h],  // pixels
 *   realWidthCm: number    // lookup from KNOWN_WIDTHS_CM
 * }>>}
 */
export async function detectObjects(videoEl) {
  if (!videoEl) return [];

  const model = await loadModel();
  if (!model)  return [];

  // Skip frames where video hasn't started yet
  if (videoEl.readyState < 2) return [];

  try {
    const predictions = await model.detect(videoEl);

    return predictions
      .filter(p =>
        p.score >= MIN_CONFIDENCE &&
        ALLOWED_CLASSES.has(p.class)
      )
      .map(p => {
        const key = p.class.replace(' ', '_');
        return {
          class:       p.class,
          score:       p.score,
          bbox:        p.bbox,           // [x, y, w, h]
          realWidthCm: KNOWN_WIDTHS_CM[key],
        };
      });
  } catch (err) {
    console.warn('detectObjects inference error:', err);
    return [];
  }
}

// ---------------------------------------------------------------------------
// pickPrimaryTarget
// ---------------------------------------------------------------------------
/**
 * Selects the single most relevant detection from a list:
 *  1. Prefers obstacle classes (car, truck, bus, motorcycle, bicycle)
 *     over calibration objects (book, bottle, person, etc.)
 *  2. Among equals, picks the one with the largest bounding box area
 *     (largest area = closest to camera = most urgent)
 *
 * Used by both distance detection (pick nearest obstacle) and
 * calibration (pick whatever object is in frame).
 *
 * @param {Array} detections - output of detectObjects()
 * @returns {object|null}
 */
export function pickPrimaryTarget(detections) {
  if (!detections || detections.length === 0) return null;

  const OBSTACLE_CLASSES = new Set(['car', 'truck', 'bus', 'motorcycle', 'bicycle']);

  const obstacles = detections.filter(d => OBSTACLE_CLASSES.has(d.class));

  // Use obstacle detections if any exist, otherwise fall back to all detections
  const pool = obstacles.length > 0 ? obstacles : detections;

  // Largest bounding box area → closest / most prominent object
  return pool.reduce((best, current) => {
    const bestArea    = best.bbox[2]    * best.bbox[3];
    const currentArea = current.bbox[2] * current.bbox[3];
    return currentArea > bestArea ? current : best;
  });
}

// ---------------------------------------------------------------------------
// isModelReady
// ---------------------------------------------------------------------------
/**
 * Synchronous check — true if the model is already loaded.
 * Useful for showing a "Model loading..." indicator in the UI.
 * @returns {boolean}
 */
export function isModelReady() {
  return modelInstance !== null;
}