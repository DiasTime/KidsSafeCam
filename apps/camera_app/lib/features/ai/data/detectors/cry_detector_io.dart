import 'dart:async';
import 'dart:typed_data';

import 'package:ai_baby_monitor_shared/ai_baby_monitor_shared.dart';
import 'package:record/record.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../../domain/ai_detector.dart';

AiDetector? createCryDetector({double threshold = 0.4}) =>
    YamnetCryDetector(threshold: threshold);

/// On-device cry detection with YAMNet (TFLite).
///
/// Streams 16 kHz mono PCM16 from the mic, runs YAMNet over ~0.975 s windows,
/// and emits a [BabyEventType.babyCry] detection when the "Baby cry, infant
/// cry" AudioSet class (index 20) stays above [threshold] across a couple of
/// consecutive windows (to ignore one-off spikes). The window/IO tensor shapes
/// are read from the model so it works with either the raw TF-Hub YAMNet or the
/// metadata variant.
class YamnetCryDetector implements AiDetector {
  YamnetCryDetector({this.threshold = 0.4, AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();

  static const _modelAsset = 'assets/models/yamnet.tflite';
  static const _babyCryClassIndex = 20; // "Baby cry, infant cry"
  static const _sampleRate = 16000;
  static const _requiredConsecutive = 2;

  final double threshold;
  final AudioRecorder _recorder;

  Interpreter? _interpreter;
  StreamSubscription<Uint8List>? _audioSub;
  final _controller = StreamController<AiDetection>.broadcast();
  final _samples = <double>[];

  List<int> _inputShape = const [15600];
  int _windowSamples = 15600;
  List<int> _outputShape = const [1, 521];
  int _consecutiveHits = 0;

  @override
  String get name => 'cry';

  @override
  Stream<AiDetection> get detections => _controller.stream;

  @override
  Future<void> start() async {
    final interpreter = _interpreter ??= await Interpreter.fromAsset(
      _modelAsset,
    );
    _inputShape = interpreter.getInputTensor(0).shape;
    _windowSamples = _inputShape.fold(1, (a, b) => a * b);
    _outputShape = interpreter.getOutputTensor(0).shape;

    if (!await _recorder.hasPermission()) return;
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _sampleRate,
        numChannels: 1,
      ),
    );
    _audioSub = stream.listen(_onAudio);
  }

  void _onAudio(Uint8List bytes) {
    final pcm = bytes.buffer.asInt16List(
      bytes.offsetInBytes,
      bytes.lengthInBytes ~/ 2,
    );
    for (final s in pcm) {
      _samples.add(s / 32768.0);
    }
    while (_samples.length >= _windowSamples) {
      final window = Float32List.fromList(_samples.sublist(0, _windowSamples));
      _samples.removeRange(0, _windowSamples);
      _classify(window);
    }
  }

  void _classify(Float32List window) {
    final interpreter = _interpreter;
    if (interpreter == null) return;
    double cry;
    try {
      final input = window.reshape(_inputShape);
      final output = List.filled(
        _outputShape.fold(1, (a, b) => a * b),
        0.0,
      ).reshape(_outputShape);
      interpreter.run(input, output);
      cry = _maxCryScore(output);
    } catch (_) {
      return;
    }

    if (cry >= threshold) {
      if (++_consecutiveHits >= _requiredConsecutive) {
        _consecutiveHits = 0;
        _controller.add(
          AiDetection(
            type: BabyEventType.babyCry,
            confidence: cry,
            metadata: {'class': 'baby_cry'},
          ),
        );
      }
    } else {
      _consecutiveHits = 0;
    }
  }

  /// Reads the baby-cry score across however many frames the model emits
  /// (output is [frames, classes] or [classes]); takes the strongest frame.
  double _maxCryScore(Object output) {
    var best = 0.0;
    void scan(List<dynamic> row) {
      if (_babyCryClassIndex < row.length) {
        final v = (row[_babyCryClassIndex] as num).toDouble();
        if (v > best) best = v;
      }
    }

    if (output is List && output.isNotEmpty && output.first is List) {
      for (final frame in output) {
        scan((frame as List).cast<dynamic>());
      }
    } else if (output is List) {
      scan(output.cast<dynamic>());
    }
    return best;
  }

  @override
  Future<void> stop() async {
    await _audioSub?.cancel();
    _audioSub = null;
    try {
      await _recorder.stop();
    } catch (_) {}
    _samples.clear();
    _consecutiveHits = 0;
  }

  @override
  Future<void> dispose() async {
    await stop();
    _interpreter?.close();
    _interpreter = null;
    await _controller.close();
    await _recorder.dispose();
  }
}
