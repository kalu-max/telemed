import 'package:flutter/material.dart';

// Import all the screens we have built so far
import 'login.dart';
import 'doctor_dashboard.dart';
import 'paitentdashboard.dart';
import 'findspecialist.dart';
import 'prescription_details.dart';
// Note: active_consultation_screen.dart is already imported inside find_specialist_screen.dart
// for the "Track-to-Consult" data bridge navigation.

void main() {
  runApp(const MediCareApp());
}

class MediCareApp extends StatelessWidget {
  const MediCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MediCare Connect',
      debugShowCheckedModeBanner: false, // Removes the red debug banner
      // Global Theme Setup
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: Colors.teal[700],
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          primary: Colors.teal[700]!,
          secondary: Colors.orange, // Used for warning/instruction accents
          surface: Colors.grey[50]!, // Use surface (background deprecated)
        ),
        scaffoldBackgroundColor: Colors.grey[50],
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.black87),
          titleTextStyle: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal[700],
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        fontFamily: 'Roboto', // Or any custom font you prefer like 'Poppins'
      ),

      // Application Entry Point
      home: const LoginScreen(),

      // Optional: Setup Named Routes for easy navigation later
      routes: {
        '/dashboard': (context) => const PatientDashboard(),
        '/doctor-dashboard': (context) => const DoctorDashboard(),
        '/search': (context) => const FindSpecialistScreen(),
        '/prescription': (context) => const PrescriptionDetailsScreen(),
      },
    );
  }
}
