import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../core/agent/tool_registry.dart';
import '../../core/keys/key_store.dart';
import '../../core/navigation/routes.dart';
import '../../core/notifications/reply_sender.dart';
import '../../core/services/backend_client.dart';
import '../../core/services/gemini_client.dart';
import '../../core/services/gemini_key_guard.dart';
import '../../core/services/language_policy.dart';
import '../../core/services/model_catalog.dart';
import '../../core/theme/persona.dart';
import '../../state/app_state.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final config = state.voice.config;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Persona', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: Persona.values.map((p) {
            return ChoiceChip(
              label: Text(p.label),
              selected: state.persona == p,
              onSelected: (_) => state.setPersona(p),
            );
          }).toList(),
        ),
        const Divider(height: 32),

        Text('Voice', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text('Spoken language: বাংলা (শুধু বাংলা — আপাতত)'),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.record_voice_over),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: LanguagePolicy.locales
                        .any((entry) => entry.$1 == config.localeId)
                    ? config.localeId
                    : LanguagePolicy.localeId,
                decoration: const InputDecoration(labelText: 'Recognition locale'),
                items: LanguagePolicy.locales
                    .map((entry) => DropdownMenuItem(
                          value: entry.$1,
                          child: Text(entry.$2),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  // Only the ASR dialect changes; TTS always stays Bengali.
                  state.voice.updateConfig(
                    config.copyWith(
                      localeId: v,
                      ttsLanguage: LanguagePolicy.ttsLanguage,
                      wakeWords: LanguagePolicy.wakeWords,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text('Speech rate: ${config.ttsRate.toStringAsFixed(2)}'),
        Slider(
          min: 0.3,
          max: 0.9,
          value: config.ttsRate,
          onChanged: (v) => state.voice.updateConfig(config.copyWith(ttsRate: v)),
        ),
        Text('Wake words: ${config.wakeWords.join(", ")}',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: state.testVoice,
              icon: const Icon(Icons.volume_up),
              label: const Text('Test voice'),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () => openAppSettings(),
              icon: const Icon(Icons.mic),
              label: const Text('Mic permission'),
            ),
          ],
        ),
        const Divider(height: 32),

        Text('Gemini setup', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Install doc → engine'),
            subtitle: const Text('প্রথমে doc ফাইল, তারপর Gemini engine install'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => state.navigate(Routes.settingsGeminiSetup),
          ),
        ),
        const SizedBox(height: 10),
        Text('API key (Gemini)', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text('Your key is stored encrypted on this device only.'),
        const SizedBox(height: 10),
        const _KeyField(),
        const SizedBox(height: 16),
        const _BackendField(),
        const Divider(height: 32),

        Text('Tool budget', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text('${ToolRegistry.budget(8).length} of ${kTools.length} tools declared '
            '(tier 0 first). Unknown names get fuzzy suggestions.'),
        const Divider(height: 32),

        Text('Notifications', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: ReplySender.openNotificationSettings,
          icon: const Icon(Icons.notifications_active_outlined),
          label: const Text('Enable notification reply access'),
        ),
        const Divider(height: 32),

        Text('Chat summary', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: state.summarizeChat,
          icon: const Icon(Icons.summarize_outlined),
          label: const Text('Summarize conversation'),
        ),
        const Divider(height: 32),

        Text('Backup', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const _BackupField(),
        const Divider(height: 32),

        Text('Devices', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const _DevicesField(),
      ],
    );
  }
}

class _BackupField extends StatefulWidget {
  const _BackupField();

  @override
  State<_BackupField> createState() => _BackupFieldState();
}

class _BackupFieldState extends State<_BackupField> {
  final _controller = TextEditingController();
  String _message = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () async {
                final data = await BackendClient.instance.exportBackup();
                if (data == null) {
                  setState(() => _message = 'Export ব্যর্থ — backend সেট করা আছে কি?');
                  return;
                }
                _controller.text = data;
                setState(() => _message = 'Backup প্রস্তুত — নিচের টেক্সট কপি করুন।');
              },
              icon: const Icon(Icons.download_outlined),
              label: const Text('Export'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: () async {
                final ok = await BackendClient.instance.importBackup(_controller.text);
                setState(() => _message = ok ? 'Import হয়েছে।' : 'Import ব্যর্থ — JSON দেখুন।');
              },
              icon: const Icon(Icons.upload_outlined),
              label: const Text('Import'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Backup JSON (export / paste to import)',
            border: OutlineInputBorder(),
          ),
        ),
        if (_message.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_message),
          ),
      ],
    );
  }
}

