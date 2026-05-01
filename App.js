import React, { useState, useEffect, useRef } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  Alert,
  Platform,
  ScrollView,
} from 'react-native';
import { SafeAreaView, SafeAreaProvider } from 'react-native-safe-area-context';
import { CameraView, useCameraPermissions } from 'expo-camera';

// Web camera component using getUserMedia
function WebCamera({ onReady, onError, facing }) {
  const videoRef = useRef(null);
  const streamRef = useRef(null);

  // Only render on web platform
  if (Platform.OS !== 'web') {
    return null;
  }

  useEffect(() => {
    const startWebCamera = async () => {
      try {
        const constraints = {
          video: {
            facingMode: facing === 'back' ? 'environment' : 'user',
            width: { ideal: 720 },
            height: { ideal: 1280 },
          },
          audio: false,
        };

        const stream = await navigator.mediaDevices.getUserMedia(constraints);
        streamRef.current = stream;

        if (videoRef.current) {
          videoRef.current.srcObject = stream;
          onReady?.();
        }
      } catch (error) {
        console.error('Web camera error:', error);
        onError?.(error?.message || 'Failed to access camera');
      }
    };

    startWebCamera();

    return () => {
      if (streamRef.current) {
        streamRef.current.getTracks().forEach((track) => track.stop());
      }
    };
  }, [facing, onReady, onError]);

  return (
    <video
      ref={videoRef}
      autoPlay
      playsInline
      style={{
        width: '100%',
        height: '100%',
        borderRadius: 24,
        objectFit: 'cover',
        backgroundColor: '#0f1c2d',
      }}
    />
  );
}

