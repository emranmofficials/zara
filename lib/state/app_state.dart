import 'dart:async';

import 'package:flutter/material.dart';

import '../core/agent/tool_dispatcher.dart';
import '../core/models/models.dart';
import '../core/navigation/routes.dart';
import '../core/notifications/reply_sender.dart';
import '../core/services/backend_client.dart';
import '../core/services/gemini_client.dart';
import '../core/services/language_policy.dart';
import '../core/services/voice_session.dart';
import '../core/theme/persona.dart';

enum VoiceStatus { idle, listening, thinking, speaking }

class AppState extends ChangeNotifier {
  /// [enableVoice] = false keeps platform channels untouched (used in widget tests).
  AppState({this.enableVoice = true}) {
    _initVoice();
    if (enableVoice) _startNotificationPolling();
  }

  final bool enableVoice;
  late final VoiceSession _voice;
  StreamSubscription<String>? _transcriptSub;
  StreamSubscription<String>? _partialSub;
  StreamSubscription<void>? _wakeSub;
  StreamSubscription<VoiceStage>? _stageSub;
  Timer? _notificationPoll;

  final ToolDispatcher _tools = const ToolDispatcher();

  Persona _persona = Persona.zara;
  String _route = Routes.home;
  VoiceStatus _voiceStatus = VoiceStatus.idle;
  final List<ChatMessage> _messages = <ChatMessage>[];
  VoiceReplyOffer? _offer;
  PendingReply? _pending;
  PendingTool? _pendingTool;
  String _draft = '';
  String _partial = '';
  String _voiceError = '';
  String _lastAction = '';

  // Home / Vibes live state (mirrors the foreground-service state flow).
  String _mood = 'happy';
  int _energy = 72;
  String? _attachment;
  bool _oldChat = false;
  final Map<String, bool> _flags = <String, bool>{};

  Persona get persona => _persona;
  String get route => _route;
  VoiceStatus get voiceStatus => _voiceStatus;
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  VoiceReplyOffer? get offer => _offer;
  PendingReply? get pending => _pending;
  PendingTool? get pendingTool => _pendingTool;
  String get draft => _draft;
  String get partial => _partial;
  String get voiceError => _voiceError;
  String get lastAction => _lastAction;
  String get mood => _mood;
  int get energy => _energy;
  String? get attachment => _attachment;
  bool get oldChat => _oldChat;
  VoiceSession get voice => _voice;

  void _initVoice() {
    _voice = VoiceSession();

    _transcriptSub = _voice.transcripts.listen((text) {
      setDraft(text);
      send();
    });
    _partialSub = _voice.partials.listen((text) {
      _partial = text;
      notifyListeners();
    });
    _wakeSub = _voice.wakeDetected.listen((_) {
      if (!_voice.isListening) _voice.startListening();
    });
    _stageSub = _voice.stages.listen((stage) {
      _voiceStatus = switch (stage) {
        VoiceStage.listening => VoiceStatus.listening,
        VoiceStage.speaking => VoiceStatus.speaking,
        VoiceStage.transcribing => VoiceStatus.thinking,
        VoiceStage.idle => VoiceStatus.idle,
      };
      notifyListeners();
    });
  }

  void _startNotificationPolling() {
    _notificationPoll = Timer.periodic(const Duration(seconds: 4), (_) async {
      final targets = await ReplySender.pendingReplies();
      if (targets.isEmpty || _offer != null || _pending != null) return;
      final first = targets.first;
      _offer = VoiceReplyOffer(
        chat: first.chat,
        language: _guessLanguage(first.chat),
        token: first.token,
      );
      _lastAction = 'ভয়েস নোটের উত্তর মোড: ${first.chat}';
      notifyListeners();
    });
  }

  String _guessLanguage(String chat) {
    // ZaRa is Bengali-only for now: offers are always polished into Bengali,
    // whatever language the incoming voice note used.
    return LanguagePolicy.name;
  }

