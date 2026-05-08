import 'dart:async';
import 'dart:isolate';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class DepthEstimator {
  DepthEstimator({
    this.modelAssetPath = 'assets/models/midas_small.tflite',
    this.inputSize = 256,
    this.interpreterThreads = 2,
  });

  final String modelAssetPath;
  final int inputSize;
  final int interpreterThreads;

  _DepthWorkerHandle? _worker;
  bool _useDepth = true;
  bool _initialized = false;
  Size? _lastSourceSize;
  List<List<double>>? _lastDepthMap;

  bool get isReady => _initialized && _useDepth && _worker != null;

  bool get useDepth => _useDepth;

  List<List<double>>? get lastDepthMap => _lastDepthMap;

  Future<bool> initialize() async {
    if (isReady) {
      return true;
    }

    try {
      final modelData = await rootBundle.load(modelAssetPath);
      final modelBytes = modelData.buffer.asUint8List(
        modelData.offsetInBytes,
        modelData.lengthInBytes,
      );
      _worker = await _DepthWorkerHandle.spawn(
        modelBytes,
        inputSize: inputSize,
        threads: interpreterThreads,
      );
      _initialized = true;
      _useDepth = true;
      return true;
    } catch (error) {
      debugPrint('DepthEstimator init failed: $error');
      _initialized = false;
      _useDepth = false;
      return false;
    }
  }

  Future<List<List<double>>> estimateDepth(CameraImage image) async {
    if (!isReady) {
      final initialized = await initialize();
      if (!initialized || !isReady) {
        return _lastDepthMap ?? const <List<double>>[];
      }
    }

    _lastSourceSize = Size(image.width.toDouble(), image.height.toDouble());

    try {
      final response = await _worker!.predict(_serializeCameraImage(image));
      final values = (response['values'] as List).cast<num>().map((value) => value.toDouble()).toList(growable: false);
      final width = response['width'] as int? ?? inputSize;
      final height = response['height'] as int? ?? inputSize;
      final depthMap = _buildDepthMap(values, width, height);
      _lastDepthMap = depthMap;
      return depthMap;
    } catch (error) {
      debugPrint('DepthEstimator inference failed: $error');
      _useDepth = false;
      return _lastDepthMap ?? const <List<double>>[];
    }
  }

  double getDepthAtPoint(int cx, int cy, List<List<double>> depthMap) {
    if (depthMap.isEmpty || depthMap.first.isEmpty) {
      return 0.0;
    }

    final sourceSize = _lastSourceSize;
    final sourceWidth = sourceSize?.width ?? depthMap.first.length.toDouble();
    final sourceHeight = sourceSize?.height ?? depthMap.length.toDouble();
    if (sourceWidth <= 0 || sourceHeight <= 0) {
      return 0.0;
    }

    final depthHeight = depthMap.length;
    final depthWidth = depthMap.first.length;
    final mappedX = ((cx.clamp(0, sourceWidth.round()) / sourceWidth) * (depthWidth - 1)).round();
    final mappedY = ((cy.clamp(0, sourceHeight.round()) / sourceHeight) * (depthHeight - 1)).round();
    final x = mappedX.clamp(0, depthWidth - 1);
    final y = mappedY.clamp(0, depthHeight - 1);

    double sum = 0.0;
    int count = 0;
    for (var offsetY = -1; offsetY <= 1; offsetY++) {
      for (var offsetX = -1; offsetX <= 1; offsetX++) {
        final sampleY = (y + offsetY).clamp(0, depthHeight - 1);
        final sampleX = (x + offsetX).clamp(0, depthWidth - 1);
        final sample = depthMap[sampleY][sampleX];
        if (sample.isFinite) {
          sum += sample;
          count++;
        }
      }
    }

    if (count == 0) {
      return 0.0;
    }

    return sum / count;
  }

  void dispose() {
    _worker?.close();
    _worker = null;
    _initialized = false;
    _useDepth = false;
  }

  Map<String, dynamic> _serializeCameraImage(CameraImage image) {
    return <String, dynamic>{
      'width': image.width,
      'height': image.height,
      'format': image.format.group.index,
      'planes': image.planes
          .map(
            (plane) => <String, dynamic>{
              'bytes': plane.bytes,
              'bytesPerRow': plane.bytesPerRow,
              'bytesPerPixel': plane.bytesPerPixel,
            },
          )
          .toList(growable: false),
    };
  }

  List<List<double>> _buildDepthMap(List<double> values, int width, int height) {
    if (values.isEmpty || width <= 0 || height <= 0) {
      return const <List<double>>[];
    }

    final expectedLength = width * height;
    final clampedLength = values.length < expectedLength ? values.length : expectedLength;
    final depthMap = List<List<double>>.generate(
      height,
      (_) => List<double>.filled(width, 0.0, growable: false),
      growable: false,
    );

    for (var index = 0; index < clampedLength; index++) {
      final row = index ~/ width;
      final column = index % width;
      depthMap[row][column] = values[index];
    }

    return depthMap;
  }
}