export default function App() {
  const [permission, requestPermission] = useCameraPermissions();
  const [cameraVisible, setCameraVisible] = useState(false);
  const [cameraReady, setCameraReady] = useState(false);
  const [cameraError, setCameraError] = useState('');
  const [facing, setFacing] = useState('back');
  const [permissionRequested, setPermissionRequested] = useState(false);

  // Request camera permissions on app startup (mobile only)
  useEffect(() => {
    if (!permissionRequested && Platform.OS !== 'web') {
      (async () => {
        try {
          if (!permission?.granted) {
            await requestPermission();
          }
          setPermissionRequested(true);
        } catch (error) {
          console.warn('Failed to request permissions:', error);
          setPermissionRequested(true);
        }
      })();
    }
  }, [permission, requestPermission, permissionRequested]);

  const openCamera = async () => {
    try {
      // On web, we don't pre-check permissions; the browser will prompt
      if (Platform.OS === 'web') {
        setCameraError('');
        setCameraReady(false);
        setCameraVisible(true);
      } else if (permission?.granted) {
        // On mobile, check if permission is already granted
        setCameraError('');
        setCameraReady(false);
        setCameraVisible(true);
      } else {
        // Permission not granted on mobile
        Alert.alert('Permission needed', 'Camera permission is required. Please allow camera access in settings.');
      }
    } catch (error) {
      setCameraError('Could not open camera: ' + (error?.message || 'Unknown error'));
      console.error('Camera open error:', error);
    }
  };

  const closeCamera = () => {
    setCameraVisible(false);
    setCameraReady(false);
    setCameraError('');
  };

  const toggleFacing = () => {
    setFacing((currentFacing) => (currentFacing === 'back' ? 'front' : 'back'));
  };

  return (
    <SafeAreaProvider>
      <SafeAreaView style={styles.container}>
      <View style={styles.backgroundGlowOne} />
      <View style={styles.backgroundGlowTwo} />

      <ScrollView contentContainerStyle={styles.scrollContent}>
        <View style={styles.heroCard}>
          <Text style={styles.heading}>Find distance of your car from the rear obstacle/hurdle to avoid a rear-end collision</Text>

          <View style={styles.ctaRow}>
            <TouchableOpacity style={styles.primaryButton} onPress={openCamera} accessibilityLabel="Open camera">
              <Text style={styles.primaryButtonText}>Open Camera</Text>
            </TouchableOpacity>

            <TouchableOpacity style={styles.secondaryButton} onPress={closeCamera} accessibilityLabel="Close camera">
              <Text style={styles.secondaryButtonText}>Reset View</Text>
            </TouchableOpacity>
          </View>
        </View>

        <View style={styles.previewShell}>
          <View style={styles.previewHeader}>
            <View>
              <Text style={styles.previewLabel}>Live Camera</Text>
              <Text style={styles.previewStatus}>
                {cameraError
                  ? cameraError
                  : cameraVisible
                    ? cameraReady
                      ? 'Camera running'
                      : 'Starting camera...'
                    : 'Preview ready to open'}
              </Text>
            </View>

            {cameraVisible ? (
              <Text style={styles.previewBadge}>
                {cameraReady ? (Platform.OS === 'web' ? 'Web preview' : 'Mobile preview') : 'Loading'}
              </Text>
            ) : null}
          </View>

          <View style={styles.overlayPanel}>
            <Text style={styles.overlayTitle}>Realtime Distance Processing</Text>
          </View>

          <View style={styles.cameraFrame}>
            {cameraVisible && !cameraError ? (
              <>
                {Platform.OS === 'web' ? (
                  <WebCamera
                    facing={facing}
                    onReady={() => setCameraReady(true)}
                    onError={(error) => {
                      setCameraError(error);
                      setCameraVisible(false);
                    }}
                  />
                ) : (
                  <CameraView
                    style={styles.camera}
                    facing={facing === 'back' ? 'back' : 'front'}
                    onCameraReady={() => {
                      console.log('Camera ready');
                      setCameraReady(true);
                    }}
                    onMountError={(event) => {
                      console.error('Camera mount error:', event?.message);
                      setCameraError(event?.message || 'Camera preview could not start.');
                      setCameraVisible(false);
                      setCameraReady(false);
                    }}
                  />
                )}

                {!cameraReady ? (
                  <View style={styles.loadingOverlay}>
                    <Text style={styles.placeholderTitle}>Starting camera</Text>
                    <Text style={styles.placeholderText}>Waiting for the live preview to initialize.</Text>
                  </View>
                ) : null}
              </>
            ) : (
              <View style={styles.placeholder}>
                <Text style={styles.placeholderTitle}>
                  {cameraError ? 'Camera unavailable' : 'Camera preview appears here'}
                </Text>
                <Text style={styles.placeholderText}>
                  {cameraError || 'Tap Open Camera to start the live feed.'}
                </Text>
              </View>
            )}
          </View>

          <View style={styles.controlsRow}>
            {Platform.OS !== 'web' ? (
              <TouchableOpacity style={styles.controlButton} onPress={toggleFacing}>
                <Text style={styles.controlButtonText}>Switch Camera</Text>
              </TouchableOpacity>
            ) : null}

            <TouchableOpacity style={styles.controlButtonAlt} onPress={closeCamera}>
              <Text style={styles.controlButtonAltText}>Close</Text>
            </TouchableOpacity>
          </View>
        </View>
      </ScrollView>
    </SafeAreaView>
    </SafeAreaProvider>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#07111f',
    position: 'relative',
  },
  backgroundGlowOne: {
    position: 'absolute',
    width: 280,
    height: 280,
    borderRadius: 280,
    backgroundColor: 'rgba(88, 173, 255, 0.16)',
    top: -90,
    right: -80,
  },
  backgroundGlowTwo: {
    position: 'absolute',
    width: 220,
    height: 220,
    borderRadius: 220,
    backgroundColor: 'rgba(0, 214, 201, 0.12)',
    bottom: 100,
    left: -80,
  },
  scrollContent: {
    padding: 20,
    gap: 18,
  },
  heroCard: {
    backgroundColor: 'rgba(10, 20, 35, 0.88)',
    borderColor: 'rgba(255, 255, 255, 0.08)',
    borderWidth: 1,
    borderRadius: 28,
    padding: 22,
  },
  kicker: {
    color: '#66e3ff',
    letterSpacing: 2.5,
    fontSize: 12,
    fontWeight: '700',
    marginBottom: 12,
  },
  heading: {
    color: '#ffffff',
    fontSize: 32,
    lineHeight: 38,
    fontWeight: '800',
    marginBottom: 12,
  },
  subheading: {
    color: 'rgba(234, 241, 255, 0.78)',
    fontSize: 15,
    lineHeight: 22,
  },
  ctaRow: {
    flexDirection: 'row',
    gap: 12,
    marginTop: 22,
    flexWrap: 'wrap',
  },
  primaryButton: {
    backgroundColor: '#5de1ff',
    paddingVertical: 14,
    paddingHorizontal: 22,
    borderRadius: 18,
    minWidth: 140,
    alignItems: 'center',
  },
  primaryButtonText: {
    color: '#04111c',
    fontSize: 16,
    fontWeight: '800',
  },
  secondaryButton: {
    backgroundColor: 'rgba(255, 255, 255, 0.06)',
    borderColor: 'rgba(255, 255, 255, 0.08)',
    borderWidth: 1,
    paddingVertical: 14,
    paddingHorizontal: 22,
    borderRadius: 18,
    minWidth: 120,
    alignItems: 'center',
  },
  secondaryButtonText: {
    color: '#eff7ff',
    fontSize: 16,
    fontWeight: '700',
  },
  previewShell: {
    backgroundColor: 'rgba(8, 16, 29, 0.94)',
    borderRadius: 28,
    borderColor: 'rgba(255, 255, 255, 0.08)',
    borderWidth: 1,
    padding: 16,
    gap: 14,
  },
  previewHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    gap: 12,
  },
  previewLabel: {
    color: '#ffffff',
    fontSize: 18,
    fontWeight: '800',
  },
  previewStatus: {
    color: 'rgba(234, 241, 255, 0.7)',
    marginTop: 4,
  },
  previewBadge: {
    color: '#07111f',
    backgroundColor: '#7bf6cf',
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 999,
    overflow: 'hidden',
    fontWeight: '800',
    fontSize: 12,
  },
  overlayPanel: {
    backgroundColor: 'rgba(93, 225, 255, 0.12)',
    borderColor: 'rgba(93, 225, 255, 0.2)',
    borderWidth: 1,
    borderRadius: 20,
    padding: 14,
  },
  overlayTitle: {
    color: '#d7fbff',
    fontSize: 15,
    fontWeight: '800',
    marginBottom: 6,
  },
  overlayText: {
    color: 'rgba(234, 241, 255, 0.8)',
    lineHeight: 20,
  },
  cameraFrame: {
    width: '100%',
    height: 600,
    borderRadius: 24,
    overflow: 'hidden',
    backgroundColor: '#0f1c2d',
  },
  camera: {
    ...StyleSheet.absoluteFillObject,
  },
  loadingOverlay: {
    ...StyleSheet.absoluteFillObject,
    alignItems: 'center',
    justifyContent: 'center',
    padding: 24,
    backgroundColor: '#0f1c2d',
  },
  placeholder: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    padding: 24,
    backgroundColor: '#0f1c2d',
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
  controlsRow: {
    flexDirection: 'row',
    gap: 12,
  },
  controlButton: {
    flex: 1,
    backgroundColor: '#ffffff',
    paddingVertical: 14,
    borderRadius: 18,
    alignItems: 'center',
  },
  controlButtonText: {
    color: '#04111c',
    fontSize: 15,
    fontWeight: '800',
  },
  controlButtonAlt: {
    paddingVertical: 14,
    paddingHorizontal: 20,
    borderRadius: 18,
    borderWidth: 1,
    borderColor: 'rgba(255, 255, 255, 0.08)',
    backgroundColor: 'rgba(255, 255, 255, 0.04)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  controlButtonAltText: {
    color: '#eff7ff',
    fontSize: 15,
    fontWeight: '700',
  },
});
