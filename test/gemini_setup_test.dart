import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zara/features/settings/gemini_setup_screen.dart';
import 'package:zara/state/app_state.dart';

void main() {
  testWidgets('Gemini engine install is gated on seeing the install doc',
      (tester) async {
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => AppState(enableVoice: false),
      child: const MaterialApp(home: GeminiSetupScreen()),
    ));
    await tester.pumpAndSettle();

    FilledButton installButton() => tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'ইঞ্জিন ইনস্টল করুন'),
        );

    // Step 1 first: the engine button exists but is disabled.
    expect(find.text('ধাপ ১ — Install doc'), findsOneWidget);
    expect(find.text('ধাপ ২ — Gemini engine'), findsOneWidget);
    expect(installButton().onPressed, isNull);

    // Open and acknowledge the doc.
    await tester.tap(find.text('Doc ফাইল খুলুন'));
    await tester.pumpAndSettle();
    expect(find.textContaining('install doc'), findsWidgets);
    await tester.tap(find.text('Doc দেখেছি — পরবর্তী'));
    await tester.pumpAndSettle();

    // Only now can the engine be installed.
    expect(installButton().onPressed, isNotNull);
    await tester.tap(find.text('ইঞ্জিন ইনস্টল করুন'));
    await tester.pumpAndSettle();
    expect(find.text('ইনস্টল হয়েছে'), findsWidgets);
  });
}