class _DepthWorkerHandle {
  _DepthWorkerHandle._(
    this._responsePort,
    this._isolate,
  );

  final ReceivePort _responsePort;
  final Isolate _isolate;
  final Completer<SendPort> _readyCompleter = Completer<SendPort>();
  final Map<int, Completer<Map<String, dynamic>>> _pending = <int, Completer<Map<String, dynamic>>>{};
  SendPort? _commandPort;
  int _requestCounter = 0;

  static Future<_DepthWorkerHandle> spawn(
    Uint8List modelBytes, {
    required int inputSize,
    required int threads,
  }) async {
    final responsePort = ReceivePort();
    final isolate = await Isolate.spawn(
      _depthWorkerMain,
      <dynamic>[
        responsePort.sendPort,
        modelBytes,
        inputSize,
        threads,
      ],
      debugName: 'midas-depth-worker',
    );

    final handle = _DepthWorkerHandle._(responsePort, isolate);
    responsePort.listen(handle._handleMessage);

    final commandPort = await handle._readyCompleter.future.timeout(const Duration(seconds: 10));
    handle._commandPort = commandPort;
    return handle;
  }

  Future<Map<String, dynamic>> predict(Map<String, dynamic> imagePayload) {
    final commandPort = _commandPort;
    if (commandPort == null) {
      return Future<Map<String, dynamic>>.error(StateError('Depth worker is not ready.'));
    }

    final requestId = _requestCounter++;
    final completer = Completer<Map<String, dynamic>>();
    _pending[requestId] = completer;

    commandPort.send(<String, dynamic>{
      'requestId': requestId,
      'replyTo': _responsePort.sendPort,
      'image': imagePayload,
    });

    return completer.future;
  }

  void close() {
    _isolate.kill(priority: Isolate.immediate);
    _responsePort.close();
  }

  void _handleMessage(dynamic message) {
    if (message is SendPort) {
      if (!_readyCompleter.isCompleted) {
        _readyCompleter.complete(message);
      }
      return;
    }

    if (message is Map) {
      final startupError = message['startupError'];
      if (startupError != null && !_readyCompleter.isCompleted) {
        _readyCompleter.completeError(StateError(startupError.toString()));
        return;
      }

      final requestId = message['requestId'];
      if (requestId is int) {
        final completer = _pending.remove(requestId);
        if (completer == null || completer.isCompleted) {
          return;
        }

        final error = message['error'];
        if (error != null) {
          completer.completeError(StateError(error.toString()));
          return;
        }

        final result = message['result'];
        if (result is Map) {
          completer.complete(result.cast<String, dynamic>());
          return;
        }

        completer.completeError(StateError('Depth worker returned an invalid payload.'));
      }
    }
  }
}

void _depthWorkerMain(List<dynamic> args) async {
  final SendPort responseSendPort = args[0] as SendPort;
  final Uint8List modelBytes = args[1] as Uint8List;
  final int inputSize = args[2] as int;
  final int threads = args[3] as int;

  Interpreter? interpreter;
  ReceivePort? commandPort;

  try {
    final options = InterpreterOptions()..threads = threads;
    interpreter = Interpreter.fromBuffer(modelBytes, options: options);
    interpreter.allocateTensors();

    final localCommandPort = ReceivePort();
    commandPort = localCommandPort;
    responseSendPort.send(localCommandPort.sendPort);

    await for (final dynamic message in localCommandPort) {
      if (message is Map && message['type'] == 'close') {
        break;
      }

      if (message is! Map) {
        continue;
      }

      final requestId = message['requestId'];
      final imagePayload = message['image'];
      if (requestId is! int || imagePayload is! Map) {
        continue;
      }

      final replyTo = message['replyTo'] as SendPort? ?? responseSendPort;
      try {
        final result = _runInference(
          interpreter,
          imagePayload.cast<String, dynamic>(),
          inputSize,
        );
        replyTo.send(<String, dynamic>{
          'requestId': requestId,
          'result': result,
        });
      } catch (error) {
        replyTo.send(<String, dynamic>{
          'requestId': requestId,
          'error': error.toString(),
        });
      }
    }
  } catch (error) {
    responseSendPort.send(<String, dynamic>{
      'startupError': error.toString(),
    });
  } finally {
    commandPort?.close();
    interpreter?.close();
  }
}