class _DevicesField extends StatefulWidget {
  const _DevicesField();

  @override
  State<_DevicesField> createState() => _DevicesFieldState();
}

class _DevicesFieldState extends State<_DevicesField> {
  final _name = TextEditingController();
  List<String> _devices = const [];
  String _message = '';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final devices = await BackendClient.instance.listDevices();
    if (!mounted) return;
    setState(() {
      if (devices != null) _devices = devices;
      if (devices == null) _message = 'Backend সেট করা নেই।';
    });
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _name,
          decoration: const InputDecoration(
            labelText: 'Device name (e.g. Phone-2)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            FilledButton.icon(
              onPressed: () async {
                final token = await BackendClient.instance.registerDevice(_name.text.trim());
                if (token == null) {
                  setState(() => _message = 'রেজিস্টার ব্যর্থ।');
                  return;
                }
                await KeyStore.instance.save(KeyStoreKeys.backendToken, token);
                setState(() => _message = 'ডিভাইস টোকেন সংরক্ষিত।');
                _refresh();
              },
              icon: const Icon(Icons.devices_other),
              label: const Text('Register'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () async {
                final ok = await BackendClient.instance.revokeDevice(_name.text.trim());
                setState(() => _message = ok ? 'ডিভাইস বাতিল।' : 'বাতিল ব্যর্থ।');
                _refresh();
              },
              icon: const Icon(Icons.block),
              label: const Text('Revoke'),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _refresh,
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._devices.map((d) => ListTile(
              dense: true,
              leading: const Icon(Icons.smartphone_outlined, size: 18),
              title: Text(d),
            )),
        if (_message.isNotEmpty) Text(_message),
      ],
    );
  }
}

class _BackendField extends StatefulWidget {
  const _BackendField();

  @override
  State<_BackendField> createState() => _BackendFieldState();
}

class _BackendFieldState extends State<_BackendField> {
  final _url = TextEditingController();
  final _token = TextEditingController();
  String _message = '';

  @override
  void initState() {
    super.initState();
    Future.wait([
      KeyStore.instance.read(KeyStoreKeys.backendUrl),
      KeyStore.instance.read(KeyStoreKeys.backendToken),
    ]).then((values) {
      if (!mounted) return;
      setState(() {
        _url.text = values[0] ?? '';
        _token.text = values[1] ?? '';
      });
    });
  }

  @override
  void dispose() {
    _url.dispose();
    _token.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: const Text('Backend proxy (optional)'),
      subtitle: const Text('Use a Python server instead of a local API key'),
      children: [
        TextField(
          controller: _url,
          decoration: const InputDecoration(
            labelText: 'Backend URL (e.g. http://10.0.2.2:8000)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _token,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Bearer token (optional)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: () async {
            final appState = context.read<AppState>();
            await KeyStore.instance.save(KeyStoreKeys.backendUrl, _url.text);
            await KeyStore.instance.save(KeyStoreKeys.backendToken, _token.text);
            if (!mounted) return;
            appState.setFlag(
                KeyStoreKeys.backendUrl, _url.text.trim().isNotEmpty);
            setState(() => _message = 'সংরক্ষিত। সরাসরি key মোডে URL খালি রাখুন।');
          },
          child: const Text('Save backend settings'),
        ),
        if (_message.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_message),
          ),
      ],
    );
  }
}

class _KeyField extends StatefulWidget {
  const _KeyField();

  @override
  State<_KeyField> createState() => _KeyFieldState();
}

class _KeyFieldState extends State<_KeyField> {
  final _controller = TextEditingController();
  bool _obscure = true;
  bool _checking = false;
  bool _saved = false;
  String _message = '';
  String _hint = '';
  String _model = '';

