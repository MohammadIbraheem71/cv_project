import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'screens/home_screen.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fetch available cameras on the device
  try {
    cameras = await availableCameras();
    debugPrint('[main] Found ${cameras.length} camera(s)');
    for (int i = 0; i < cameras.length; i++) {
      debugPrint('[main] Camera $i: ${cameras[i].name} — ${cameras[i].lensDirection}');
    }
  } catch (e) {
    debugPrint('[main] Error fetching cameras: $e');
  }

  runApp(MyApp(cameras: cameras));
}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;

  const MyApp({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    debugPrint('[MyApp] Building app');
    return MaterialApp(
      title: 'Rear Obstacle Detector',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: HomeScreen(cameras: cameras),
    );
  }
}