import React from 'react';
import { StyleSheet } from 'react-native';
import { CameraView as ExpoCameraView } from 'expo-camera';

/**
 * NativeCameraView
 * Native-only camera component using expo-camera.
 *
 * Props:
 *  facing     - 'back' | 'front'
 *  onReady    - called when camera hardware is ready
 *  onError    - called with error message string on failure
 */
export default function NativeCameraView({ facing, onReady, onError }) {
  return (
    <ExpoCameraView
      style={StyleSheet.absoluteFill}
      facing={facing === 'back' ? 'back' : 'front'}
      onCameraReady={() => {
        console.log('Native camera ready');
        onReady?.();
      }}
      onMountError={(event) => {
        console.error('Native camera mount error:', event?.message);
        onError?.(event?.message || 'Camera preview could not start.');
      }}
    />
  );
}