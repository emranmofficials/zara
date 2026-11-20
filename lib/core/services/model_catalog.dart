/// Clean-room model catalogue.
///
/// These are generic public model identifiers, not copied proprietary model
/// names. The app tries them in order when a model is missing, rate limited or
/// temporarily unavailable. Users can pin one in Settings.
abstract final class ModelCatalog {
  static const List<String> textFallback = <String>[
    'gemini-2.5-flash-lite',
    'gemini-2.0-flash-lite',
    'gemini-2.0-flash',
    'gemini-flash-latest',
  ];

  static const String defaultText = 'gemini-2.0-flash';

  /// Live voice is negotiated through the same transport as text when the
  /// user's key supports it; these are the candidate model ids we announce.
  static const List<String> liveFallback = <String>[
    'gemini-2.5-flash-native-audio-preview-12-2025',
    'gemini-2.0-flash-lite',
  ];

  static List<String> candidates(String? pinned) {
    final value = pinned?.trim();
    if (value == null || value.isEmpty) return List.unmodifiable(textFallback);
    return <String>[value, ...textFallback.where((m) => m != value)];
  }
}
