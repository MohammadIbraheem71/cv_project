import React, { useEffect } from 'react';
import { View, Text, StyleSheet, Dimensions } from 'react-native';

/**
 * NativeBoundingBox
 * Renders a bounding box overlay for Android/iOS using React Native Views.
 * Since we can't use HTML Canvas on native, we position absolute Views
 * to mimic the bounding box drawn on web.
 *
 * Props:
 *  bbox       - { x, y, w, h, label, pixelCount } — from useDistanceDetection
 *  alertLevel - 'danger' | 'warning' | 'safe' | 'clear'
 *
 * Coordinates in bbox are expressed as fractions of the frame (0–1),
 * so this component scales them to the actual screen dimensions.
 */
export default function NativeBoundingBox({ bbox, alertLevel }) {
  const { width: screenW, height: screenH } = Dimensions.get('window');

  useEffect(() => {
    if (bbox) {
      console.log(
        `[NativeBoundingBox] Rendering bbox — x:${bbox.x?.toFixed(3)}, y:${bbox.y?.toFixed(3)}, ` +
        `w:${bbox.w?.toFixed(3)}, h:${bbox.h?.toFixed(3)}, label:"${bbox.label}", level:${alertLevel}`
      );
    }
  }, [bbox, alertLevel]);

  if (!bbox) {
    console.log('[NativeBoundingBox] No bbox — not rendering');
    return null;
  }

  const colors = {
    danger:  '#E24B4A',
    warning: '#EF9F27',
    safe:    '#1D9E75',
    clear:   'rgba(255,255,255,0.5)',
  };
  const color = colors[alertLevel] || colors.clear;

  // bbox coords are fractions (0–1) mapped to screen pixels
  const left   = bbox.x * screenW;
  const top    = bbox.y * screenH;
  const width  = bbox.w * screenW;
  const height = bbox.h * screenH;

  const CORNER = 16;
  const THICKNESS = 3;

  return (
    <View
      pointerEvents="none"
      style={[styles.container, { left, top, width, height }]}
    >
      {/* ── Corner brackets ── */}
      {/* Top-left */}
      <View style={[styles.cornerH, { top: 0, left: 0, backgroundColor: color, width: CORNER, height: THICKNESS }]} />
      <View style={[styles.cornerV, { top: 0, left: 0, backgroundColor: color, width: THICKNESS, height: CORNER }]} />
      {/* Top-right */}
      <View style={[styles.cornerH, { top: 0, right: 0, backgroundColor: color, width: CORNER, height: THICKNESS }]} />
      <View style={[styles.cornerV, { top: 0, right: 0, backgroundColor: color, width: THICKNESS, height: CORNER }]} />
      {/* Bottom-left */}
      <View style={[styles.cornerH, { bottom: 0, left: 0, backgroundColor: color, width: CORNER, height: THICKNESS }]} />
      <View style={[styles.cornerV, { bottom: 0, left: 0, backgroundColor: color, width: THICKNESS, height: CORNER }]} />
      {/* Bottom-right */}
      <View style={[styles.cornerH, { bottom: 0, right: 0, backgroundColor: color, width: CORNER, height: THICKNESS }]} />
      <View style={[styles.cornerV, { bottom: 0, right: 0, backgroundColor: color, width: THICKNESS, height: CORNER }]} />

      {/* ── Label chip ── */}
      {bbox.label ? (
        <View style={[styles.labelChip, { backgroundColor: color }]}>
          <Text style={styles.labelText}>{bbox.label}</Text>
        </View>
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    position: 'absolute',
  },
  cornerH: {
    position: 'absolute',
    borderRadius: 1,
  },
  cornerV: {
    position: 'absolute',
    borderRadius: 1,
  },
  labelChip: {
    position: 'absolute',
    top: -26,
    left: 0,
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: 6,
  },
  labelText: {
    color: '#ffffff',
    fontSize: 12,
    fontWeight: '800',
  },
});