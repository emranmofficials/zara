import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zara/app.dart';

void main() {
  testWidgets('ZaRa renders the Maya-style home shell', (tester) async {
    await tester.pumpWidget(const ZaraApp(enableVoice: false));
    expect(find.textContaining('ZaRa'), findsWidgets);
    expect(find.byType(Scaffold), findsWidgets);
    expect(find.text('Weather'), findsOneWidget);
    expect(find.text('Energy'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Quick actions'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Quick actions'), findsOneWidget);
    expect(find.text('Reminder'), findsOneWidget);
    expect(find.text('Automation'), findsOneWidget);
  });

  testWidgets('quick action navigates to chat with a pre-filled draft', (tester) async {
    await tester.pumpWidget(const ZaraApp(enableVoice: false));
    final chip = find.widgetWithText(ActionChip, 'Reminder');
    await tester.scrollUntilVisible(chip, 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(find.text('Ask anything…'), findsOneWidget);
  });
}
