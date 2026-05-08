import React, { useRef, useEffect } from 'react';

/**
 * WebCameraView
 * Web-only camera component using the getUserMedia API.
 * Renders a <video> element and pipes the camera stream into it.
 *
 * Props:
 *  facing     - 'back' | 'front'
 *  onReady    - called when video starts playing
 *  onError    - called with error message string on failure
 *  videoRef   - forwarded ref so parent can read frames from the video element
 */
export default function WebCameraView({ facing, onReady, onError, videoRef }) {
  const internalRef = useRef(null);
  const streamRef   = useRef(null);
  const ref         = videoRef || internalRef;

  useEffect(() => {
    const start = async () => {
      try {
        const constraints = {
          video: {
            facingMode: facing === 'back' ? 'environment' : 'user',
            width:  { ideal: 720 },
            height: { ideal: 1280 },
          },
          audio: false,
        };
        const stream = await navigator.mediaDevices.getUserMedia(constraints);
        streamRef.current = stream;
        if (ref.current) {
          ref.current.srcObject = stream;
          ref.current.onloadedmetadata = () => onReady?.();
        }
      } catch (err) {
        console.error('WebCameraView error:', err);
        onError?.(err?.message || 'Failed to access camera');
      }
    };

    start();

    return () => {
      streamRef.current?.getTracks().forEach((t) => t.stop());
    };
  }, [facing]);

  return (
    <video
      ref={ref}
      autoPlay
      playsInline
      muted
      style={{
        width: '100%',
        height: '100%',
        objectFit: 'cover',
        borderRadius: 24,
        backgroundColor: '#0f1c2d',
      }}
    />
  );
}