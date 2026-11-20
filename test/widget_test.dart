import 'package:flutter_test/flutter_test.dart';
import 'package:zara/app.dart';

void main() {
  testWidgets('ZaRa renders the home shell', (tester) async {
    await tester.pumpWidget(const ZaraApp(enableVoice: false));
    expect(find.textContaining('ZaRa'), findsWidgets);
    expect(find.byType(Scaffold), findsWidgets);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Chat'), findsWidgets);
    expect(find.text('Settings'), findsWidgets);
  });
}
