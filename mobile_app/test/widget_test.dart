import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/main.dart';

void main() {
  testWidgets('KIWI App loads Dashboard smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const KiwiApp());

    expect(find.text("Let's secure your connection."), findsOneWidget);
    expect(find.text('KIWI Scan'), findsOneWidget);
  });
}
