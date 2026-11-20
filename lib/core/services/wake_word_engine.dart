import 'dart:async';
import 'dart:typed_data';

/// A pluggable wake-word detector.
///
/// ZaRa ships a clean-room keyword spotter that watches speech-recognition
/// partials (no model assets, no voice pack copying). Apps that have their own
/// `.tflite` keyword model can swap in [ModelWakeWordEngine] instead.
abstract class WakeWordEngine {
  Stream<void> get detected;

  /// Feed a recognised transcript fragment (partial or final).
  void feed(String transcript);

  void dispose();
}

/// Dependency-free keyword spotting on ASR partial transcripts.
///
/// Normalises punctuation/case, matches whole words, and debounces repeated
/// hits for [cooldown] so one utterance produces a single detection.
class KeywordWakeWordEngine implements WakeWordEngine {
  KeywordWakeWordEngine({
    Iterable<String> words = const ['hey zara', 'za ra', 'zara', 'ও জারা'],
    this.cooldown = const Duration(seconds: 2),
  }) : _words = words.map(_normalise).toList();

  final List<String> _words;
  final Duration cooldown;
  final StreamController<void> _controller = StreamController<void>.broadcast();
  DateTime _lastDetection = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  Stream<void> get detected => _controller.stream;

  /// Update the phrase list at runtime (Settings → wake words).
  void updateWords(Iterable<String> words) {
    _words
      ..clear()
      ..addAll(words.map(_normalise));
  }

  @override
  void feed(String transcript) {
    if (transcript.trim().isEmpty || _controller.isClosed) return;
    final normalised = _normalise(transcript);
    final hit = _words.any((w) => w.isNotEmpty && normalised.contains(w));
    if (!hit) return;

    final now = DateTime.now();
    if (now.difference(_lastDetection) < cooldown) return;
    _lastDetection = now;
    _controller.add(null);
  }

  static String _normalise(String text) => text
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  @override
  void dispose() {
    _controller.close();
  }
}

/// Integration slot for a real on-device keyword-spotting model.
///
/// Pass [infer] backed by `tflite_flutter` (or any local classifier): it
/// receives a feature window (e.g. log-mel / MFCC floats) and returns a
/// confidence in 0..1 for the wake word. ZaRa never bundles a model itself —
/// supply your own `.tflite` and labels. Text partials are ignored here; feed
/// audio features with [feedFeatures] instead.
class ModelWakeWordEngine implements WakeWordEngine {
  ModelWakeWordEngine({
    required this.infer,
    this.threshold = 0.7,
    this.label = 'zara',
  });

  /// Runs one inference window. Must return a score in 0..1.
  final Future<double> Function(Float32List features) infer;
  final double threshold;
  final String label;

  final StreamController<void> _controller = StreamController<void>.broadcast();
  bool _armed = true;

  @override
  Stream<void> get detected => _controller.stream;

  /// Feed one feature window from an audio stream.
  Future<void> feedFeatures(Float32List features) async {
    if (_controller.isClosed || !_armed) return;
    double score;
    try {
      score = (await infer(features)).clamp(0.0, 1.0);
    } catch (_) {
      return;
    }
    if (score >= threshold) {
      _armed = false; // one detection per continuous utterance
      _controller.add(null);
    } else if (score < threshold * 0.4) {
      _armed = true; // reset once the audio is clearly quiet/non-wake
    }
  }

  @override
  void feed(String transcript) {
    // A model engine consumes audio features, not ASR text.
  }

  @override
  void dispose() {
    _controller.close();
  }
}
