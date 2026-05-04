import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';

class Detection {
  final double ymin, xmin, ymax, xmax;
  final double score;
  final int classIndex;

  Detection({
    required this.ymin,
    required this.xmin,
    required this.ymax,
    required this.xmax,
    required this.score,
    required this.classIndex,
  });
}

class ObjectDetector {
  late Interpreter _interpreter;
  bool _isLoaded = false;

  Future<void> loadModel() async {
    _interpreter = await Interpreter.fromAsset('detect.tflite');
    _isLoaded = true;
  }

  bool get isLoaded => _isLoaded;

  List<Detection> run(Uint8List input) {
    var outputBoxes = List.filled(1 * 10 * 4, 0.0).reshape([1, 10, 4]);
    var outputClasses = List.filled(1 * 10, 0.0).reshape([1, 10]);
    var outputScores = List.filled(1 * 10, 0.0).reshape([1, 10]);
    var numDetections = List.filled(1, 0.0);

    _interpreter.runForMultipleInputs(
      [input],
      {
        0: outputBoxes,
        1: outputClasses,
        2: outputScores,
        3: numDetections,
      },
    );

    List<Detection> detections = [];

    for (int i = 0; i < 10; i++) {
      double score = outputScores[0][i];
      if (score > 0.6) {
        detections.add(
          Detection(
            ymin: outputBoxes[0][i][0],
            xmin: outputBoxes[0][i][1],
            ymax: outputBoxes[0][i][2],
            xmax: outputBoxes[0][i][3],
            score: score,
            classIndex: outputClasses[0][i].toInt(),
          ),
        );
      }
    }

    return detections;
  }
}