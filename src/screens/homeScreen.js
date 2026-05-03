import React, { useRef, useState, useEffect } from 'react';
import {
  View,
  ScrollView,
  StyleSheet,
  Platform,
  Alert,
  TouchableOpacity,
  Text,
  Modal,
  StatusBar,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

// Hooks
import { useCamera }            from '../hooks/useCamera';
import { useCalibration }       from '../hooks/useCalibration';
import { useDistanceDetection } from '../hooks/useDistanceDetection';

// Components
import CameraFrame       from '../components/camera/cameraFrame';
import CalibrationPanel  from '../components/calibration/calibrationPanel';
import MetricsBar        from '../components/metrics/metricsBar';
import AlertStatusBar    from '../components/metrics/alertStatusBar';
import NativeBoundingBox from '../components/detection/nativeBoundingBox';

// Utils
import { calculateFocalLength } from '../utils/distanceMath';

export default function HomeScreen() {
  console.log('[HomeScreen] Rendering HomeScreen');

  // Refs for web camera frame access
  const videoRef  = useRef(null);
  const canvasRef = useRef(null);
  const cameraRef = useRef(null); // For native camera snapshot

  // UI state
  const [showMenu,        setShowMenu]        = useState(false);
  const [showCalibration, setShowCalibration] = useState(false);

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
    setFocalLength,
    setIsCalibrated,
  } = useCalibration();

  const {
    distance, speed, tti, alertLevel, statusMessage,
    nativeBoundingBox,
  } = useDistanceDetection({
    videoRef,
    canvasRef,
    focalLength,
    knownObjectWidthCm: knownObjectWidth,
    enabled: cameraReady && isCalibrated,
  });

  // Auto-open camera on mount for camera-first experience
  useEffect(() => {
    console.log('[HomeScreen] Component mounted — auto-opening camera');
    const timer = setTimeout(() => {
      openCamera();
    }, 300);
    return () => clearTimeout(timer);
  }, []);

  // Log whenever camera state changes
  useEffect(() => {
    console.log(`[HomeScreen] Camera state — visible: ${cameraVisible}, ready: ${cameraReady}, error: "${cameraError}"`);
  }, [cameraVisible, cameraReady, cameraError]);

  // Log detection metrics
  useEffect(() => {
    if (distance !== null) {
      console.log(`[HomeScreen] Detection — distance: ${distance}m, speed: ${speed}m/s, tti: ${tti}s, level: ${alertLevel}`);
    }
  }, [distance, speed, tti, alertLevel]);

  // --- Calibration capture handler ---
  const handleCalibrationCapture = async () => {
    console.log(`[HomeScreen] Calibration capture triggered — platform: ${Platform.OS}`);
    if (Platform.OS === 'web') {
      const hiddenCanvas = document.getElementById('hidden-calibration-canvas');
      captureCalibration(videoRef.current, hiddenCanvas);
    } else {
      try {
        if (!cameraRef.current) {
          console.warn('[HomeScreen] Calibration failed — cameraRef not ready');
          Alert.alert('Error', 'Camera not ready');
          return;
        }

        // For native calibration: estimate focal length from entered params
        // Assumes detected object fills roughly 120px at the given distance
        const estimatedPixelWidth = 120;
        const fl = calculateFocalLength(estimatedPixelWidth, calibrationDist, knownObjectWidth);
        const flRounded = Math.round(fl);

        console.log(`[HomeScreen] Native calibration — estimatedPixelWidth: ${estimatedPixelWidth}, fl computed: ${flRounded}px`);

        setFocalLength(flRounded);
        setIsCalibrated(true);

        Alert.alert(
          'Calibration complete',
          `Focal length estimated: ${flRounded}px\n\nFor best accuracy:\n• Place a known object (${knownObjectWidth}cm) in center\n• Distance should be ${calibrationDist}cm\n• Adjust if detections are inaccurate`
        );
      } catch (err) {
        console.error('[HomeScreen] Native calibration error:', err);
        Alert.alert('Calibration failed', err?.message || 'Unknown error');
      }
    }
  };

  const handleMenuOpen = () => {
    console.log('[HomeScreen] Menu opened');
    setShowMenu(true);
  };

  const handleMenuClose = () => {
    console.log('[HomeScreen] Menu closed');
    setShowMenu(false);
  };

  const handleOpenCalibration = () => {
    console.log('[HomeScreen] Opening calibration panel');
    setShowMenu(false);
    setShowCalibration(true);
  };

  const handleCloseCalibration = () => {
    console.log('[HomeScreen] Closing calibration panel');
    setShowCalibration(false);
  };

  const handleReset = () => {
    console.log('[HomeScreen] Resetting calibration');
    resetCalibration();
    setShowCalibration(false);
  };

  // --- Render ---
  return (
    <View style={styles.container}>
      <StatusBar barStyle="light-content" translucent backgroundColor="transparent" />

      {/* FULLSCREEN CAMERA — always fills screen */}
      <View style={StyleSheet.absoluteFill}>
        <CameraFrame
          visible={cameraVisible}
          ready={cameraReady}
          error={cameraError}
          facing={facing}
          onReady={() => {
            console.log('[HomeScreen] Camera ready callback fired');
            setCameraReady(true);
          }}
          onError={(err) => {
            console.error('[HomeScreen] Camera error:', err);
            setCameraError(err);
          }}
          videoRef={videoRef}
          canvasRef={canvasRef}
          cameraRef={cameraRef}
          fullscreen
        />
      </View>

      {/* Native bounding box overlay — Android/iOS only */}
      {Platform.OS !== 'web' && nativeBoundingBox && (
        <NativeBoundingBox bbox={nativeBoundingBox} alertLevel={alertLevel} />
      )}

      {/* TOP STATUS BAR */}
      <SafeAreaView style={styles.safeTop} edges={['top']}>
        <View style={styles.topRow}>
          <View style={styles.statusWrapper}>
            <AlertStatusBar level={alertLevel} message={statusMessage} />
          </View>

          {/* 3-DOT MENU BUTTON */}
          <TouchableOpacity
            style={styles.menuButton}
            onPress={handleMenuOpen}
            hitSlop={{ top: 10, bottom: 10, left: 10, right: 10 }}
          >
            <Text style={styles.menuDots}>⋮</Text>
          </TouchableOpacity>
        </View>
      </SafeAreaView>

      {/* BOTTOM METRICS + CONTROLS */}
      <SafeAreaView style={styles.safeBottom} edges={['bottom']}>
        <View style={styles.bottomPanel}>
          <MetricsBar distance={distance} speed={speed} tti={tti} />

          {/* Camera toggle row */}
          <View style={styles.cameraControls}>
            {!cameraVisible ? (
              <TouchableOpacity style={styles.openBtn} onPress={() => {
                console.log('[HomeScreen] Open camera tapped');
                openCamera();
              }}>
                <Text style={styles.openBtnText}>Open Camera</Text>
              </TouchableOpacity>
            ) : (
              <>
                {Platform.OS !== 'web' && (
                  <TouchableOpacity style={styles.secondaryBtn} onPress={() => {
                    console.log('[HomeScreen] Toggle facing tapped');
                    toggleFacing();
                  }}>
                    <Text style={styles.secondaryBtnText}>Flip</Text>
                  </TouchableOpacity>
                )}
                <TouchableOpacity style={styles.secondaryBtn} onPress={() => {
                  console.log('[HomeScreen] Close camera tapped');
                  closeCamera();
                }}>
                  <Text style={styles.secondaryBtnText}>Close</Text>
                </TouchableOpacity>
              </>
            )}
          </View>
        </View>
      </SafeAreaView>

      {/* ── 3-DOT DROPDOWN MENU ── */}
      <Modal
        visible={showMenu}
        transparent
        animationType="fade"
        onRequestClose={handleMenuClose}
      >
        <TouchableOpacity style={styles.menuBackdrop} activeOpacity={1} onPress={handleMenuClose}>
          <View style={styles.menuDropdown}>
            <TouchableOpacity style={styles.menuItem} onPress={handleOpenCalibration}>
              <Text style={styles.menuItemIcon}>🎯</Text>
              <Text style={styles.menuItemText}>Calibration mode</Text>
            </TouchableOpacity>
            <View style={styles.menuDivider} />
            <TouchableOpacity style={styles.menuItem} onPress={() => {
              console.log('[HomeScreen] Reset all from menu');
              handleMenuClose();
              resetCalibration();
              closeCamera();
            }}>
              <Text style={styles.menuItemIcon}>↺</Text>
              <Text style={styles.menuItemText}>Reset all</Text>
            </TouchableOpacity>
          </View>
        </TouchableOpacity>
      </Modal>

      {/* ── CALIBRATION MODAL ── */}
      <Modal
        visible={showCalibration}
        transparent
        animationType="slide"
        onRequestClose={handleCloseCalibration}
      >
        <View style={styles.calBackdrop}>
          <View style={styles.calSheet}>
            {/* Handle bar */}
            <View style={styles.sheetHandle} />

            <Text style={styles.sheetTitle}>Calibration</Text>

            <CalibrationPanel
              isCalibrated={isCalibrated}
              focalLength={focalLength}
              knownObjectWidth={knownObjectWidth}
              calibrationDist={calibrationDist}
              onWidthChange={(v) => {
                console.log(`[HomeScreen] knownObjectWidth changed to: ${v}`);
                setKnownObjectWidth(v);
              }}
              onDistChange={(v) => {
                console.log(`[HomeScreen] calibrationDist changed to: ${v}`);
                setCalibrationDist(v);
              }}
              onCapture={handleCalibrationCapture}
              onReset={handleReset}
              cameraReady={cameraReady}
            />

            <TouchableOpacity style={styles.sheetCloseBtn} onPress={handleCloseCalibration}>
              <Text style={styles.sheetCloseBtnText}>Done</Text>
            </TouchableOpacity>
          </View>
        </View>
      </Modal>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#000',
  },

  // ── Top overlay ──
  safeTop: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
  },
  topRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingTop: 8,
    gap: 10,
  },
  statusWrapper: {
    flex: 1,
  },

  // ── 3-dot button ──
  menuButton: {
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: 'rgba(0,0,0,0.55)',
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.12)',
  },
  menuDots: {
    color: '#fff',
    fontSize: 22,
    lineHeight: 26,
    fontWeight: '700',
  },

  // ── Bottom panel ──
  safeBottom: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
  },
  bottomPanel: {
    paddingHorizontal: 16,
    paddingBottom: 12,
    paddingTop: 16,
    gap: 12,
    backgroundColor: 'rgba(0,0,0,0.55)',
    borderTopLeftRadius: 24,
    borderTopRightRadius: 24,
    borderTopWidth: 1,
    borderTopColor: 'rgba(255,255,255,0.07)',
  },
  cameraControls: {
    flexDirection: 'row',
    gap: 10,
  },
  openBtn: {
    flex: 1,
    backgroundColor: '#5de1ff',
    paddingVertical: 14,
    borderRadius: 16,
    alignItems: 'center',
  },
  openBtnText: {
    color: '#04111c',
    fontWeight: '800',
    fontSize: 15,
  },
  secondaryBtn: {
    flex: 1,
    paddingVertical: 14,
    borderRadius: 16,
    alignItems: 'center',
    backgroundColor: 'rgba(255,255,255,0.08)',
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.1)',
  },
  secondaryBtnText: {
    color: '#eff7ff',
    fontWeight: '700',
    fontSize: 15,
  },

  // ── 3-dot dropdown menu ──
  menuBackdrop: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.3)',
  },
  menuDropdown: {
    position: 'absolute',
    top: 100,
    right: 16,
    backgroundColor: '#0f1c2d',
    borderRadius: 16,
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.1)',
    overflow: 'hidden',
    minWidth: 200,
    shadowColor: '#000',
    shadowOpacity: 0.4,
    shadowRadius: 12,
    elevation: 12,
  },
  menuItem: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 14,
    gap: 12,
  },
  menuItemIcon: {
    fontSize: 18,
  },
  menuItemText: {
    color: '#eff7ff',
    fontSize: 15,
    fontWeight: '600',
  },
  menuDivider: {
    height: 1,
    backgroundColor: 'rgba(255,255,255,0.07)',
    marginHorizontal: 16,
  },

  // ── Calibration bottom sheet ──
  calBackdrop: {
    flex: 1,
    justifyContent: 'flex-end',
    backgroundColor: 'rgba(0,0,0,0.6)',
  },
  calSheet: {
    backgroundColor: '#07111f',
    borderTopLeftRadius: 28,
    borderTopRightRadius: 28,
    padding: 20,
    paddingBottom: 36,
    gap: 16,
    borderTopWidth: 1,
    borderTopColor: 'rgba(255,255,255,0.08)',
  },
  sheetHandle: {
    width: 40,
    height: 4,
    backgroundColor: 'rgba(255,255,255,0.2)',
    borderRadius: 2,
    alignSelf: 'center',
    marginBottom: 4,
  },
  sheetTitle: {
    color: '#ffffff',
    fontSize: 18,
    fontWeight: '800',
    textAlign: 'center',
  },
  sheetCloseBtn: {
    backgroundColor: 'rgba(93,225,255,0.1)',
    borderWidth: 1,
    borderColor: 'rgba(93,225,255,0.3)',
    paddingVertical: 14,
    borderRadius: 16,
    alignItems: 'center',
    marginTop: 4,
  },
  sheetCloseBtnText: {
    color: '#5de1ff',
    fontSize: 15,
    fontWeight: '800',
  },
});