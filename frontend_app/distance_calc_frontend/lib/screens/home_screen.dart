import 'dart:typed_data';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';

import '../main.dart';
import '../services/mlkit_detector.dart';
import '../widgets/bounding_box_painter.dart';
import '../widgets/camera_preview_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final MLKitDetector _detector = MLKitDetector();

  CameraController? _controller;
  List<RearObstacleDetection> _detections = const [];

  bool _isCameraReady = false;
  bool _isProcessing = false;
  bool _isInitializing = false;
  bool _isDetectorReady = false;

  int _selectedCameraIndex = 0;
  Size _frameSize = Size.zero;
  String? _errorMessage;
  DateTime? _lastAlertAt;
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
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_availableCameras.isEmpty) {
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _disposeCameraController();
    } else if (state == AppLifecycleState.resumed && !_isCameraReady) {
      _initializeCamera();
    }
  }

  Future<void> _bootstrap() async {
    try {
      await _detector.init();
      _isDetectorReady = true;
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = 'ML detector failed to initialize: $error';
        });
      }
      return;
    }

    if (_availableCameras.isEmpty) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'No cameras were found on this device. Connect a camera and retry.';
        });
      }
      return;
    }

    _selectedCameraIndex = _findDefaultCameraIndex();
    await _initializeCamera();
  }

  int _findDefaultCameraIndex() {
    final backIndex = _availableCameras.indexWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
    );

    return backIndex >= 0 ? backIndex : 0;
  }

  Future<void> _initializeCamera() async {
    if (_isInitializing || !_isDetectorReady || _availableCameras.isEmpty) {
      return;
    }

    final activeCamera = _activeCamera;
    if (activeCamera == null) {
      return;
    }

    _isInitializing = true;
    _errorMessage = null;
    await _disposeCameraController();

    final controller = CameraController(
      activeCamera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    try {
      await controller.initialize();
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

  Future<void> _disposeCameraController() async {
    final controller = _controller;
    _controller = null;

    if (controller == null) {
      return;
    }

    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
    } catch (_) {
      // The stream may already be stopped during lifecycle changes.
    }

    await controller.dispose();

    if (mounted) {
      setState(() {
        _isCameraReady = false;
      });
    }
  }

  Future<void> _switchCamera() async {
    if (_availableCameras.length < 2 || _isInitializing) {
      return;
    }

    setState(() {
      _selectedCameraIndex =
          (_selectedCameraIndex + 1) % _availableCameras.length;
    });

    await _initializeCamera();
  }

  Future<void> _processFrame(CameraImage image) async {
    if (_isProcessing || !_isCameraReady) {
      return;
    }

    _isProcessing = true;

    try {
      final inputImage = _convert(image);
      final frameSize = Size(image.height.toDouble(), image.width.toDouble());
      final results = await _detector.process(inputImage, frameSize);

      if (!mounted) {
        return;
      }

      setState(() {
        _detections = results;
        _frameSize = frameSize;
      });

      _handleHazardAlert(results.isNotEmpty ? results.first : null);
    } catch (error) {
      debugPrint('[Detection Error] $error');
    } finally {
      _isProcessing = false;
    }
  }

  void _handleHazardAlert(RearObstacleDetection? nearestDetection) {
    if (nearestDetection == null || !nearestDetection.isHazard) {
      return;
    }

    final now = DateTime.now();
    final canAlert =
        _lastAlertAt == null ||
        now.difference(_lastAlertAt!) >= const Duration(seconds: 2);

    if (!canAlert) {
      return;
    }

    _lastAlertAt = now;
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.mediumImpact();
  }

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
      output.setRange(
        outputOffset,
        outputOffset + width,
        yPlane.bytes,
        rowStart,
      );
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

  RearObstacleDetection? get _nearestDetection {
    if (_detections.isEmpty) {
      return null;
    }

    return _detections.first;
  }

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

  Future<void> _captureCalibrationTarget() async {
    final target = _nearestDetection;

    if (target == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No detected object is available to calibrate.')),
      );
      return;
    }

    setState(() {
      _calibrationTarget = target;
    });

    await _showCalibrationDialog(target);
  }

  Future<void> _showCalibrationDialog(RearObstacleDetection target) async {
    final widthController = TextEditingController();
    final distanceController = TextEditingController();
    String? errorText;

    final scaffoldMessenger = ScaffoldMessenger.of(context);

    void saveCalibration(BuildContext dialogContext, void Function(void Function()) setDialogState) {
      final widthCm = double.tryParse(widthController.text.trim());
      final distanceMeters = double.tryParse(distanceController.text.trim());

      if (widthCm == null || widthCm <= 0 || distanceMeters == null || distanceMeters <= 0) {
        setDialogState(() {
          errorText = 'Enter valid width in cm and distance in meters.';
        });
        return;
      }
      final objectWidthMeters = widthCm / 100.0;
      final focalLengthPx = (target.boundingBox.width * objectWidthMeters) / distanceMeters;

      _detector.setFocalLength(focalLengthPx);

      Navigator.of(dialogContext).pop();
 
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            'Calibration saved. Focal length set to ${focalLengthPx.toStringAsFixed(1)} px.',
          ),
        ),
      );

      if (mounted) {
        _cancelCalibrationMode();
      }
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, void Function(void Function()) setDialogState) {
            return AlertDialog(
              title: const Text('Calibrate object'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Captured box width: ${target.boundingBox.width.toStringAsFixed(1)} px',
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: widthController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Object width (cm)',
                        hintText: 'e.g. 20',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: distanceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Distance from camera (m)',
                        hintText: 'e.g. 2.5',
                      ),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        errorText!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => saveCalibration(dialogContext, setDialogState),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    // Dispose AFTER the dialog future completes, not before
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

  Widget _buildLoadingState() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Starting rear obstacle detector...',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.videocam_off, size: 64, color: Colors.white70),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, height: 1.4),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _errorMessage = null;
                      _isCameraReady = false;
                      _detections = const [];
                    });
                    _bootstrap();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final nearest = _nearestDetection;
    final dangerColor = nearest?.isHazard == true
        ? Colors.redAccent
        : Colors.greenAccent;

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
              nearest == null
                  ? 'IDLE'
                  : nearest.isHazard
                  ? 'DANGER'
                  : 'SAFE',
              style: TextStyle(
                color: dangerColor,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            onSelected: (String value) {
              if (value == 'camera_flip' && _availableCameras.length > 1) {
                _switchCamera();
              } else if (value == 'calibration') {
                _enterCalibrationMode();
              }
            },
            itemBuilder: (BuildContext context) => [
              if (_availableCameras.length > 1)
                const PopupMenuItem<String>(
                  value: 'camera_flip',
                  child: Row(
                    children: [
                      Icon(Icons.cameraswitch, size: 20),
                      SizedBox(width: 12),
                      Text('Flip Camera'),
                    ],
                  ),
                ),
              const PopupMenuItem<String>(
                value: 'calibration',
                child: Row(
                  children: [
                    Icon(Icons.tune, size: 20),
                    SizedBox(width: 12),
                    Text('Calibration'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel() {
    final nearest = _nearestDetection;
    final distanceText = nearest == null
        ? '--'
        : '${nearest.estimatedDistanceMeters.toStringAsFixed(1)} m';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Nearest distance',
                  value: distanceText,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricTile(
                  label: 'Objects tracked',
                  value: '${_detections.length}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return _buildErrorState(_errorMessage!);
    }

    if (!_isCameraReady || _controller == null) {
      return _buildLoadingState();
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
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
