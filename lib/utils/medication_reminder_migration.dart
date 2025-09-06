import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hemophilia_manager/services/firestore.dart';
import 'package:hemophilia_manager/services/local_medication_reminder_service.dart';

/// Migration utility to help users transition from Firebase to local reminders
class MedicationReminderMigration {
  static final FirestoreService _firestoreService = FirestoreService();
  static final LocalMedicationReminderService _localService =
      LocalMedicationReminderService();

  /// Clear all Firebase medication reminders for current user
  /// This is optional and only needed if users want a clean slate
  static Future<void> clearFirebaseReminders() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('No user logged in');
        return;
      }

      // Get all Firebase reminders
      final firebaseReminders =
          await _firestoreService.getMedicationSchedules(user.uid);

      print('Found ${firebaseReminders.length} Firebase reminders to clear');

      // Delete each reminder
      for (final reminder in firebaseReminders) {
        try {
          await _firestoreService.deleteMedicationSchedule(reminder['id']);
          print('Deleted Firebase reminder: ${reminder['medicationName']}');
        } catch (e) {
          print('Error deleting reminder ${reminder['id']}: $e');
        }
      }

      print('✅ Firebase reminders cleanup completed');
    } catch (e) {
      print('❌ Error clearing Firebase reminders: $e');
      rethrow;
    }
  }

  /// Show migration status to user
  static Future<Map<String, dynamic>> getMigrationStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return {
          'error': 'No user logged in',
          'firebaseCount': 0,
          'localCount': 0,
        };
      }

      await _localService.initialize();

      // Count Firebase reminders
      final firebaseReminders =
          await _firestoreService.getMedicationSchedules(user.uid);
      final firebaseCount = firebaseReminders.length;

      // Count local reminders
      final localReminders =
          await _localService.getMedicationReminders(user.uid);
      final localCount = localReminders.length;

      // Count today's reminders
      final todaysLocalReminders =
          await _localService.getTodaysMedicationReminders(user.uid);
      final todaysLocalCount = todaysLocalReminders.length;

      return {
        'firebaseCount': firebaseCount,
        'localCount': localCount,
        'todaysLocalCount': todaysLocalCount,
        'migrationRecommended': firebaseCount > 0,
        'status': firebaseCount > 0
            ? 'You have $firebaseCount Firebase reminders and $localCount local reminders'
            : 'You are using the new local reminder system with $localCount reminders',
      };
    } catch (e) {
      print('Error getting migration status: $e');
      return {
        'error': e.toString(),
        'firebaseCount': 0,
        'localCount': 0,
      };
    }
  }

  /// Optional: Import Firebase reminders to local storage
  /// This creates local copies of existing Firebase reminders
  static Future<void> importFirebaseToLocal() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('No user logged in');
        return;
      }

      await _localService.initialize();

      // Get all Firebase reminders
      final firebaseReminders =
          await _firestoreService.getMedicationSchedules(user.uid);

      print(
          'Importing ${firebaseReminders.length} Firebase reminders to local storage');

      int importedCount = 0;
      for (final reminder in firebaseReminders) {
        try {
          final reminderTime = TimeOfDay(
            hour: reminder['reminderTimeHour'] ?? 9,
            minute: reminder['reminderTimeMinute'] ?? 0,
          );

          final startDate = reminder['startDate']?.toDate() ?? DateTime.now();
          final endDate = reminder['endDate']?.toDate() ??
              DateTime.now().add(const Duration(days: 7));

          final localReminderId = await _localService.saveMedicationReminder(
            uid: user.uid,
            medicationName: reminder['medicationName'] ?? 'Unknown',
            dosage: reminder['dosage'] ?? 'Unknown',
            administrationType: reminder['administrationType'] ?? 'Unknown',
            frequency: reminder['frequency'] ?? 'Daily',
            reminderTime: reminderTime,
            notificationEnabled: reminder['notificationEnabled'] ?? true,
            startDate: startDate,
            endDate: endDate,
            notes: reminder['notes'] ?? '',
          );

          print(
              'Imported reminder: ${reminder['medicationName']} -> $localReminderId');
          importedCount++;
        } catch (e) {
          print('Error importing reminder ${reminder['medicationName']}: $e');
        }
      }

      print(
          '✅ Successfully imported $importedCount reminders to local storage');
    } catch (e) {
      print('❌ Error importing Firebase reminders: $e');
      rethrow;
    }
  }

  /// Complete migration: Import then clear Firebase
  /// Use with caution - this will delete Firebase data
  static Future<void> completeIncompleteMigration() async {
    try {
      print('🔄 Starting complete migration...');

      await importFirebaseToLocal();
      print('✅ Import completed');

      await clearFirebaseReminders();
      print('✅ Firebase cleanup completed');

      print('🎉 Migration completed successfully!');
    } catch (e) {
      print('❌ Migration failed: $e');
      rethrow;
    }
  }

  /// Widget to show migration status in UI
  static Widget buildMigrationStatusWidget(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: getMigrationStatus(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError || snapshot.data?['error'] != null) {
          return Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.error, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Migration Status Error',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(snapshot.data?['error'] ?? 'Unknown error'),
              ],
            ),
          );
        }

        final data = snapshot.data!;
        final firebaseCount = data['firebaseCount'] as int;
        final localCount = data['localCount'] as int;
        final migrationRecommended = data['migrationRecommended'] as bool;

        return Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: migrationRecommended
                ? Colors.orange.shade50
                : Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: migrationRecommended
                  ? Colors.orange.shade200
                  : Colors.green.shade200,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    migrationRecommended ? Icons.info : Icons.check_circle,
                    color: migrationRecommended ? Colors.orange : Colors.green,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Medication Reminders Status',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(data['status'] as String),
              if (migrationRecommended) ...[
                const SizedBox(height: 12),
                const Text(
                  'You are using the new local reminder system! Your reminders are now stored locally for better offline support and no more unending reminders.',
                  style: TextStyle(color: Colors.black87),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Firebase reminders (if any) will continue to work but new reminders will be local only.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
