import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:doctor_app/main.dart';
import 'package:doctor_app/config/app_config.dart';

void main() {
  testWidgets('DoctorApp can be created', (WidgetTester tester) async {
    await tester.pumpWidget(const DoctorApp());
    expect(find.byType(DoctorApp), findsOneWidget);
  });

  testWidgets('Doctor login screen renders email and password fields', (WidgetTester tester) async {
    await tester.pumpWidget(const DoctorApp());
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsWidgets);
    expect(find.widgetWithText(ElevatedButton, 'Sign In'), findsOneWidget);
  });

  testWidgets('Doctor login screen has forgot password', (WidgetTester tester) async {
    await tester.pumpWidget(const DoctorApp());
    await tester.pumpAndSettle();

    expect(find.text('Forgot Password?'), findsOneWidget);
  });

  test('Doctor AppConfig has valid API URL', () {
    expect(AppConfig.apiBaseUrl, isNotEmpty);
    expect(AppConfig.apiBaseUrl, startsWith('http'));
  });

  test('Doctor AppConfig ICE servers are non-empty', () {
    final servers = AppConfig.iceServers;
    expect(servers, isNotEmpty);
    expect(servers.first, contains('urls'));
  });
}
