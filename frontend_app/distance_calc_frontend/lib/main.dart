import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'screens/home_screen.dart';

late List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Fullscreen — hide status and nav bar
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  try {
    cameras = await availableCameras();
    debugPrint('[main] Found ${cameras.length} camera(s)');
    for (int i = 0; i < cameras.length; i++) {
      debugPrint('[main] Camera $i: ${cameras[i].name} — ${cameras[i].lensDirection}');
    }
  } catch (e) {
    debugPrint('[main] Error fetching cameras: $e');
    cameras = [];
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('[MyApp] Building app');
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Rear Obstacle Detector',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const HomeScreen(),
    );
  }
}