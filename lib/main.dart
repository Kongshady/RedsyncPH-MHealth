import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hemophilia_manager/routes/routes.dart';
import 'package:hemophilia_manager/screens/registration/authentication_landing_screen.dart';
import 'package:hemophilia_manager/screens/onboarding/onboarding_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hemophilia_manager/firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hemophilia_manager/screens/main_screen/patient_screens/main_screen_hud.dart';
import 'package:hemophilia_manager/screens/main_screen/healthcare_provider_screen/healthcare_main_screen.dart';
import 'package:hemophilia_manager/screens/admin/admin_dashboard.dart';
import 'package:hemophilia_manager/services/openai_service.dart';
import 'package:hemophilia_manager/services/notification_service.dart';
import 'package:hemophilia_manager/services/firestore.dart';
import 'package:hemophilia_manager/services/offline_service.dart';
import 'package:hemophilia_manager/services/local_medication_reminder_service.dart';
import 'package:hemophilia_manager/services/medication_notification_service.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize OpenAI service
  try {
    await OpenAIService.initialize();
  } catch (e) {
    print('Warning: Failed to initialize OpenAI service: $e');
  }

  // Clean up expired unverified medical accounts
  try {
    final FirestoreService firestoreService = FirestoreService();
    await firestoreService.cleanupExpiredUnverifiedAccounts();
    print('Expired account cleanup completed');
  } catch (e) {
    print('Warning: Failed to cleanup expired accounts: $e');
  }

  // Initialize Offline service for local storage and sync
  try {
    final OfflineService offlineService = OfflineService();
    await offlineService.initialize();
    print('Offline service initialized successfully');
  } catch (e) {
    print('Warning: Failed to initialize Offline service: $e');
  }

  // Initialize Notification service
  try {
    await NotificationService().initialize();
    print('Notification service initialized successfully');
  } catch (e) {
    print('Warning: Failed to initialize Notification service: $e');
    // App can still function without notifications
    // Don't rethrow to prevent app startup crash
  }

  // Initialize Local Medication Reminder service
  try {
    final LocalMedicationReminderService medicationReminderService =
        LocalMedicationReminderService();
    await medicationReminderService.initialize();
    print('Local Medication Reminder service initialized successfully');
  } catch (e) {
    print(
        'Warning: Failed to initialize Local Medication Reminder service: $e');
  }

  // Initialize Medication Notification service for in-app notifications
  try {
    final MedicationNotificationService medicationNotificationService =
        MedicationNotificationService();
    await medicationNotificationService.initialize();
    print('Medication Notification service initialized successfully');
  } catch (e) {
    print('Warning: Failed to initialize Medication Notification service: $e');
  }

  runApp(const MyApp());
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // Set up notification tap handling for local notifications
    NotificationService.setNavigationCallback(_handleNotificationTap);
  }

  void _handleNotificationTap(String payload) {
    print('Handling notification tap with payload: $payload');

    // Parse payload and navigate accordingly
    try {
      if (payload.startsWith('post_')) {
        // Handle post notifications (like, comment, share)
        final parts = payload.split(':');
        if (parts.length >= 2) {
          final postId = parts[1];
          _navigateToPost(postId);
        }
      } else if (payload.startsWith('message:')) {
        // Handle message notifications
        final parts = payload.split(':');
        if (parts.length >= 3) {
          final senderId = parts[1];
          final conversationId = parts[2];
          _navigateToMessage(senderId, conversationId);
        }
      } else if (payload.startsWith('medication_reminder:')) {
        // Handle medication reminder notifications
        final parts = payload.split(':');
        if (parts.length >= 2) {
          final scheduleId = parts[1];
          _navigateToMedication(scheduleId);
        }
      }
    } catch (e) {
      print('Error parsing notification payload: $e');
    }
  }

  void _navigateToPost(String postId) {
    print('Navigating to post: $postId');

    // Navigate to community screen with specific post
    navigatorKey.currentState?.pushNamed(
      '/community',
      arguments: {'openPostId': postId},
    );
  }

  void _navigateToMessage(String senderId, String conversationId) {
    print('Navigating to message: $senderId, $conversationId');

    // Navigate to messages screen with specific conversation
    navigatorKey.currentState?.pushNamed(
      '/messages',
      arguments: {
        'openChatWithUserId': senderId,
        'conversationId': conversationId,
      },
    );
  }

  void _navigateToMedication(String scheduleId) {
    print('Navigating to medication: $scheduleId');

    // Navigate to medication/dashboard screen
    navigatorKey.currentState?.pushNamed(
      '/medication',
      arguments: {'scheduleId': scheduleId},
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'RedSyncPH',
          theme: ThemeData(
            fontFamily: 'Poppins',
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.redAccent,
              brightness: Brightness.light,
            ),
            scaffoldBackgroundColor: Colors.white,
            cardColor: Colors.grey[50],
            dividerColor: Colors.grey[300],
          ),
          themeMode: currentMode,
          debugShowCheckedModeBanner: false,
          home: const AppInitializer(),
          routes: AppRoutes.routes,
        );
      },
    );
  }
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  _AppInitializerState createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Check onboarding status
      final prefs = await SharedPreferences.getInstance();
      final onboardingComplete = prefs.getBool('onboarding_complete') ?? false;

      if (!mounted) return;

      if (!onboardingComplete) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const OnboardingScreen()),
        );
        return;
      }

      // Check login status from secure storage
      final isLoggedIn = await _secureStorage.read(key: 'isLoggedIn');
      final userRole = await _secureStorage.read(key: 'userRole');

      if (!mounted) return;

      if (isLoggedIn == 'true' && userRole != null && userRole.isNotEmpty) {
        // User is logged in, navigate to appropriate screen
        Widget targetScreen;
        switch (userRole) {
          case 'patient':
          case 'caregiver':
            targetScreen = const MainScreenDisplay();
            break;
          case 'medical':
            targetScreen = const HealthcareMainScreen();
            break;
          case 'admin':
            targetScreen = const AdminDashboard();
            break;
          default:
            targetScreen = const AuthenticationLandingScreen();
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => targetScreen),
        );
      } else {
        // User is not logged in, go to homepage
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const AuthenticationLandingScreen(),
          ),
        );
      }
    } catch (e) {
      // If any error occurs, default to homepage
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const AuthenticationLandingScreen(),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'RedSyncPH',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.redAccent,
                letterSpacing: 1.2,
              ),
            ),
            SizedBox(height: 20),
            CircularProgressIndicator(color: Colors.redAccent),
          ],
        ),
      ),
    );
  }
}
