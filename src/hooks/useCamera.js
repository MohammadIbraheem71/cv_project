import { useState, useEffect, useRef } from 'react';
import { Platform, Alert } from 'react-native';
import { useCameraPermissions } from 'expo-camera';

/**
 * useCamera
 * Manages camera lifecycle: permissions, visibility, ready state, errors.
 * Abstracts the difference between web (getUserMedia) and native (expo-camera).
 *
 * @returns {{
 *   permission, requestPermission,
 *   cameraVisible, cameraReady, cameraError, facing,
 *   openCamera, closeCamera, toggleFacing,
 *   setCameraReady, setCameraError
 * }}
 */
export function useCamera() {
  const [permission, requestPermission] = useCameraPermissions();
  const [cameraVisible, setCameraVisible]   = useState(false);
  const [cameraReady,   setCameraReady]     = useState(false);
  const [cameraError,   setCameraError]     = useState('');
  const [facing,        setFacing]          = useState('back');
  const [permissionRequested, setPermissionRequested] = useState(false);

  // Request permissions automatically on native at startup
  useEffect(() => {
    if (permissionRequested || Platform.OS === 'web') return;
    (async () => {
      try {
        if (!permission?.granted) await requestPermission();
      } catch (err) {
        console.warn('Permission request failed:', err);
      } finally {
        setPermissionRequested(true);
      }
    })();
  }, [permission, requestPermission, permissionRequested]);

  const openCamera = async () => {
    try {
      setCameraError('');
      setCameraReady(false);
      if (Platform.OS === 'web') {
        // Web: browser will prompt for permission when getUserMedia is called
        setCameraVisible(true);
      } else if (permission?.granted) {
        setCameraVisible(true);
      } else {
        Alert.alert(
          'Permission needed',
          'Camera permission is required. Please allow camera access in settings.'
        );
      }
    } catch (err) {
      setCameraError('Could not open camera: ' + (err?.message || 'Unknown error'));
    }
  };

  const closeCamera = () => {
    setCameraVisible(false);
    setCameraReady(false);
    setCameraError('');
  };

  const toggleFacing = () => {
    setFacing((f) => (f === 'back' ? 'front' : 'back'));
  };

  return {
    permission,
    requestPermission,
    cameraVisible,
    cameraReady,
    cameraError,
    facing,
    openCamera,
    closeCamera,
    toggleFacing,
    setCameraReady,
    setCameraError,
  };
}