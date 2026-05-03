import React from 'react';
import { View, Text, StyleSheet, Platform } from 'react-native';
import WebCameraView    from './cameraView.web.js';
import NativeCameraView from './cameraView.native.js';

/**
 * CameraFrame
 * Shared wrapper that:
 *  - Picks Web or Native camera based on Platform.OS
 *  - Shows a loading overlay while camera initialises
 *  - Shows a placeholder when camera is closed or errored
 *  - Renders the detection overlay canvas (web only)
 *  - Forwards videoRef and canvasRef to parent for frame processing
 *
 * Props:
 *  visible      - bool: whether to show camera
 *  ready        - bool: whether camera stream is active
 *  error        - string: error message (empty = no error)
 *  facing       - 'back' | 'front'
 *  onReady      - callback when camera is ready
 *  onError      - callback(errorMsg) when camera fails
 *  videoRef     - ref forwarded to <video> element (web)
 *  canvasRef    - ref for detection overlay canvas (web)
 *  cameraRef    - ref forwarded to CameraView (native)
 *  fullscreen   - bool: if true, fill parent container completely
 */
export default function CameraFrame({
  visible,
  ready,
  error,
  facing,
  onReady,
  onError,
  videoRef,
  canvasRef,
  cameraRef,
  fullscreen = false,
}) {
  const frameStyle = fullscreen
    ? [styles.frame, styles.frameFullscreen]
    : styles.frame;

  console.log(
    `[CameraFrame] Render — visible:${visible}, ready:${ready}, ` +
    `error:"${error}", facing:${facing}, fullscreen:${fullscreen}, platform:${Platform.OS}`
  );

  return (
    <View style={frameStyle}>
      {visible && !error ? (
        <>
          {Platform.OS === 'web' ? (
            <WebCameraView
              facing={facing}
              onReady={() => {
                console.log('[CameraFrame] WebCameraView onReady fired');
                onReady?.();
              }}
              onError={(err) => {
                console.error('[CameraFrame] WebCameraView onError:', err);
                onError?.(err);
              }}
              videoRef={videoRef}
            />
          ) : (
            <NativeCameraView
              facing={facing}
              onReady={() => {
                console.log('[CameraFrame] NativeCameraView onReady fired');
                onReady?.();
              }}
              onError={(err) => {
                console.error('[CameraFrame] NativeCameraView onError:', err);
                onError?.(err);
              }}
              cameraRef={cameraRef}
            />
          )}

          {/* Detection overlay canvas — web only */}
          {Platform.OS === 'web' && (
            <canvas
              ref={canvasRef}
              style={{
                position: 'absolute',
                top: 0, left: 0,
                width: '100%', height: '100%',
                pointerEvents: 'none',
              }}
            />
          )}

          {/* Hidden canvas used for pixel reading — web only */}
          {Platform.OS === 'web' && (
            <canvas
              id="hidden-calibration-canvas"
              style={{ display: 'none' }}
            />
          )}

          {/* Loading overlay */}
          {!ready && (
            <View style={styles.overlay}>
              <Text style={styles.overlayTitle}>Starting camera</Text>
              <Text style={styles.overlayText}>Waiting for live preview...</Text>
            </View>
          )}
        </>
      ) : (
        <View style={styles.placeholder}>
          <Text style={styles.placeholderTitle}>
            {error ? 'Camera unavailable' : 'Camera preview appears here'}
          </Text>
          <Text style={styles.placeholderText}>
            {error || 'Tap Open Camera to start the live feed.'}
          </Text>
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  frame: {
    width: '100%',
    height: 500,
    borderRadius: 24,
    overflow: 'hidden',
    backgroundColor: '#0f1c2d',
    position: 'relative',
  },
  frameFullscreen: {
    height: '100%',
    borderRadius: 0,
    flex: 1,
  },
  overlay: {
    ...StyleSheet.absoluteFillObject,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#0f1c2d',
    padding: 24,
  },
  overlayTitle: {
    color: '#ffffff',
    fontSize: 20,
    fontWeight: '800',
    marginBottom: 8,
    textAlign: 'center',
  },
  overlayText: {
    color: 'rgba(234, 241, 255, 0.75)',
    textAlign: 'center',
    lineHeight: 20,
  },
  placeholder: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    padding: 24,
  },
  placeholderTitle: {
    color: '#ffffff',
    fontSize: 20,
    fontWeight: '800',
    marginBottom: 8,
    textAlign: 'center',
  },
  placeholderText: {
    color: 'rgba(234, 241, 255, 0.75)',
    textAlign: 'center',
    lineHeight: 20,
  },
});