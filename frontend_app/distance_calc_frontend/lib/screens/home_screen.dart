import 'dart:typed_data';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';

import '../main.dart';
import '../services/mlkit_detector.dart';
import '../widgets/camera_preview_widget.dart';

/// The main dashboard screen. It manages the camera stream, coordinates 
/// with the ML detector, and handles user interactions like calibration.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  // The service that handles AI object detection
  final MLKitDetector _detector = MLKitDetector();

  CameraController? _controller;
  List<RearObstacleDetection> _detections = const [];

  // Status flags
  bool _isCameraReady = false;
  bool _isProcessing = false;     // Prevents overlapping frames from being processed
  bool _isInitializing = false;
  bool _isDetectorReady = false;

  int _selectedCameraIndex = 0;
  Size _frameSize = Size.zero;
  String? _errorMessage;
  DateTime? _lastAlertAt;         // Used to throttle the sound alerts
  bool _isCalibrationMode = false;
  RearObstacleDetection? _calibrationTarget;

  List<CameraDescription> get _availableCameras => cameras;

  CameraDescription? get _activeCamera {
    if (_availableCameras.isEmpty ||
        _selectedCameraIndex < 0 ||
        _selectedCameraIndex >= _availableCameras.length) {
      return null;
    }
    return _availableCameras[_selectedCameraIndex];
  }

  bool get _isFrontCamera =>
      _activeCamera?.lensDirection == CameraLensDirection.front;

  @override
  void initState() {
    super.initState();
    // Start observing app lifecycle (e.g. to stop camera when app is minimized)
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_availableCameras.isEmpty) return;

    // Handle backgrounding/foregrounding to save battery and camera resources
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _disposeCameraController();
    } else if (state == AppLifecycleState.resumed && !_isCameraReady) {
      _initializeCamera();
    }
  }

  /// Initial setup: Initialize the AI detector and the camera.
  Future<void> _bootstrap() async {
    try {
      await _detector.init();
      _isDetectorReady = true;
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = 'ML detector failed: $error');
      }
      return;
    }

    if (_availableCameras.isEmpty) {
      if (mounted) {
        setState(() => _errorMessage = 'No cameras found on this device.');
      }
      return;
    }

    _selectedCameraIndex = _findDefaultCameraIndex();
    await _initializeCamera();
  }

  /// Prefers the back camera if available.
  int _findDefaultCameraIndex() {
    final backIndex = _availableCameras.indexWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
    );
    return backIndex >= 0 ? backIndex : 0;
  }

  /// Configures and starts the camera stream.
  Future<void> _initializeCamera() async {
    if (_isInitializing || !_isDetectorReady || _availableCameras.isEmpty) {
      return;
    }

    final activeCamera = _activeCamera;
    if (activeCamera == null) return;

    _isInitializing = true;
    _errorMessage = null;
    await _disposeCameraController();

    final controller = CameraController(
      activeCamera,
      ResolutionPreset.medium, // Balance between performance and accuracy
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420, // Required for Android processing
    );

    try {
      await controller.initialize();
      // Start streaming frames to the _processFrame method
      await controller.startImageStream(_processFrame);

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _isCameraReady = true;
        _frameSize = Size(
          controller.value.previewSize?.height ?? 0,
          controller.value.previewSize?.width ?? 0,
        );
      });
    } catch (error) {
      await controller.dispose();
      if (mounted) {
        setState(() {
          _errorMessage = 'Unable to initialize camera: $error';
          _isCameraReady = false;
        });
      }
    } finally {
      _isInitializing = false;
    }
  }

  /// Safely stops and cleans up the camera.
  Future<void> _disposeCameraController() async {
    final controller = _controller;
    _controller = null;

    if (controller == null) return;

    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
    } catch (_) {}

    await controller.dispose();

    if (mounted) {
      setState(() => _isCameraReady = false);
    }
  }

  /// Toggles between front and back cameras.
  Future<void> _switchCamera() async {
    if (_availableCameras.length < 2 || _isInitializing) return;

    setState(() {
      _selectedCameraIndex = (_selectedCameraIndex + 1) % _availableCameras.length;
    });

    await _initializeCamera();
  }

  /// The core "loop" function called for every camera frame.
  Future<void> _processFrame(CameraImage image) async {
    // If already processing a frame, skip this one to avoid lag
    if (_isProcessing || !_isCameraReady) return;

    _isProcessing = true;

    try {
      final inputImage = _convert(image);
      final frameSize = Size(image.height.toDouble(), image.width.toDouble());
      
      // Pass the frame to the AI service
      final results = await _detector.process(inputImage, frameSize);

      if (!mounted) return;

      setState(() {
        _detections = results;
        _frameSize = frameSize;
      });

      // Check if the closest object is a hazard
      _handleHazardAlert(results.isNotEmpty ? results.first : null);
    } catch (error) {
      debugPrint('[Detection Error] $error');
    } finally {
      _isProcessing = false;
    }
  }

  /// Triggers sound and vibration if a hazard is detected, with throttling.
  void _handleHazardAlert(RearObstacleDetection? nearestDetection) {
    if (nearestDetection == null || !nearestDetection.isHazard) return;

    final now = DateTime.now();
    // Only alert every 2 seconds to avoid annoying the user
    final canAlert = _lastAlertAt == null ||
        now.difference(_lastAlertAt!) >= const Duration(seconds: 2);

    if (!canAlert) return;

    _lastAlertAt = now;
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.mediumImpact();
  }

  /// Converts camera stream format (YUV) to a format ML Kit understands (NV21/Bytes).
  InputImage _convert(CameraImage image) {
    final bytes = _convertYuv420ToNv21(image);
    final imageSize = Size(image.width.toDouble(), image.height.toDouble());

    final rotation =
        InputImageRotationValue.fromRawValue(
          _controller?.description.sensorOrientation ?? 0,
        ) ??
        InputImageRotation.rotation0deg;

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: imageSize,
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: image.width,
      ),
    );
  }

  /// Helper to convert raw YUV plane data to NV21 bytes for processing.
  Uint8List _convertYuv420ToNv21(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final output = Uint8List(width * height * 3 ~/ 2);
    var outputOffset = 0;

    for (var row = 0; row < height; row++) {
      final rowStart = row * yPlane.bytesPerRow;
      output.setRange(outputOffset, outputOffset + width, yPlane.bytes, rowStart);
      outputOffset += width;
    }

    final chromaHeight = height ~/ 2;
    final chromaWidth = width ~/ 2;
    final uPixelStride = uPlane.bytesPerPixel ?? 1;
    final vPixelStride = vPlane.bytesPerPixel ?? 1;

    for (var row = 0; row < chromaHeight; row++) {
      final uRowStart = row * uPlane.bytesPerRow;
      final vRowStart = row * vPlane.bytesPerRow;
      for (var col = 0; col < chromaWidth; col++) {
        final uIndex = uRowStart + col * uPixelStride;
        final vIndex = vRowStart + col * vPixelStride;
        output[outputOffset++] = vPlane.bytes[vIndex];
        output[outputOffset++] = uPlane.bytes[uIndex];
      }
    }
    return output;
  }

  RearObstacleDetection? get _nearestDetection =>
      _detections.isEmpty ? null : _detections.first;

  void _enterCalibrationMode() {
    setState(() {
      _isCalibrationMode = true;
      _calibrationTarget = null;
    });
  }

  void _cancelCalibrationMode() {
    setState(() {
      _isCalibrationMode = false;
      _calibrationTarget = null;
    });
  }

  /// Captures the currently detected object to start the calibration process.
  Future<void> _captureCalibrationTarget() async {
    final target = _nearestDetection;
    if (target == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No object detected to calibrate.')),
      );
      return;
    }

    setState(() => _calibrationTarget = target);
    await _showCalibrationDialog(target);
  }

  /// Logic to update the camera's Focal Length based on user input.
  Future<void> _showCalibrationDialog(RearObstacleDetection target) async {
    final widthController = TextEditingController();
    final distanceController = TextEditingController();
    String? errorText;
    final messenger = ScaffoldMessenger.of(context);

    void saveCalibration(BuildContext dialogContext, void Function(void Function()) setDialogState) {
      final widthCm = double.tryParse(widthController.text.trim());
      final distanceMeters = double.tryParse(distanceController.text.trim());

      if (widthCm == null || widthCm <= 0 || distanceMeters == null || distanceMeters <= 0) {
        setDialogState(() => errorText = 'Enter valid dimensions.');
        return;
      }
      
      // Calculate Focal Length: (Pixel Width * Distance) / Real Width
      final objectWidthMeters = widthCm / 100.0;
      final focalLengthPx = (target.boundingBox.width * distanceMeters) / objectWidthMeters;

      _detector.setFocalLength(focalLengthPx);
      Navigator.of(dialogContext).pop();
 
      messenger.showSnackBar(
        SnackBar(content: Text('Calibration saved: ${focalLengthPx.toStringAsFixed(1)} px')),
      );

      if (mounted) _cancelCalibrationMode();
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Calibrate Camera'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: widthController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Object width (cm)'),
                ),
                TextField(
                  controller: distanceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Distance from camera (m)'),
                ),
                if (errorText != null) 
                  Text(errorText!, style: const TextStyle(color: Colors.red)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
            FilledButton(onPressed: () => saveCalibration(dialogContext, setDialogState), child: const Text('Save')),
          ],
        ),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      widthController.dispose();
      distanceController.dispose();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeCameraController();
    _detector.dispose();
    super.dispose();
  }

  /// Top navigation bar with status indicator and menu.
  Widget _buildTopBar() {
    final nearest = _nearestDetection;
    final dangerColor = nearest?.isHazard == true ? Colors.redAccent : Colors.greenAccent;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: dangerColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: dangerColor.withOpacity(0.35)),
            ),
            child: Text(
              nearest == null ? 'IDLE' : (nearest.isHazard ? 'DANGER' : 'SAFE'),
              style: TextStyle(color: dangerColor, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            onSelected: (val) {
              if (val == 'flip') _switchCamera();
              if (val == 'calib') _enterCalibrationMode();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'flip', child: Text('Flip Camera')),
              const PopupMenuItem(value: 'calib', child: Text('Calibration')),
            ],
          ),
        ],
      ),
    );
  }

  /// Bottom panel showing the most important metrics.
  Widget _buildBottomPanel() {
    final nearest = _nearestDetection;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Expanded(child: _MetricTile(label: 'Distance', value: nearest == null ? '--' : '${nearest.estimatedDistanceMeters.toStringAsFixed(1)} m')),
          const SizedBox(width: 12),
          Expanded(child: _MetricTile(label: 'Tracked', value: '${_detections.length}')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Scaffold(backgroundColor: Colors.black, body: Center(child: Text(_errorMessage!)));
    }

    if (!_isCameraReady || _controller == null) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            CameraPreviewWidget(
              controller: _controller!,
              detections: _detections,
              frameSize: _frameSize,
              mirror: _isFrontCamera,
              isCalibrationMode: _isCalibrationMode,
              onCalibrate: _captureCalibrationTarget,
              onCancelCalibration: _cancelCalibrationMode,
            ),
            _buildBottomPanel(),
          ],
        ),
      ),
    );
  }
}

/// Simple reusable UI component for showing a metric (Distance/Count).
class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  const _MetricTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
