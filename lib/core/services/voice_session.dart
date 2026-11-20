import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_error.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart' as stt;
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../theme/persona.dart';
import 'language_policy.dart';
import 'wake_word_engine.dart';

/// Internal engine stages. AppState maps these to its public VoiceStatus.
enum VoiceStage { idle, listening, transcribing, speaking }

/// Tunable voice settings. Kept immutable so Settings can copy-with.
class VoiceConfig {
  final String localeId;
  final String ttsLanguage;
  final List<String> wakeWords;
  final double ttsRate;
  final double ttsPitch;

  const VoiceConfig({
    this.localeId = LanguagePolicy.localeId,
    this.ttsLanguage = LanguagePolicy.ttsLanguage,
    this.wakeWords = LanguagePolicy.wakeWords,
    this.ttsRate = 0.48,
    this.ttsPitch = 1.0,
  });

  VoiceConfig copyWith({
    String? localeId,
    String? ttsLanguage,
    List<String>? wakeWords,
    double? ttsRate,
    double? ttsPitch,
  }) {
    return VoiceConfig(
      localeId: localeId ?? this.localeId,
      ttsLanguage: ttsLanguage ?? this.ttsLanguage,
      wakeWords: wakeWords ?? this.wakeWords,
      ttsRate: ttsRate ?? this.ttsRate,
      ttsPitch: ttsPitch ?? this.ttsPitch,
    );
  }
}

/// Real voice I/O: microphone -> ASR -> streams, and TTS output.
///
/// Wake word is spotted by a pluggable [WakeWordEngine]: the default watches
/// ASR partial transcripts (fully clean-room), while a `.tflite`-backed engine
/// can be injected for audio-level keyword spotting.
class VoiceSession {
  VoiceSession({
    VoiceConfig config = const VoiceConfig(),
    WakeWordEngine? wakeEngine,
  })  : _config = config,
        _wakeEngine = wakeEngine ?? KeywordWakeWordEngine(words: config.wakeWords);

  VoiceConfig _config;
  final WakeWordEngine _wakeEngine;
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();

  final StreamController<String> _transcripts = StreamController<String>.broadcast();
  final StreamController<String> _partials = StreamController<String>.broadcast();
  final StreamController<VoiceStage> _stages = StreamController<VoiceStage>.broadcast();

  bool _ready = false;
  bool _listening = false;
  bool _speaking = false;

  Stream<String> get transcripts => _transcripts.stream;
  Stream<String> get partials => _partials.stream;
  Stream<void> get wakeDetected => _wakeEngine.detected;
  Stream<VoiceStage> get stages => _stages.stream;

  bool get isReady => _ready;
  bool get isListening => _listening;
  bool get isSpeaking => _speaking;
  VoiceConfig get config => _config;

  Future<bool> initialize() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) return false;

    _ready = await _speech.initialize(
      onStatus: _onStatus,
      onError: _onError,
      debugLogging: kDebugMode,
    );
    if (!_ready) return false;

    await _applyTtsSettings();
    _tts.setCompletionHandler(() {
      _speaking = false;
      _emit(VoiceStage.idle);
    });
    _tts.setErrorHandler((msg) {
      _speaking = false;
      _emit(VoiceStage.idle);
      debugPrint('ZaRa TTS error: $msg');
    });
    return true;
  }

  Future<void> _applyTtsSettings() async {
    await _tts.setLanguage(_config.ttsLanguage);
    await _tts.setSpeechRate(_config.ttsRate);
    await _tts.setPitch(_config.ttsPitch);
  }

  void updateConfig(VoiceConfig config) {
    _config = config;
    if (_wakeEngine is KeywordWakeWordEngine) {
      _wakeEngine.updateWords(config.wakeWords);
    }
    if (_ready) _applyTtsSettings();
  }

  Future<void> startListening() async {
    if (!_ready || _listening) return;
    _listening = true;
    _emit(VoiceStage.listening);
    await _speech.listen(
      onResult: _onResult,
      listenOptions: stt.SpeechListenOptions(
        localeId: _config.localeId,
        partialResults: true,
        cancelOnError: true,
        listenMode: stt.ListenMode.confirmation,
      ),
    );
  }

  Future<void> stopListening() async {
    if (!_listening) return;
    await _speech.stop();
    _listening = false;
    _emit(VoiceStage.transcribing);
  }

  Future<void> cancelListening() async {
    await _speech.cancel();
    _listening = false;
    _emit(VoiceStage.idle);
  }

  Future<void> speak(String text, {Persona? persona}) async {
    if (text.trim().isEmpty) return;
    // Re-apply the Bengali voice on every utterance so a persona/preset change
    // can never leave TTS on a non-Bengali voice.
    await _tts.setLanguage(LanguagePolicy.ttsLanguage);
    if (persona != null) {
      final rate = _config.ttsRate + (persona == Persona.nova ? 0.08 : 0.0);
      final pitch = _config.ttsPitch + (persona.dark ? -0.1 : 0.1);
      await _tts.setSpeechRate(rate);
      await _tts.setPitch(pitch);
    }
    _speaking = true;
    _emit(VoiceStage.speaking);
    await _tts.speak(text);
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
    _speaking = false;
  }

  void _onResult(stt.SpeechRecognitionResult result) {
    final text = result.recognizedWords.trim();
    if (text.isEmpty) return;

    _wakeEngine.feed(text);
    if (!result.finalResult) {
      _partials.add(text);
      return;
    }

    _partials.add(text);
    _transcripts.add(text);
    _emit(VoiceStage.transcribing);
  }

  void _onStatus(String status) {
    if (status == 'done' || status == 'doneNoAudio') {
      _listening = false;
      _emit(VoiceStage.transcribing);
    } else if (status == 'listening') {
      _listening = true;
      _emit(VoiceStage.listening);
    } else if (status == 'notListening' || status == 'canceled') {
      _listening = false;
      _emit(VoiceStage.idle);
    }
  }

  void _onError(stt.SpeechRecognitionError error) {
    _listening = false;
    _emit(VoiceStage.idle);
    debugPrint('ZaRa STT error: ${error.errorMsg}');
  }

  void _emit(VoiceStage stage) {
    if (!_stages.isClosed) _stages.add(stage);
  }

  void dispose() {
    _speech.stop();
    _tts.stop();
    _transcripts.close();
    _partials.close();
    _stages.close();
    _wakeEngine.dispose();
  }
}
