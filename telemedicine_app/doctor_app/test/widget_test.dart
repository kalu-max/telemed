// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:doctor_app/main.dart';

void main() {
  testWidgets('DoctorApp can be created', (WidgetTester tester) async {
    // Build the application and ensure it renders a widget tree.
    await tester.pumpWidget(const DoctorApp());
    expect(find.byType(DoctorApp), findsOneWidget);
  });
}
