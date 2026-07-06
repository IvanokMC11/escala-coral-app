import 'package:flutter_test/flutter_test.dart';
import 'package:escala_coral/main.dart';

void main() {
  testWidgets('App renders login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const EscalaCoralApp());
    expect(find.text('Escala Coral'), findsOneWidget);
    expect(find.text('UNSAAC'), findsOneWidget);
  });
}
