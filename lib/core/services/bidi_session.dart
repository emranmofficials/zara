import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../agent/tool_registry.dart';
import 'language_policy.dart';

/// Public BidiGenerateContent transport states. Names are generic and describe
/// observable stage changes, not any vendor-specific implementation.
enum BidiState {
  disconnected,
  connecting,
  ready,
  listening,
  thinking,
  speaking,
  error,
}

/// Configuration for one live conversational session.
class BidiConfig {
  final String model;
  final String systemInstruction;
  final int toolBudget;
  final String voiceName;
  final String languageCode;
  final bool automaticActivity;
  final String? resumeHandle;

  const BidiConfig({
    required this.model,
    required this.systemInstruction,
    this.toolBudget = 8,
    this.voiceName = 'bn-standard',
    this.languageCode = LanguagePolicy.ttsLanguage,
    this.automaticActivity = true,
    this.resumeHandle,
  });
}

/// A clean-room full-duplex session over the public BidiGenerateContent wire
/// protocol. It owns the socket, setup frame, outbound queue, transcript and
/// audio sinks, and a resumable session handle.
///
/// Audio capture itself stays in [VoiceSession]/a platform plugin; this class
/// accepts 16 kHz PCM base64 frames so the transport can be tested without a
/// microphone. No proprietary model id, voice pack or prompt is embedded.
class BidiSession {
  static const endpoint =
      'wss://generativelanguage.googleapis.com/ws/'
      'google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent';

  final String _key;
  final BidiConfig config;
  final WebSocketChannel? Function(Uri uri)? channelFactory;

  WebSocketChannel? _channel;
  String? _resumeHandle;
  bool _setupComplete = false;
  final List<Map<String, dynamic>> _outbox = <Map<String, dynamic>>[];

  final _states = StreamController<BidiState>.broadcast();
  final _transcripts = StreamController<String>.broadcast();
  final _audio = StreamController<String>.broadcast();
  final _toolCalls = StreamController<Map<String, dynamic>>.broadcast();

  BidiSession({
    required String key,
    required this.config,
    this.channelFactory,
  }) : _key = key {
    _resumeHandle = config.resumeHandle;
  }

  Stream<BidiState> get states => _states.stream;
  Stream<String> get transcripts => _transcripts.stream;
  Stream<String> get audioBase64 => _audio.stream;
  Stream<Map<String, dynamic>> get toolCalls => _toolCalls.stream;
  String? get resumeHandle => _resumeHandle;
  bool get isReady => _setupComplete;

  /// Pure builder: unit-testable without opening a socket.
  static Map<String, dynamic> buildSetup(BidiConfig config) {
    final setup = <String, dynamic>{
      'model': config.model,
      'generationConfig': <String, dynamic>{
        'responseModalities': <String>['AUDIO'],
      },
      'speechConfig': <String, dynamic>{
        'voiceConfig': <String, dynamic>{
          'prebuiltVoiceConfig': <String, dynamic>{
            'voiceName': config.voiceName,
          },
        },
        'languageCode': config.languageCode,
      },
      'inputAudioTranscription': <String, dynamic>{},
      'outputAudioTranscription': <String, dynamic>{},
      'realtimeInputConfig': config.automaticActivity
          ? <String, dynamic>{
              'automaticActivityDetection': <String, dynamic>{
                'disabled': false,
              },
              'activityHandling': 'START_OF_ACTIVITY_INTERRUPTS',
            }
          : <String, dynamic>{
              'automaticActivityDetection': <String, dynamic>{
                'disabled': true,
              },
              'activityHandling': 'START_OF_ACTIVITY_INTERRUPTS',
              'turnCoverage': 'TURN_INCLUDES_ONLY_ACTIVITY',
            },
      'systemInstruction': <String, dynamic>{
        'parts': <Map<String, dynamic>>[
          <String, dynamic>{'text': config.systemInstruction},
        ],
      },
    };

    final declarations = ToolRegistry.declarations(config.toolBudget);
    if (declarations.isNotEmpty) {
      setup['tools'] = <Map<String, dynamic>>[
        <String, dynamic>{'functionDeclarations': declarations},
      ];
    }
    if (config.resumeHandle != null && config.resumeHandle!.isNotEmpty) {
      setup['sessionResumption'] = <String, dynamic>{
        'handle': config.resumeHandle,
      };
    }
    return <String, dynamic>{'setup': setup};
  }

