import 'package:flutter/material.dart';
import 'package:hemophilia_manager/screens/main_screen/patient_screens/chatbot_screen.dart';
import 'package:hemophilia_manager/screens/main_screen/patient_screens/community/community_screen.dart';
import 'package:hemophilia_manager/screens/main_screen/patient_screens/pre_screening/pre_screening.dart';
import 'package:hemophilia_manager/screens/registration/authentication_landing_screen.dart';
import 'package:hemophilia_manager/screens/main_screen/healthcare_provider_screen/healthcare_main_screen.dart';
import 'package:hemophilia_manager/screens/main_screen/patient_screens/care_provider_screen.dart';
import 'package:hemophilia_manager/screens/main_screen/patient_screens/care_user_information_screen.dart';
import 'package:hemophilia_manager/screens/main_screen/patient_screens/dosage_calculator_screen.dart';
import 'package:hemophilia_manager/screens/main_screen/patient_screens/log_bleed.dart';
import 'package:hemophilia_manager/screens/main_screen/patient_screens/log_history_screen.dart';
import 'package:hemophilia_manager/screens/main_screen/patient_screens/log_infusion.dart';
import 'package:hemophilia_manager/screens/main_screen/patient_screens/main_screen_hud.dart';
import 'package:hemophilia_manager/screens/main_screen/patient_screens/notifications_screen.dart';
import 'package:hemophilia_manager/screens/main_screen/patient_screens/schedule_medication_screen.dart';
import 'package:hemophilia_manager/screens/main_screen/patient_screens/edit_medication_reminder_screen.dart';
import 'package:hemophilia_manager/screens/main_screen/patient_screens/settings_screens/main_settings.dart';
import 'package:hemophilia_manager/screens/main_screen/patient_screens/settings_screens/user_info_settings.dart';
import 'package:hemophilia_manager/screens/main_screen/patient_screens/settings_screens/caregiver_info_settings.dart';
import 'package:hemophilia_manager/screens/main_screen/patient_screens/settings_screens/medical_info_settings.dart';
import 'package:hemophilia_manager/screens/main_screen/patient_screens/settings_screens/change_password_screen.dart';
import 'package:hemophilia_manager/screens/main_screen/patient_screens/messages_screen.dart';
import 'package:hemophilia_manager/screens/admin/admin_dashboard.dart';
import 'package:hemophilia_manager/screens/admin/admin_settings.dart';
import 'package:hemophilia_manager/screens/onboarding/onboarding_screen.dart';
import 'package:hemophilia_manager/screens/registration/create_acc_page.dart';
import 'package:hemophilia_manager/screens/registration/forgot_password.dart';
import 'package:hemophilia_manager/screens/registration/login_page.dart';
// import 'package:hemophilia_manager/screens/role_selection/choose_role_selection.dart';
import 'package:hemophilia_manager/screens/role_selection/user_creation_success.dart';
import 'package:hemophilia_manager/screens/role_selection/user_details.dart';

class AppRoutes {
  static const String onboarding = '/onboarding';
  static const String authenticationScreen = '/authentication';
  static const String login = '/login';
  static const String register = '/register';
  static const String roleSelection = '/role_selection';
  static const String settings = '/settings';
  static const String notifications = '/notifications';
  static const String doseCalculator = '/dose_calculator';
  static const String logBleed = '/log_bleed';
  static const String scheduleMedication = '/schedule_medication';
  static const String editMedicationReminder = '/edit_medication_reminder';
  static const String userFillup = '/user_fillup';
  static const String userAccountCreated = '/user_account_created';
  static const String userScreen = '/user_screen';
  static const String logHistoryScreen = '/log_history';
  static const String careProviderScreen = '/care_provider';
  static const String careUserInformationScreen = '/care_user_information';
  static const String healthcareMainScreen = '/healthcare_main';
  static const String userInfoSettings = '/user_info_settings';
  static const String caregiverInfoSettings = '/caregiver_info_settings';
  static const String medicalInfoSettings = '/medical_info_settings';
  static const String changePassword = '/change_password';
  static const String logInfusion = '/log_infusion';
  static const String forgotPassword = '/forgot_password';
  static const String chatbotScreen = '/chatbot';
  static const String preScreening = '/pre_screening';
  static const String messages = '/messages';
  static const String community = '/community';
  static const String postDetail = '/post_detail';
  static const String healthcarePatientsList = '/healthcare_patients_list';
  static const String adminDashboard = '/admin_dashboard';
  static const String adminSettings = '/admin_settings';

  static Map<String, WidgetBuilder> routes = {
    onboarding: (context) => const OnboardingScreen(),
    authenticationScreen: (context) => const AuthenticationLandingScreen(),
    login: (context) => const LoginPage(),
    register: (context) => const CreateAccPage(),
    // roleSelection: (context) => const ChooseRoleSelection(),
    settings: (context) => const UserSettings(),
    notifications: (context) => const NotificationsScreen(),
    doseCalculator: (context) => const DosageCalculatorScreen(),
    logBleed: (context) => const LogBleed(),
    scheduleMedication: (context) => const ScheduleMedicationScreen(),
    editMedicationReminder: (context) => const EditMedicationReminderScreen(),
    userFillup: (context) => const UserDetails(),
    userAccountCreated: (context) => const UserCreationSuccess(),
    userScreen: (context) => const MainScreenDisplay(),
    logHistoryScreen: (context) => const LogHistoryScreen(),
    careProviderScreen: (context) => const CareProviderScreen(),
    careUserInformationScreen: (context) => const CareUserInformationScreen(),
    healthcareMainScreen: (context) => const HealthcareMainScreen(),
    userInfoSettings: (context) => const UserInfoSettings(),
    caregiverInfoSettings: (context) => const CaregiverInfoSettings(),
    medicalInfoSettings: (context) => const MedicalInfoSettings(),
    changePassword: (context) => const ChangePasswordScreen(),
    logInfusion: (context) => const LogInfusionScreen(),
    forgotPassword: (context) => const ForgotPassword(),
    chatbotScreen: (context) => const ChatbotScreen(),
    preScreening: (context) => const PreScreeningScreen(),
    messages: (context) => const MessagesScreen(),
    community: (context) => const CommunityScreen(),
    adminDashboard: (context) => const AdminDashboard(),
    adminSettings: (context) => const AdminSettings(),
    // Add other routes here as needed
  };
}
