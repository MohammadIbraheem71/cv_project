import React from 'react';
import { View, Text, TouchableOpacity, StyleSheet, Platform } from 'react-native';

/**
 * ControlsRow
 * Camera control buttons shown below the camera frame.
 *
 * Props:
 *  onToggleFacing - switches between front and back camera (native only)
 *  onClose        - closes the camera
 *  cameraVisible  - bool: only show controls when camera is open
 */
export default function ControlsRow({ onToggleFacing, onClose, cameraVisible }) {
  if (!cameraVisible) return null;

  return (
    <View style={styles.row}>
      {Platform.OS !== 'web' && (
        <TouchableOpacity style={styles.primaryButton} onPress={onToggleFacing}>
          <Text style={styles.primaryButtonText}>Switch camera</Text>
        </TouchableOpacity>
      )}
      <TouchableOpacity style={styles.secondaryButton} onPress={onClose}>
        <Text style={styles.secondaryButtonText}>Close</Text>
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  row: {
    flexDirection: 'row',
    gap: 12,
  },
  primaryButton: {
    flex: 1,
    backgroundColor: '#ffffff',
    paddingVertical: 14,
    borderRadius: 18,
    alignItems: 'center',
  },
  primaryButtonText: {
    color: '#04111c',
    fontSize: 15,
    fontWeight: '800',
  },
  secondaryButton: {
    paddingVertical: 14,
    paddingHorizontal: 20,
    borderRadius: 18,
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.08)',
    backgroundColor: 'rgba(255,255,255,0.04)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  secondaryButtonText: {
    color: '#eff7ff',
    fontSize: 15,
    fontWeight: '700',
  },
});