import 'package:flutter/material.dart';

// Import all the screens from paitent module
import 'package:provider/provider.dart';

import 'paitent/login.dart';
import 'paitent/paitentdashboard.dart';
import 'paitent/findspecialist.dart';
import 'paitent/prescription_details.dart';
import 'paitent/api_client.dart';
import 'paitent/admin_dashboard.dart';
import 'paitent/doctor_service.dart';
import 'paitent/doctor_dashboard.dart';
import 'paitent/consultation_history_screen.dart';
import 'communication/providers/communication_providers.dart';
import 'communication/services/messaging_service.dart';
import 'communication/services/voice_messaging_service.dart';
import 'communication/services/video_calling_service.dart';
import 'communication/services/bandwidth_optimization_service.dart';
import 'communication/widgets/incoming_call_listener.dart';
import 'config/app_config.dart';

const String backendServerUrl = AppConfig.apiBaseUrl;
const String webSocketServerUrl = AppConfig.wsBaseUrl;

void main() {
  runApp(const MediCareApp());
}

class MediCareApp extends StatelessWidget {
  const MediCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    final apiClient = TeleMedicineApiClient(backendServerUrl);

    return MultiProvider(
      providers: [
        // API Client - for REST calls
        Provider<TeleMedicineApiClient>(create: (_) => apiClient),

        // Doctor Service - for finding and managing doctors
        ChangeNotifierProvider(create: (_) => DoctorService(apiClient)),

        // Messaging Service - for real-time chat with websocket
        ProxyProvider<TeleMedicineApiClient, MessagingService>(
          create: (context) {
            final userId = apiClient.currentUserId ?? 'guest';
            final userName = 'Patient';
            return MessagingService(
              serverUrl: webSocketServerUrl,
              userId: userId,
              userName: userName,
            );
          },
          update: (context, apiClient, previousMessagingService) {
            if (previousMessagingService != null) {
              return previousMessagingService;
            }
            final userId = apiClient.currentUserId ?? 'guest';
            final userName = 'Patient';
            return MessagingService(
              serverUrl: webSocketServerUrl,
              userId: userId,
              userName: userName,
            );
          },
        ),

        // Messaging Provider - state management for messages
        ChangeNotifierProxyProvider<MessagingService, MessagingProvider>(
          create: (context) => MessagingProvider(
            messagingService: context.read<MessagingService>(),
          ),
          update: (context, messagingService, previousMessagingProvider) {
            previousMessagingProvider?.dispose();
            return MessagingProvider(messagingService: messagingService);
          },
        ),

        // Voice Messaging Service - for voice messages
        ProxyProvider<MessagingService, VoiceMessagingService>(
          create: (context) => VoiceMessagingService(
            messagingService: context.read<MessagingService>(),
          ),
          update: (context, messagingService, previousVoiceService) {
            previousVoiceService?.dispose();
            return VoiceMessagingService(messagingService: messagingService);
          },
        ),

        // Voice Messaging Provider - state management for voice
        ChangeNotifierProxyProvider<
          VoiceMessagingService,
          VoiceMessagingProvider
        >(
          create: (context) => VoiceMessagingProvider(
            voiceMessagingService: context.read<VoiceMessagingService>(),
          ),
          update: (context, voiceService, previousVoiceProvider) {
            previousVoiceProvider?.dispose();
            return VoiceMessagingProvider(voiceMessagingService: voiceService);
          },
        ),

        // Bandwidth Optimization Service - for adaptive video quality
        Provider<BandwidthOptimizationService>(
          create: (_) => BandwidthOptimizationService(),
          dispose: (_, service) => service.dispose(),
        ),

        // Network Provider - state management for network quality
        ChangeNotifierProxyProvider<
          BandwidthOptimizationService,
          NetworkProvider
        >(
          create: (context) => NetworkProvider(
            bandwidthService: context.read<BandwidthOptimizationService>(),
          ),
          update: (context, bandwidthService, previous) {
            if (previous != null) return previous;
            return NetworkProvider(bandwidthService: bandwidthService);
          },
        ),

        // Video Calling Service - WebRTC peer-to-peer video
        ProxyProvider<BandwidthOptimizationService, VideoCallingService>(
          create: (context) {
            final userId = apiClient.currentUserId ?? 'guest';
            const userName = 'Patient';
            final service = VideoCallingService(
              signalingServerUrl: webSocketServerUrl,
              userId: userId,
              userName: userName,
              bandwidthService: context.read<BandwidthOptimizationService>(),
            );
            service.initialize();
            return service;
          },
          update: (context, bandwidthService, previousService) {
            if (previousService != null) return previousService;
            final userId = apiClient.currentUserId ?? 'guest';
            const userName = 'Patient';
            final service = VideoCallingService(
              signalingServerUrl: webSocketServerUrl,
              userId: userId,
              userName: userName,
              bandwidthService: bandwidthService,
            );
            service.initialize();
            return service;
          },
        ),

        // Video Calling Provider - state management for video calls
        ChangeNotifierProxyProvider<VideoCallingService, VideoCallingProvider>(
          create: (context) => VideoCallingProvider(
            videoCallingService: context.read<VideoCallingService>(),
          ),
          update: (context, videoService, previous) {
            if (previous != null) return previous;
            return VideoCallingProvider(videoCallingService: videoService);
          },
        ),
      ],
      child: MaterialApp(
        title: 'MediCare Connect',
        debugShowCheckedModeBanner: false,
        builder: (context, child) =>
            IncomingCallListener(child: child ?? const SizedBox.shrink()),
        theme: ThemeData(
          useMaterial3: true,
          primaryColor: Colors.teal[700],
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.teal,
            primary: Colors.teal[700]!,
            secondary: Colors.orange,
            surface: Colors.grey[50]!,
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
          fontFamily: 'Roboto',
        ),
        home: const LoginScreen(),
        routes: {
          '/dashboard': (context) => const PatientDashboard(),
          '/search': (context) => const FindSpecialistScreen(),
          '/prescription': (context) => const PrescriptionDetailsScreen(),
          '/history': (context) {
            final api = context.read<TeleMedicineApiClient>();
            return ConsultationHistoryScreen(api: api);
          },
          '/doctor/dashboard': (context) => const DoctorDashboard(),
          '/admin': (context) =>
              AdminDashboard(api: TeleMedicineApiClient(backendServerUrl)),
        },
      ),
    );
  }
}
