import { DETECTION } from '../constants/detection';

/**
 * Converts raw RGBA ImageData pixels to a flat Uint8Array of grayscale values.
 * Uses standard luminance weights: R*0.299 + G*0.587 + B*0.114
 * @param {ImageData} imageData
 * @returns {Uint8Array}
 */
export function toGrayscale(imageData) {
  const { data, width, height } = imageData;
  const gray = new Uint8Array(width * height);
  for (let i = 0; i < gray.length; i++) {
    const p = i * 4;
    gray[i] = (data[p] * 0.299 + data[p + 1] * 0.587 + data[p + 2] * 0.114) | 0;
  }
  return gray;
}

/**
 * Calculates the mean brightness across all pixels in the grayscale array.
 * @param {Uint8Array} gray
 * @returns {number}
 */
export function meanBrightness(gray) {
  let sum = 0;
  for (let i = 0; i < gray.length; i++) sum += gray[i];
  return sum / gray.length;
}

/**
 * Finds the bounding box of pixels that differ significantly from the mean
 * brightness inside the center ROI (region of interest) of the frame.
 *
 * This is the primary obstacle detection step:
 *  1. Restrict analysis to the center portion of the frame
 *  2. Compute mean brightness in that region
 *  3. Any pixel deviating more than `threshold` from the mean → foreground
 *  4. Track leftmost/rightmost/topmost/bottommost foreground pixel → bounding box
 *
 * @param {Uint8Array} gray     - Grayscale pixel array
 * @param {number}     width    - Frame width in pixels
 * @param {number}     height   - Frame height in pixels
 * @returns {{ x, y, w, h, pixelCount } | null}
 */
export function detectLargestBlob(gray, width, height) {
  const x0 = Math.floor(width  * DETECTION.roiStart);
  const x1 = Math.floor(width  * DETECTION.roiEnd);
  const y0 = Math.floor(height * DETECTION.roiStart);
  const y1 = Math.floor(height * DETECTION.roiEnd);

  // Step 1 — mean brightness inside ROI
  let total = 0;
  let count = 0;
  for (let y = y0; y < y1; y++) {
    for (let x = x0; x < x1; x++) {
      total += gray[y * width + x];
      count++;
    }
  }
  const mean = total / count;

  // Step 2 — find foreground bounding box
  let minX = x1, maxX = x0;
  let minY = y1, maxY = y0;
  let pixelCount = 0;

  for (let y = y0; y < y1; y++) {
    for (let x = x0; x < x1; x++) {
      const diff = Math.abs(gray[y * width + x] - mean);
      if (diff > DETECTION.brightnessThreshold) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
        pixelCount++;
      }
    }
  }

  if (pixelCount < DETECTION.minBlobArea) return null;

  return {
    x: minX,
    y: minY,
    w: maxX - minX,
    h: maxY - minY,
    pixelCount,
  };
}

/**
 * Draws a bounding box + distance label onto a canvas context.
 * Color is determined by the alert level.
 * @param {CanvasRenderingContext2D} ctx
 * @param {{ x, y, w, h }} bbox
 * @param {string} label           - e.g. "1.82m"
 * @param {'danger'|'warning'|'safe'|'clear'} level
 */
export function drawBoundingBox(ctx, bbox, label, level) {
  const colors = {
    danger:  '#E24B4A',
    warning: '#EF9F27',
    safe:    '#1D9E75',
    clear:   'rgba(255,255,255,0.4)',
  };
  const color = colors[level] || colors.clear;

  // Bounding box rectangle
  ctx.strokeStyle = color;
  ctx.lineWidth = 3;
  ctx.strokeRect(bbox.x, bbox.y, bbox.w, bbox.h);

  // Label background
  const padding = 4;
  ctx.font = 'bold 14px sans-serif';
  const textWidth = ctx.measureText(label).width;
  ctx.fillStyle = color;
  ctx.fillRect(bbox.x, bbox.y - 22, textWidth + padding * 2, 20);

  // Label text
  ctx.fillStyle = '#ffffff';
  ctx.fillText(label, bbox.x + padding, bbox.y - 6);

  // Dashed center-line guide from bottom of frame to box
  const cx = bbox.x + bbox.w / 2;
  ctx.strokeStyle = 'rgba(255,255,255,0.3)';
  ctx.lineWidth = 1;
  ctx.setLineDash([5, 5]);
  ctx.beginPath();
  ctx.moveTo(cx, ctx.canvas.height);
  ctx.lineTo(cx, bbox.y + bbox.h);
  ctx.stroke();
  ctx.setLineDash([]);
}

/**
 * Draws the three alert zones as semi-transparent overlays on the frame.
 * Zones are horizontal bands: bottom = danger (red), middle = warning, top = safe.
 * @param {CanvasRenderingContext2D} ctx
 * @param {number} width
 * @param {number} height
 */
export function drawZoneOverlay(ctx, width, height) {
  const zones = [
    { startFrac: 0.66, endFrac: 1.0,  color: 'rgba(226,75,74,0.08)',  label: 'DANGER' },
    { startFrac: 0.33, endFrac: 0.66, color: 'rgba(239,159,39,0.08)', label: 'CAUTION' },
    { startFrac: 0.0,  endFrac: 0.33, color: 'rgba(29,158,117,0.08)', label: 'SAFE' },
  ];

  zones.forEach(({ startFrac, endFrac, color, label }) => {
    const y     = Math.floor(height * startFrac);
    const zoneH = Math.floor(height * (endFrac - startFrac));
    ctx.fillStyle = color;
    ctx.fillRect(0, y, width, zoneH);

    ctx.fillStyle = 'rgba(255,255,255,0.25)';
    ctx.font = 'bold 11px sans-serif';
    ctx.fillText(label, 8, y + 16);
  });
}