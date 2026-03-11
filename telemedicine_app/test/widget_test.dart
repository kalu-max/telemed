import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:telemedicine_app/main.dart';
import 'package:telemedicine_app/paitent/login.dart';
import 'package:telemedicine_app/config/app_config.dart';

void main() {
  testWidgets('App builds and shows login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MediCareApp());
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('Login screen has email and password fields', (WidgetTester tester) async {
    await tester.pumpWidget(const MediCareApp());
    await tester.pumpAndSettle();

    // Should have text fields for email and password
    expect(find.byType(TextField), findsWidgets);
    // Should have a login button
    expect(find.widgetWithText(ElevatedButton, 'Sign In'), findsOneWidget);
  });

  testWidgets('Login screen has forgot password option', (WidgetTester tester) async {
    await tester.pumpWidget(const MediCareApp());
    await tester.pumpAndSettle();

    expect(find.text('Forgot Password?'), findsOneWidget);
  });

  testWidgets('Login screen has register link', (WidgetTester tester) async {
    await tester.pumpWidget(const MediCareApp());
    await tester.pumpAndSettle();

    // Should have some link/text to register
    expect(find.textContaining('Create Account'), findsWidgets);
  });

  test('AppConfig has valid default API URL', () {
    expect(AppConfig.apiBaseUrl, isNotEmpty);
    expect(AppConfig.apiBaseUrl, startsWith('http'));
  });

  test('AppConfig has valid default WebSocket URL', () {
    expect(AppConfig.wsBaseUrl, isNotEmpty);
    expect(AppConfig.wsBaseUrl, startsWith('ws'));
  });

  test('AppConfig ICE servers are non-empty', () {
    final servers = AppConfig.iceServers;
    expect(servers, isNotEmpty);
    expect(servers.first, contains('urls'));
  });
}
