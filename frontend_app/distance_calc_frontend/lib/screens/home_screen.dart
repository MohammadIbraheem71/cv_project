import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../widgets/camera_preview_widget.dart';

class HomeScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const HomeScreen({super.key, required this.cameras});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  CameraController? _controller;
  bool _isCameraReady = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    debugPrint('[HomeScreen] initState called');
    _initCamera();
  }

  Future<void> _initCamera() async {
    if (widget.cameras.isEmpty) {
      debugPrint('[HomeScreen] No cameras found on device');
      setState(() {
        _errorMessage = 'No cameras found on this device.';
      });
      return;
    }

    // Use the back camera by default
    final backCamera = widget.cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () {
        debugPrint('[HomeScreen] No back camera found, using first available');
        return widget.cameras.first;
      },
    );

    debugPrint('[HomeScreen] Initialising camera: ${backCamera.name}');

    _controller = CameraController(
      backCamera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await _controller!.initialize();
      debugPrint('[HomeScreen] Camera initialised successfully');
      if (mounted) {
        setState(() {
          _isCameraReady = true;
        });
      }
    } catch (e) {
      debugPrint('[HomeScreen] Camera init error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Camera error: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    debugPrint('[HomeScreen] dispose called — releasing camera');
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[HomeScreen] build called — isCameraReady: $_isCameraReady');

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview fills entire screen
          if (_isCameraReady && _controller != null)
            CameraPreviewWidget(controller: _controller!)
          else if (_errorMessage != null)
            _buildError()
          else
            _buildLoading(),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16),
          Text(
            'Starting camera...',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_alt_outlined, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Unknown error',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                debugPrint('[HomeScreen] Retry camera init tapped');
                setState(() {
                  _errorMessage = null;
                  _isCameraReady = false;
                });
                _initCamera();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}