  Future<bool> initializeVoice() async {
    final ok = await _voice.initialize();
    if (!ok) {
      _voiceError = 'মাইক / স্পিচ রিকগনিশন পাওয়া যায়নি। Settings দেখুন।';
      notifyListeners();
    }
    return ok;
  }

  void navigate(String route) {
    if (_route == route) return;
    _route = route;
    notifyListeners();
  }

  void setPersona(Persona p) {
    _persona = p;
    notifyListeners();
  }

  void setDraft(String value) {
    _draft = value;
    notifyListeners();
  }

  /// Used by secondary screens and quick actions to surface a local status.
  void setAction(String action) {
    _lastAction = action;
    notifyListeners();
  }

  void setMood(String value) {
    _mood = value;
    notifyListeners();
  }

  void setEnergy(int value) {
    _energy = value.clamp(0, 100);
    notifyListeners();
  }

  void attach(String name) {
    _attachment = name;
    notifyListeners();
  }

  void removeAttachment() {
    _attachment = null;
    notifyListeners();
  }

  void setOldChat(bool value) {
    _oldChat = value;
    notifyListeners();
  }

  /// Persistent switches for the many settings / rules pages.
  bool flag(String key, {bool fallback = false}) => _flags[key] ?? fallback;

  void setFlag(String key, bool value) {
    _flags[key] = value;
    notifyListeners();
  }

  /// A quick action from Home pre-fills the composer and opens Chat.
  void startQuickAction(String label) {
    _draft = '$label: ';
    _route = Routes.chat;
    _lastAction = '$label শুরু — লিখে পাঠান বা মাইক টিপুন।';
    notifyListeners();
  }

  void setOffer(VoiceReplyOffer? offer) {
    _offer = offer;
    notifyListeners();
  }

  void toggleListening() {
    if (_voice.isListening) {
      _voice.stopListening();
    } else {
      _voice.startListening();
    }
  }

  void stopSpeaking() => _voice.stopSpeaking();

  /// Speak a Bengali status line. No-op in widget tests so no plugin channel
  /// is touched when [enableVoice] is false.
  Future<void> speakBengali(String text) async {
    if (!enableVoice || text.trim().isEmpty) return;
    await _voice.speak(text, persona: _persona);
  }

  Future<void> testVoice() =>
      _voice.speak('নমস্কার, আমি ZaRa। বলুন, কী করতে পারি?', persona: _persona);

  Future<void> send() async {
    final text = _draft.trim();
    if (text.isEmpty) return;
    _draft = '';
    _messages.add(ChatMessage.user(text));
    _syncHistory();
    _voiceStatus = VoiceStatus.thinking;
    _partial = '';
    notifyListeners();

    // If a voice-note reply is pending, translate & show the confirm card.
    if (_offer != null) {
      await _prepareReply(offer: _offer!, original: text);
      return;
    }

    final brain = await GeminiClient.instance.respondWithTools(text, persona: _persona.label);
    if (brain.isTool) {
      await _runTool(brain.toolCall!);
      return;
    }

    final reply = brain.text ?? 'কোনো উত্তর পাওয়া যায়নি।';
    _messages.add(ChatMessage.assistant(reply));
    _syncHistory();
    _voiceStatus = VoiceStatus.speaking;
    notifyListeners();
    await _voice.speak(reply, persona: _persona);
  }

  Future<void> _prepareReply({
    required VoiceReplyOffer offer,
    required String original,
  }) async {
    final translated = await GeminiClient.instance.translateReply(
      text: original,
      targetLanguage: offer.language,
      chat: offer.chat,
    );
    _pending = PendingReply(
      chat: offer.chat,
      language: offer.language,
      original: original,
      reply: translated,
      token: offer.token,
    );
    _voiceStatus = VoiceStatus.idle;
    _lastAction = 'উত্তর প্রস্তুত — নিশ্চিত করুন।';
    notifyListeners();
  }