  Future<void> connect() async {
    if (_channel != null) return;
    _states.add(BidiState.connecting);
    final uri = Uri.parse(endpoint).replace(
      queryParameters: <String, String>{'key': _key},
    );
    try {
      final channel = channelFactory == null
          ? WebSocketChannel.connect(uri)
          : channelFactory!(uri);
      if (channel == null) throw StateError('channelFactory returned null');
      _channel = channel;
      channel.stream.listen(
        _onMessage,
        onError: (_) => _states.add(BidiState.error),
        onDone: _onDone,
      );
      _send(<String, dynamic>{'setup': buildSetup(config)['setup']});
    } catch (_) {
      _states.add(BidiState.error);
    }
  }

  void sendText(String text) {
    if (text.trim().isEmpty) return;
    _send(<String, dynamic>{
      'clientContent': <String, dynamic>{
        'turns': <Map<String, dynamic>>[
          <String, dynamic>{
            'role': 'user',
            'parts': <Map<String, dynamic>>[
              <String, dynamic>{'text': text},
            ],
          },
        ],
        'turnComplete': true,
      },
    });
    _states.add(BidiState.thinking);
  }

  void sendAudio(
    String base64Pcm, {
    String mimeType = 'audio/pcm;rate=16000',
  }) {
    if (base64Pcm.isEmpty) return;
    _send(<String, dynamic>{
      'realtimeInput': <String, dynamic>{
        'audio': <String, dynamic>{
          'data': base64Pcm,
          'mimeType': mimeType,
        },
      },
    });
    _states.add(BidiState.listening);
  }

  void endAudio() {
    _send(<String, dynamic>{
      'realtimeInput': <String, dynamic>{'audioStreamEnd': true},
    });
    _states.add(BidiState.thinking);
  }

  void sendToolResponse({
    required String id,
    required String name,
    required Map<String, dynamic> response,
  }) {
    _send(<String, dynamic>{
      'toolResponse': <String, dynamic>{
        'functionResponses': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': id,
            'name': name,
            'response': response,
            'scheduling': <String, dynamic>{},
          },
        ],
      },
    });
  }

  Future<void> close() async {
    _setupComplete = false;
    await _channel?.sink.close();
    _channel = null;
    _states.add(BidiState.disconnected);
  }

  void dispose() {
    _states.close();
    _transcripts.close();
    _audio.close();
    _toolCalls.close();
  }

  void _send(Map<String, dynamic> frame) {
    final channel = _channel;
    if (channel == null || !_setupComplete) {
      _outbox.add(frame);
      return;
    }
    channel.sink.add(jsonEncode(frame));
  }

  void _onMessage(dynamic raw) {
    final text = raw is String
        ? raw
        : raw is List<int>
            ? utf8.decode(raw)
            : raw.toString();
    Map<String, dynamic> message;
    try {
      message = jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    if (message.containsKey('setupComplete')) {
      _setupComplete = true;
      for (final frame in _outbox) {
        _channel?.sink.add(jsonEncode(frame));
      }
      _outbox.clear();
      _states.add(BidiState.ready);
      return;
    }

    final update = message['sessionResumptionUpdate'];
    if (update is Map && update['newHandle'] != null) {
      _resumeHandle = update['newHandle'].toString();
    }

    final toolCall = message['toolCall'];
    if (toolCall is Map) {
      _toolCalls.add(Map<String, dynamic>.from(toolCall));
    }

    final content = message['serverContent'];
    if (content is! Map) return;
    if (content['interrupted'] == true) _states.add(BidiState.listening);

    final input = content['inputTranscription'];
    if (input is Map && input['text'] != null) {
      _transcripts.add(input['text'].toString());
    }
    final output = content['outputTranscription'];
    if (output is Map && output['text'] != null) {
      _transcripts.add(output['text'].toString());
    }

    final turn = content['modelTurn'];
    if (turn is Map) {
      final parts = turn['parts'];
      if (parts is List) {
        for (final part in parts) {
          if (part is! Map) continue;
          final textPart = part['text'];
          if (textPart != null) _transcripts.add(textPart.toString());
          final inline = part['inlineData'];
          if (inline is Map && inline['data'] != null) {
            _audio.add(inline['data'].toString());
            _states.add(BidiState.speaking);
          }
        }
      }
    }
    if (content['turnComplete'] == true) _states.add(BidiState.ready);
  }

  void _onDone() {
    _setupComplete = false;
    _states.add(BidiState.disconnected);
  }
}