  @override
  void initState() {
    super.initState();
    Future.wait([
      KeyStore.instance.read(KeyStoreKeys.gemini),
      KeyStore.instance.read(KeyStoreKeys.geminiModel),
      GeminiClient.instance.savedKeyHint(),
    ]).then((values) {
      if (!mounted) return;
      setState(() {
        _controller.text = GeminiKeyGuard.sanitize(values[0] ?? '');
        _model = values[1] ?? '';
        _hint = values[2] ?? '';
        _saved = _controller.text.isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    var raw = _controller.text;
    if (raw.trim().isEmpty) {
      raw = await KeyStore.instance.read(KeyStoreKeys.gemini) ?? '';
    }
    setState(() => _checking = true);
    final check = await GeminiClient.instance.testKey(raw);
    if (!mounted) return;
    setState(() {
      _checking = false;
      _message = check.message;
    });
  }

  Future<void> _save() async {
    final key = GeminiKeyGuard.sanitize(_controller.text);
    if (key.isEmpty) {
      setState(() => _message = _controller.text.trim().isEmpty
          ? GeminiKeyCheck.missing().message
          : GeminiKeyCheck.invalidFormat().message);
      return;
    }
    setState(() => _checking = true);
    final check = await GeminiClient.instance.testKey(key);
    if (!mounted) return;
    if (!check.ok) {
      setState(() {
        _checking = false;
        _message = check.message;
      });
      return;
    }

    final hint = GeminiKeyGuard.hint(key);
    await Future.wait([
      KeyStore.instance.save(KeyStoreKeys.gemini, key),
      KeyStore.instance.save(KeyStoreKeys.geminiKeyHint, hint),
      KeyStore.instance.save(KeyStoreKeys.geminiModel, _model),
    ]);
    if (!mounted) return;
    context.read<AppState>().setFlag(KeyStoreKeys.gemini, true);
    setState(() {
      _controller.text = key;
      _hint = hint;
      _saved = true;
      _checking = false;
      _message = 'KEY যাচাই হয়েছে — ${check.message}';
    });
  }

  Future<void> _delete() async {
    await Future.wait([
      KeyStore.instance.remove(KeyStoreKeys.gemini),
      KeyStore.instance.remove(KeyStoreKeys.geminiKeyHint),
      KeyStore.instance.remove(KeyStoreKeys.geminiModel),
    ]);
    if (!mounted) return;
    context.read<AppState>().setFlag(KeyStoreKeys.gemini, false);
    setState(() {
      _controller.clear();
      _hint = '';
      _saved = false;
      _message = 'KEY মুছে ফেলা হয়েছে।';
    });
  }

  @override
  Widget build(BuildContext context) {
    final models = <String>['', ...ModelCatalog.textFallback];
    if (_model.isNotEmpty && !models.contains(_model)) models.add(_model);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          obscureText: _obscure,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: 'Gemini API key',
            hintText: _hint.isEmpty ? 'AIza…' : 'সংরক্ষিত: $_hint',
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'ফ্রি KEY: ${GeminiKeyGuard.aiStudioUrl}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        TextButton.icon(
          onPressed: () async {
            await Clipboard.setData(
              const ClipboardData(text: GeminiKeyGuard.aiStudioUrl),
            );
            if (!mounted) return;
            setState(() => _message = 'ফ্রি KEY-র লিঙ্ক কপি হয়েছে।');
          },
          icon: const Icon(Icons.copy, size: 16),
          label: const Text('লিঙ্ক কপি করুন'),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          initialValue: models.contains(_model) ? _model : '',
          decoration: const InputDecoration(
            labelText: 'মডেল',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final model in models)
              DropdownMenuItem<String>(
                value: model,
                child: Text(model.isEmpty ? 'স্বয়ংক্রিয় (fallback সহ)' : model),
              ),
          ],
          onChanged: (value) => setState(() => _model = value ?? ''),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            FilledButton.icon(
              onPressed: _checking ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(_checking ? 'যাচাই হচ্ছে…' : 'Save key'),
            ),
            OutlinedButton.icon(
              onPressed: _checking ? null : _test,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Test key'),
            ),
            if (_saved)
              OutlinedButton.icon(
                onPressed: _checking ? null : _delete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete'),
              ),
          ],
        ),
        if (_message.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_message),
          ),
      ],
    );
  }
}
