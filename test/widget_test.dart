import 'package:flutter_test/flutter_test.dart';

import 'package:zegar/main.dart';

void main() {
  testWidgets('Login screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const ZegarApp());
    await tester.pump();

    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Mark Attendance'), findsOneWidget);
  });
}