Map<String, dynamic> _runInference(
  Interpreter interpreter,
  Map<String, dynamic> imagePayload,
  int inputSize,
) {
  final width = imagePayload['width'] as int;
  final height = imagePayload['height'] as int;
  final formatRaw = imagePayload['format'] as int;
  final planes = (imagePayload['planes'] as List).cast<Map>();
  final inputBuffer = Float32List(inputSize * inputSize * 3);

  var bufferIndex = 0;
  for (var y = 0; y < inputSize; y++) {
    final sourceY = ((y / (inputSize - 1)) * (height - 1)).round();
    for (var x = 0; x < inputSize; x++) {
      final sourceX = ((x / (inputSize - 1)) * (width - 1)).round();
      final rgb = _readPixel(
        width: width,
        height: height,
        formatRaw: formatRaw,
        planes: planes,
        x: sourceX,
        y: sourceY,
      );
      inputBuffer[bufferIndex++] = rgb.red / 255.0;
      inputBuffer[bufferIndex++] = rgb.green / 255.0;
      inputBuffer[bufferIndex++] = rgb.blue / 255.0;
    }
  }

  final outputShape = interpreter.getOutputTensor(0).shape;
  final outputBuffer = _createBufferForShape(outputShape);
  interpreter.run(inputBuffer, outputBuffer);

  final flattened = <double>[];
  _flattenValues(outputBuffer, flattened);
  return <String, dynamic>{
    'width': inputSize,
    'height': inputSize,
    'values': flattened,
  };
}

dynamic _createBufferForShape(List<int> shape) {
  if (shape.isEmpty) {
    return 0.0;
  }

  if (shape.length == 1) {
    return List<double>.filled(shape.first, 0.0, growable: false);
  }

  return List.generate(
    shape.first,
    (_) => _createBufferForShape(shape.sublist(1)),
    growable: false,
  );
}

void _flattenValues(dynamic value, List<double> target) {
  if (value is num) {
    target.add(value.toDouble());
    return;
  }

  if (value is List) {
    for (final item in value) {
      _flattenValues(item, target);
    }
  }
}

_ArgbColor _readPixel({
  required int width,
  required int height,
  required int formatRaw,
  required List<Map> planes,
  required int x,
  required int y,
}) {
  if (formatRaw == ImageFormatGroup.bgra8888.index) {
    final plane = planes.first;
    final bytes = plane['bytes'] as Uint8List;
    final bytesPerRow = plane['bytesPerRow'] as int;
    final bytesPerPixel = (plane['bytesPerPixel'] as int?) ?? 4;
    final index = y * bytesPerRow + x * bytesPerPixel;
    if (index + 2 >= bytes.length) {
      return const _ArgbColor(red: 0, green: 0, blue: 0);
    }

    final blue = bytes[index];
    final green = bytes[index + 1];
    final red = bytes[index + 2];
    return _ArgbColor(red: red.toDouble(), green: green.toDouble(), blue: blue.toDouble());
  }

  if (planes.length < 3) {
    return const _ArgbColor(red: 0, green: 0, blue: 0);
  }

  final yPlane = planes[0];
  final uPlane = planes[1];
  final vPlane = planes[2];

  final yBytes = yPlane['bytes'] as Uint8List;
  final uBytes = uPlane['bytes'] as Uint8List;
  final vBytes = vPlane['bytes'] as Uint8List;

  final yBytesPerRow = yPlane['bytesPerRow'] as int;
  final uBytesPerRow = uPlane['bytesPerRow'] as int;
  final vBytesPerRow = vPlane['bytesPerRow'] as int;
  final yBytesPerPixel = (yPlane['bytesPerPixel'] as int?) ?? 1;
  final uBytesPerPixel = (uPlane['bytesPerPixel'] as int?) ?? 1;
  final vBytesPerPixel = (vPlane['bytesPerPixel'] as int?) ?? 1;

  final yIndex = y * yBytesPerRow + x * yBytesPerPixel;
  final uvX = x ~/ 2;
  final uvY = y ~/ 2;
  final uIndex = uvY * uBytesPerRow + uvX * uBytesPerPixel;
  final vIndex = uvY * vBytesPerRow + uvX * vBytesPerPixel;

  if (yIndex >= yBytes.length || uIndex >= uBytes.length || vIndex >= vBytes.length) {
    return const _ArgbColor(red: 0, green: 0, blue: 0);
  }

  final yValue = yBytes[yIndex].toDouble();
  final uValue = uBytes[uIndex].toDouble() - 128.0;
  final vValue = vBytes[vIndex].toDouble() - 128.0;

  final red = yValue + 1.402 * vValue;
  final green = yValue - 0.344136 * uValue - 0.714136 * vValue;
  final blue = yValue + 1.772 * uValue;

  return _ArgbColor(
    red: red.clamp(0.0, 255.0),
    green: green.clamp(0.0, 255.0),
    blue: blue.clamp(0.0, 255.0),
  );
}

class _ArgbColor {
  const _ArgbColor({
    required this.red,
    required this.green,
    required this.blue,
  });

  final double red;
  final double green;
  final double blue;
}
