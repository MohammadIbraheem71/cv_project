import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../main.dart' show cameras;
import '../widgets/camera_preview_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver {
  CameraController? controller;
  bool _isCameraReady = false;
  bool _isInitializing = false; // guard against re-entrant init
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    debugPrint('[HomeScreen] initState called');
    WidgetsBinding.instance.addObserver(this);
    initCamera();
  }

  // Handle app going to background / coming back
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('[HomeScreen] Lifecycle state changed: $state');

    if (state == AppLifecycleState.inactive) {
      // inactive fires constantly during normal use — ignore it
      return;
    }

    if (state == AppLifecycleState.paused) {
      debugPrint('[HomeScreen] App paused — disposing camera');
      _disposeCamera();
    } else if (state == AppLifecycleState.resumed) {
      debugPrint('[HomeScreen] App resumed — reinitialising camera');
      initCamera();
    }
  }

  Future<void> _disposeCamera() async {
    debugPrint('[HomeScreen] _disposeCamera called');
    final c = controller;
    controller = null;
    if (mounted) setState(() => _isCameraReady = false);
    try {
      if (c != null && c.value.isInitialized) {
        if (c.value.isStreamingImages) {
          await c.stopImageStream();
          debugPrint('[HomeScreen] Image stream stopped');
        }
        await c.dispose();
        debugPrint('[HomeScreen] Camera disposed');
      }
    } catch (e) {
      debugPrint('[HomeScreen] Error disposing camera: $e');
    }
  }

  Future<void> initCamera() async {
    // Prevent multiple simultaneous init calls
    if (_isInitializing) {
      debugPrint('[HomeScreen] initCamera — already initializing, skipping');
      return;
    }
    _isInitializing = true;
    debugPrint('[HomeScreen] initCamera called');

    if (cameras.isEmpty) {
      debugPrint('[HomeScreen] No cameras available');
      if (mounted) {
        setState(() {
          _errorMessage = 'No cameras found on this device.';
        });
      }
      _isInitializing = false;
      return;
    }

    // Use back camera
    final backCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () {
        debugPrint('[HomeScreen] No back camera — using last available');
        return cameras.last;
      },
    );

    debugPrint('[HomeScreen] Using camera: ${backCamera.name}');

    final newController = CameraController(
      backCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    try {
      await newController.initialize();
      debugPrint('[HomeScreen] Camera initialised — '
          'preview size: ${newController.value.previewSize}');

      if (!mounted) {
        await newController.dispose();
        _isInitializing = false;
        return;
      }

      // Start image stream for per-frame access
      await newController.startImageStream((CameraImage image) {
        // Frame available — detection will be wired here
        // Note: do NOT call setState or debugPrint here — runs every frame
      });

      debugPrint('[HomeScreen] Image stream started');

      setState(() {
        controller = newController;
        _isCameraReady = true;
        _errorMessage = null;
      });
    } catch (e) {
      debugPrint('[HomeScreen] Camera init error: $e');
      await newController.dispose();
      if (mounted) {
        setState(() {
          _errorMessage = 'Camera error: $e';
          _isCameraReady = false;
        });
      }
    }

    _isInitializing = false;
  }

  @override
  void dispose() {
    debugPrint('[HomeScreen] dispose — releasing camera');
    WidgetsBinding.instance.removeObserver(this);
    _disposeCamera();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[HomeScreen] build — isCameraReady: $_isCameraReady');

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Fullscreen camera ──
          if (_isCameraReady && controller != null)
            Positioned.fill(
              child: CameraPreviewWidget(controller: controller!),
            )
          else if (_errorMessage != null)
            _buildError()
          else
            _buildLoading(),

          // ── 3-dot menu (top right) ──
          if (_isCameraReady)
            Positioned(
              top: 48,
              right: 16,
              child: SafeArea(
                child: _MenuButton(
                  onCalibration: () {
                    debugPrint('[HomeScreen] Calibration tapped — coming soon');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Calibration coming soon'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ),
            ),
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
                debugPrint('[HomeScreen] Retry tapped');
                setState(() {
                  _errorMessage = null;
                  _isCameraReady = false;
                });
                initCamera();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 3-dot menu ────────────────────────────────────────────────────────────────
class _MenuButton extends StatelessWidget {
  final VoidCallback onCalibration;

  const _MenuButton({required this.onCalibration});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.55),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withOpacity(0.15),
          ),
        ),
        child: const Icon(
          Icons.more_vert,
          color: Colors.white,
          size: 22,
        ),
      ),
      color: const Color(0xFF0F1C2D),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (value) {
        debugPrint('[MenuButton] Selected: $value');
        if (value == 'calibration') {
          onCalibration();
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'calibration',
          child: Row(
            children: [
              Icon(Icons.tune, color: Colors.white70, size: 20),
              SizedBox(width: 12),
              Text(
                'Camera Calibration',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
  }
}