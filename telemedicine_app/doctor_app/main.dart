// Entry point for the new Flutter doctor app
import 'package:flutter/material.dart';

void main() {
  runApp(const DoctorApp());
}

class DoctorApp extends StatelessWidget {
  const DoctorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Doctor Telemedicine',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const DoctorLoginScreen(),
    );
  }
}

class DoctorLoginScreen extends StatelessWidget {
  const DoctorLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Doctor Login')),
      body: const Center(child: Text('Doctor login UI here')),
    );
  }
}