  Future<void> confirmPending({required bool yes}) async {
    if (_pending != null) {
      final p = _pending!;
      _pending = null;
      if (!yes) {
        _lastAction = 'উত্তর বাতিল হয়েছে।';
        await _voice.speak('ঠিক আছে, পাঠানো হয়নি।', persona: _persona);
        _offer = null;
        notifyListeners();
        return;
      }
      final ok = await ReplySender.send(p.token, p.reply);
      _lastAction = ok
          ? 'পাঠানো হয়েছে — ${p.chat}-এ বাংলা উত্তর।'
          : 'নোটিফিকেশনের সময় শেষ, উত্তর যায়নি।';
      _messages.add(ChatMessage.assistant(_lastAction));
      _syncHistory();
      _offer = null;
      notifyListeners();
      await _voice.speak(_lastAction, persona: _persona);
      return;
    }

    if (_pendingTool != null) {
      final call = _pendingTool!.call;
      _pendingTool = null;
      final result = await _tools.execute(call, confirmed: yes);
      if (call.name == 'remember_fact' && yes) {
        await BackendClient.instance.addMemory(call.args['fact']?.toString() ?? '');
      }
      _lastAction = result.message;
      _messages.add(ChatMessage.assistant(result.message));
      _syncHistory();
      notifyListeners();
      await _voice.speak(result.message, persona: _persona);
    }
  }

  void _syncHistory() {
    BackendClient.instance.syncHistory(
      _messages.map((m) => m.toMap()).toList(),
      replace: true,
    );
  }

  Future<String?> _recallFromBackend(String query) async {
    final facts = await BackendClient.instance.fetchMemory();
    if (facts == null || facts.isEmpty) return null;
    final matches = query.isEmpty
        ? facts
        : facts.where((f) => f.toLowerCase().contains(query.toLowerCase())).toList();
    if (matches.isEmpty) return null;
    return 'মনে আছে: ${matches.take(5).join(" | ")}';
  }

  Future<void> _runTool(ToolCall call) async {
    // Local-first recall from backend memory store.
    if (call.name == 'recall_memory') {
      final recalled = await _recallFromBackend(call.args['query']?.toString() ?? '');
      if (recalled != null) {
        _lastAction = recalled;
        _messages.add(ChatMessage.assistant(recalled));
        _syncHistory();
        _voiceStatus = VoiceStatus.speaking;
        notifyListeners();
        await _voice.speak(recalled, persona: _persona);
        return;
      }
    }
    final result = await _tools.execute(call);
    if (result.needsConfirm) {
      _pendingTool = PendingTool(call: call, description: result.message);
      _lastAction = result.message;
      notifyListeners();
      return;
    }
    _lastAction = result.message;
    _messages.add(ChatMessage.assistant(result.message));
    _syncHistory();
    _voiceStatus = VoiceStatus.speaking;
    notifyListeners();
    await _voice.speak(result.message, persona: _persona);
  }

  void cancelPending() => confirmPending(yes: false);

  /// Ask the backend to summarise the synced chat history.
  Future<void> summarizeChat() async {
    _voiceStatus = VoiceStatus.thinking;
    _lastAction = 'চ্যাটের সারাংশ তৈরি করছি…';
    notifyListeners();
    final summary = await BackendClient.instance.fetchSummary();
    if (summary == null) {
      _lastAction = 'সারাংশ পাওয়া যায়নি — backend সেট করা আছে কি?';
      _voiceStatus = VoiceStatus.idle;
      notifyListeners();
      return;
    }
    _lastAction = summary;
    _messages.add(ChatMessage.assistant(summary));
    _syncHistory();
    _voiceStatus = VoiceStatus.speaking;
    notifyListeners();
    await _voice.speak(summary, persona: _persona);
  }

  void clearChat() {
    _messages.clear();
    _pending = null;
    _pendingTool = null;
    BackendClient.instance.clearHistory();
    notifyListeners();
  }

  @override
  void dispose() {
    _notificationPoll?.cancel();
    _transcriptSub?.cancel();
    _partialSub?.cancel();
    _wakeSub?.cancel();
    _stageSub?.cancel();
    _voice.dispose();
    super.dispose();
  }
}
