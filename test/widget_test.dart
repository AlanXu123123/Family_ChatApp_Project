import 'package:flutter_test/flutter_test.dart';
import 'package:im_app/main.dart';

void main() {
  testWidgets('App renders', (WidgetTester tester) async {
    await tester.pumpWidget(const JustinChatApp());
    expect(find.text('Justin Chat'), findsOneWidget);
  });
}
