import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:typed_data';
import 'dart:ui';
import 'dart:typed_data';

import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';

import '../main.dart';
import '../widgets/camera_preview_widget.dart';
import '../widgets/bounding_box_painter.dart';
import '../services/mlkit_detector.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver {
  CameraController? controller;

  final MLKitDetector _detector = MLKitDetector();

  List<Detection> _detections = [];

  bool _isCameraReady = false;
  bool _isProcessing = false;
  bool _isInitializing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _initMLKit();
    _initCamera();
  }

  // ───────────────────────── ML KIT ─────────────────────────

  Future<void> _initMLKit() async {
    await _detector.init();
    debugPrint('[MLKit] Ready');
  }

  // ───────────────────────── CAMERA ─────────────────────────

  Future<void> _initCamera() async {
    if (_isInitializing) return;
    _isInitializing = true;

    final cam = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    controller = CameraController(
      cam,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    try {
      await controller!.initialize();

      if (!mounted) return;

      await controller!.startImageStream(_processFrame);

      setState(() {
        _isCameraReady = true;
      });
    } catch (e) {
      debugPrint('[Camera Error] $e');
    }

    _isInitializing = false;
  }

  // ───────────────────────── FRAME PROCESSING ─────────────────────────

  Future<void> _processFrame(CameraImage image) async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final inputImage = _convert(image);
      final results = await _detector.process(inputImage);

      if (mounted) {
        setState(() {
          _detections = results;
        });
      }
    } catch (e) {
      debugPrint('[Detection Error] $e');
    }

    _isProcessing = false;
  }

  // ───────────────────────── SAFE CONVERSION ─────────────────────────

  InputImage _convert(CameraImage image) {
    final WriteBuffer allBytes = WriteBuffer();

    for (final plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }

    final bytes = allBytes.done().buffer.asUint8List();

    final Size imageSize =
        Size(image.width.toDouble(), image.height.toDouble());

    final rotation = InputImageRotationValue.fromRawValue(
          controller!.description.sensorOrientation,
        ) ??
        InputImageRotation.rotation0deg;

    final format =
        InputImageFormatValue.fromRawValue(image.format.raw) ??
        InputImageFormat.nv21;

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: imageSize,
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  // ───────────────────────── LIFECYCLE ─────────────────────────

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller?.dispose();
    _detector.dispose();
    super.dispose();
  }

  // ───────────────────────── UI ─────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!_isCameraReady || controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: CameraPreviewWidget(controller: controller!),
          ),

          Positioned.fill(
            child: CustomPaint(
              painter: BoundingBoxPainter(_detections),
            ),
          ),
        ],
      ),
    );
  }
}