import React, { useRef } from 'react';
import {
  View,
  ScrollView,
  StyleSheet,
  Platform,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

// Hooks
import { useCamera }            from '../hooks/useCamera';
import { useCalibration }       from '../hooks/useCalibration';
import { useDistanceDetection } from '../hooks/useDistanceDetection';

// Components
import HeroCard          from '../components/ui/heroCard';
import ControlsRow       from '../components/ui/controlsRow';
import CameraFrame       from '../components/camera/cameraFrame';
import CalibrationPanel  from '../components/calibration/calibrationPanel';
import MetricsBar        from '../components/metrics/metricsBar';
import AlertStatusBar    from '../components/metrics/alertStatusBar';

export default function HomeScreen() {
  // Refs for web camera frame access
  const videoRef  = useRef(null);
  const canvasRef = useRef(null);

  // --- Hooks ---
  const {
    cameraVisible, cameraReady, cameraError, facing,
    openCamera, closeCamera, toggleFacing,
    setCameraReady, setCameraError,
  } = useCamera();

  const {
    isCalibrated, focalLength,
    knownObjectWidth, setKnownObjectWidth,
    calibrationDist, setCalibrationDist,
    captureCalibration, resetCalibration,
  } = useCalibration();

  const {
    distance, speed, tti, alertLevel, statusMessage,
  } = useDistanceDetection({
    videoRef,
    canvasRef,
    focalLength,
    knownObjectWidthCm: knownObjectWidth,
    // Only run detection on web when camera is ready and calibrated
    enabled: Platform.OS === 'web' && cameraReady && isCalibrated,
  });

  // --- Calibration capture handler ---
  const handleCalibrationCapture = () => {
    if (Platform.OS === 'web') {
      const hiddenCanvas = document.getElementById('hidden-calibration-canvas');
      captureCalibration(videoRef.current, hiddenCanvas);
    }
    // Native calibration would use a different approach (e.g. CameraView snapshot)
  };

  // --- Render ---
  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.glowOne} />
      <View style={styles.glowTwo} />

      <ScrollView contentContainerStyle={styles.scroll}>

        <HeroCard
          onOpen={openCamera}
          onReset={closeCamera}
        />

        <View style={styles.shell}>

          {/* Camera feed */}
          <CameraFrame
            visible={cameraVisible}
            ready={cameraReady}
            error={cameraError}
            facing={facing}
            onReady={() => setCameraReady(true)}
            onError={(err) => { setCameraError(err); }}
            videoRef={videoRef}
            canvasRef={canvasRef}
          />

          {/* Camera controls */}
          <ControlsRow
            onToggleFacing={toggleFacing}
            onClose={closeCamera}
            cameraVisible={cameraVisible}
          />

          {/* Alert status */}
          <AlertStatusBar level={alertLevel} message={statusMessage} />

          {/* Distance / speed / TTI metrics */}
          <MetricsBar
            distance={distance}
            speed={speed}
            tti={tti}
          />

          {/* Calibration panel */}
          <CalibrationPanel
            isCalibrated={isCalibrated}
            focalLength={focalLength}
            knownObjectWidth={knownObjectWidth}
            calibrationDist={calibrationDist}
            onWidthChange={setKnownObjectWidth}
            onDistChange={setCalibrationDist}
            onCapture={handleCalibrationCapture}
            onReset={resetCalibration}
            cameraReady={cameraReady}
          />

        </View>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#07111f',
    position: 'relative',
  },
  glowOne: {
    position: 'absolute',
    width: 280, height: 280, borderRadius: 280,
    backgroundColor: 'rgba(88, 173, 255, 0.14)',
    top: -90, right: -80,
  },
  glowTwo: {
    position: 'absolute',
    width: 220, height: 220, borderRadius: 220,
    backgroundColor: 'rgba(0, 214, 201, 0.10)',
    bottom: 100, left: -80,
  },
  scroll: {
    padding: 20,
    gap: 16,
  },
  shell: {
    backgroundColor: 'rgba(8, 16, 29, 0.94)',
    borderRadius: 28,
    borderColor: 'rgba(255, 255, 255, 0.08)',
    borderWidth: 1,
    padding: 16,
    gap: 14,
  },
});