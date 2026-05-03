import React from 'react';
import { View, Text, TouchableOpacity, StyleSheet } from 'react-native';
import CalibrationInput from './calibrationInput';

/**
 * CalibrationPanel
 * Full calibration UI panel.
 * Shows input fields for known object width and distance,
 * displays computed focal length, and triggers calibration capture.
 *
 * Props:
 *  isCalibrated       - bool
 *  focalLength        - number|null
 *  knownObjectWidth   - number (cm)
 *  calibrationDist    - number (cm)
 *  onWidthChange      - (value: number) => void
 *  onDistChange       - (value: number) => void
 *  onCapture          - () => void  — triggers calibration snapshot
 *  onReset            - () => void
 *  cameraReady        - bool — disables button if camera not ready
 */
export default function CalibrationPanel({
  isCalibrated,
  focalLength,
  knownObjectWidth,
  calibrationDist,
  onWidthChange,
  onDistChange,
  onCapture,
  onReset,
  cameraReady,
}) {
  return (
    <View style={styles.panel}>
      <View style={styles.header}>
        <Text style={styles.title}>Calibration</Text>
        <View style={[styles.badge, isCalibrated ? styles.badgeDone : styles.badgePending]}>
          <Text style={[styles.badgeText, isCalibrated ? styles.badgeDoneText : styles.badgePendingText]}>
            {isCalibrated ? 'Calibrated' : 'Not calibrated'}
          </Text>
        </View>
      </View>

      <Text style={styles.instructions}>
        Place a known object in the center of the frame at a measured distance, then tap Capture.
      </Text>

      <CalibrationInput
        label="Object width (cm)"
        value={knownObjectWidth}
        onChange={onWidthChange}
        hint="e.g. car bumper = 180cm, book = 30cm"
      />

      <CalibrationInput
        label="Distance to object (cm)"
        value={calibrationDist}
        onChange={onDistChange}
        hint="Measure with a tape measure for accuracy"
      />

      {isCalibrated && focalLength !== null && (
        <View style={styles.result}>
          <Text style={styles.resultLabel}>Computed focal length</Text>
          <Text style={styles.resultValue}>{focalLength} px</Text>
        </View>
      )}

      <View style={styles.buttonRow}>
        <TouchableOpacity
          style={[styles.captureButton, !cameraReady && styles.buttonDisabled]}
          onPress={onCapture}
          disabled={!cameraReady}
        >
          <Text style={styles.captureButtonText}>
            {isCalibrated ? 'Recalibrate' : 'Capture frame'}
          </Text>
        </TouchableOpacity>

        {isCalibrated && (
          <TouchableOpacity style={styles.resetButton} onPress={onReset}>
            <Text style={styles.resetButtonText}>Reset</Text>
          </TouchableOpacity>
        )}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  panel: {
    backgroundColor: 'rgba(255, 255, 255, 0.04)',
    borderColor: 'rgba(255, 255, 255, 0.08)',
    borderWidth: 1,
    borderRadius: 20,
    padding: 16,
    gap: 12,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  title: {
    color: '#ffffff',
    fontSize: 16,
    fontWeight: '800',
  },
  badge: {
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: 999,
    overflow: 'hidden',
  },
  badgeDone: {
    backgroundColor: 'rgba(123, 246, 207, 0.15)',
  },
  badgePending: {
    backgroundColor: 'rgba(239, 159, 39, 0.15)',
  },
  badgeText: {
    fontSize: 12,
    fontWeight: '700',
  },
  badgeDoneText: {
    color: '#7bf6cf',
  },
  badgePendingText: {
    color: '#EF9F27',
  },
  instructions: {
    color: 'rgba(234, 241, 255, 0.65)',
    fontSize: 13,
    lineHeight: 19,
  },
  result: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    backgroundColor: 'rgba(93, 225, 255, 0.08)',
    borderRadius: 10,
    paddingHorizontal: 12,
    paddingVertical: 8,
  },
  resultLabel: {
    color: 'rgba(234, 241, 255, 0.7)',
    fontSize: 13,
  },
  resultValue: {
    color: '#5de1ff',
    fontSize: 15,
    fontWeight: '800',
  },
  buttonRow: {
    flexDirection: 'row',
    gap: 10,
  },
  captureButton: {
    flex: 1,
    backgroundColor: '#5de1ff',
    paddingVertical: 13,
    borderRadius: 14,
    alignItems: 'center',
  },
  buttonDisabled: {
    opacity: 0.4,
  },
  captureButtonText: {
    color: '#04111c',
    fontWeight: '800',
    fontSize: 14,
  },
  resetButton: {
    paddingVertical: 13,
    paddingHorizontal: 18,
    borderRadius: 14,
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.1)',
    alignItems: 'center',
  },
  resetButtonText: {
    color: '#eff7ff',
    fontSize: 14,
    fontWeight: '700',
  },
});