import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/offline/medication_reminder.dart';
import 'notification_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalMedicationReminderService {
  static final LocalMedicationReminderService _instance =
      LocalMedicationReminderService._internal();
  factory LocalMedicationReminderService() => _instance;
  LocalMedicationReminderService._internal();

  static const String _medicationRemindersBox = 'medication_reminders';
  final NotificationService _notificationService = NotificationService();
  bool _isInitialized = false;

  /// Initialize the local medication reminder service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Register the MedicationReminder adapter if not already registered
      if (!Hive.isAdapterRegistered(4)) {
        Hive.registerAdapter(MedicationReminderAdapter());
      }

      if (!Hive.isBoxOpen(_medicationRemindersBox)) {
        await Hive.openBox<MedicationReminder>(_medicationRemindersBox);
      }
      await _notificationService.initialize();
      _isInitialized = true;
      print('✅ Local Medication Reminder Service initialized');
    } catch (e) {
      print('❌ Error initializing Local Medication Reminder Service: $e');
      rethrow;
    }
  }

  /// Save a medication reminder locally
  Future<String> saveMedicationReminder({
    required String uid,
    required String medicationName,
    required String dosage,
    required String administrationType,
    required String frequency,
    required TimeOfDay reminderTime,
    required bool notificationEnabled,
    required DateTime startDate,
    required DateTime endDate,
    String? notes,
  }) async {
    try {
      await initialize();

      final id = 'reminder_${DateTime.now().millisecondsSinceEpoch}';
      final notificationId =
          id.hashCode.abs(); // Generate unique notification ID

      final reminder = MedicationReminder(
        id: id,
        uid: uid,
        medicationName: medicationName,
        dosage: dosage,
        administrationType: administrationType,
        frequency: frequency,
        reminderTimeHour: reminderTime.hour,
        reminderTimeMinute: reminderTime.minute,
        notificationEnabled: notificationEnabled,
        startDate: startDate,
        endDate: endDate,
        notes: notes ?? '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        notificationId: notificationId,
      );

      final box = Hive.box<MedicationReminder>(_medicationRemindersBox);
      await box.put(id, reminder);

      print('💾 Medication reminder saved locally: $id');

      // Schedule local notifications if enabled
      if (notificationEnabled) {
        // Run comprehensive diagnostic
        print('🔧 Running notification diagnostics...');
        await diagnoseNotificationIssues();

        // Schedule the actual notifications
        await _scheduleNotifications(reminder);

        // Show immediate confirmation notification
        try {
          await _notificationService.showImmediateNotification(
            id: 99998,
            title: 'Medication Reminder Created',
            body:
                'Your reminder for ${reminder.medicationName} has been set up successfully!',
            payload: 'reminder_created:${reminder.id}',
          );
          print('✅ Confirmation notification sent');
        } catch (e) {
          print('❌ Confirmation notification failed: $e');
        }
      }

      return id;
    } catch (e) {
      print('❌ Error saving medication reminder locally: $e');
      rethrow;
    }
  }

  /// Get all medication reminders for a user
  Future<List<MedicationReminder>> getMedicationReminders(String uid) async {
    try {
      await initialize();

      final box = Hive.box<MedicationReminder>(_medicationRemindersBox);
      final reminders = box.values
          .where((reminder) => reminder.uid == uid && reminder.isActive)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return reminders;
    } catch (e) {
      print('❌ Error getting medication reminders: $e');
      return [];
    }
  }

  /// Get today's medication reminders for a user
  Future<List<MedicationReminder>> getTodaysMedicationReminders(
      String uid) async {
    try {
      await initialize();

      final allReminders = await getMedicationReminders(uid);
      final todaysReminders = allReminders
          .where((reminder) => reminder.shouldTakeToday())
          .toList()
        ..sort((a, b) =>
            a.todayReminderDateTime.compareTo(b.todayReminderDateTime));

      print('📋 Found ${todaysReminders.length} reminders for today');
      return todaysReminders;
    } catch (e) {
      print('❌ Error getting today\'s medication reminders: $e');
      return [];
    }
  }

  /// Mark medication as taken
  Future<void> markMedicationTaken(String reminderId) async {
    try {
      await initialize();

      final box = Hive.box<MedicationReminder>(_medicationRemindersBox);
      final reminder = box.get(reminderId);

      if (reminder != null) {
        reminder.markAsTaken();
        print('✅ Medication marked as taken: ${reminder.medicationName}');
      }
    } catch (e) {
      print('❌ Error marking medication as taken: $e');
      rethrow;
    }
  }

  /// Mark medication as not taken
  Future<void> markMedicationNotTaken(String reminderId) async {
    try {
      await initialize();

      final box = Hive.box<MedicationReminder>(_medicationRemindersBox);
      final reminder = box.get(reminderId);

      if (reminder != null) {
        reminder.markAsNotTaken();
        print('↩️ Medication marked as not taken: ${reminder.medicationName}');
      }
    } catch (e) {
      print('❌ Error marking medication as not taken: $e');
      rethrow;
    }
  }

  /// Update a medication reminder
  Future<void> updateMedicationReminder(
      String reminderId, Map<String, dynamic> updates) async {
    try {
      await initialize();

      final box = Hive.box<MedicationReminder>(_medicationRemindersBox);
      final reminder = box.get(reminderId);

      if (reminder != null) {
        // Cancel existing notifications
        if (reminder.notificationEnabled) {
          await _cancelNotifications(reminder);
        }

        // Update fields
        if (updates.containsKey('medicationName'))
          reminder.medicationName = updates['medicationName'];
        if (updates.containsKey('dosage')) reminder.dosage = updates['dosage'];
        if (updates.containsKey('administrationType'))
          reminder.administrationType = updates['administrationType'];
        if (updates.containsKey('frequency'))
          reminder.frequency = updates['frequency'];
        if (updates.containsKey('reminderTimeHour'))
          reminder.reminderTimeHour = updates['reminderTimeHour'];
        if (updates.containsKey('reminderTimeMinute'))
          reminder.reminderTimeMinute = updates['reminderTimeMinute'];
        if (updates.containsKey('notificationEnabled'))
          reminder.notificationEnabled = updates['notificationEnabled'];
        if (updates.containsKey('startDate'))
          reminder.startDate = updates['startDate'];
        if (updates.containsKey('endDate'))
          reminder.endDate = updates['endDate'];
        if (updates.containsKey('notes')) reminder.notes = updates['notes'];

        reminder.updatedAt = DateTime.now();
        reminder.save();

        // Reschedule notifications if enabled
        if (reminder.notificationEnabled) {
          await _scheduleNotifications(reminder);
        }

        print('📝 Medication reminder updated: ${reminder.medicationName}');
      }
    } catch (e) {
      print('❌ Error updating medication reminder: $e');
      rethrow;
    }
  }

  /// Delete a medication reminder
  Future<void> deleteMedicationReminder(String reminderId) async {
    try {
      await initialize();

      final box = Hive.box<MedicationReminder>(_medicationRemindersBox);
      final reminder = box.get(reminderId);

      if (reminder != null) {
        // Cancel notifications
        if (reminder.notificationEnabled) {
          await _cancelNotifications(reminder);
        }

        // Mark as inactive instead of deleting
        reminder.isActive = false;
        reminder.updatedAt = DateTime.now();
        reminder.save();

        print('🗑️ Medication reminder deleted: ${reminder.medicationName}');
      }
    } catch (e) {
      print('❌ Error deleting medication reminder: $e');
      rethrow;
    }
  }

  /// Schedule notifications for a medication reminder (offline-compatible)
  Future<void> _scheduleNotifications(MedicationReminder reminder) async {
    try {
      print(
          '🔔 Starting offline-compatible notification scheduling for ${reminder.medicationName}');

      // Try to request permissions with timeout for offline scenarios
      bool permissionsGranted = false;
      try {
        permissionsGranted = await _notificationService
            .requestPermissions()
            .timeout(Duration(seconds: 10), onTimeout: () {
          print(
              '⏰ Permission request timed out, assuming granted for offline mode');
          return true;
        });
      } catch (e) {
        print('⚠️ Permission request failed (possibly offline): $e');
        print('📱 Assuming permissions granted for offline functionality');
        permissionsGranted = true;
      }

      if (!permissionsGranted) {
        print('⚠️ Notification permissions not granted');
        return;
      }

      print('✅ Notification permissions confirmed');
      print(
          '📋 Reminder details: ${reminder.frequency} at ${reminder.reminderTime}');
      print('🌐 Scheduling in offline-compatible mode...');

      switch (reminder.frequency) {
        case 'Daily':
          print('📅 Scheduling daily repeating notification...');
          await _notificationService.scheduleRepeatingMedicationReminder(
            id: reminder.notificationId,
            title: 'Medication Reminder',
            body:
                'Time to take ${reminder.medicationName} (${reminder.dosage})',
            time: reminder.reminderTime,
            repeatInterval: RepeatInterval.daily,
            payload: 'local_medication_reminder:${reminder.id}',
          );
          break;

        case 'Once':
          final scheduledTime = DateTime(
            reminder.startDate.year,
            reminder.startDate.month,
            reminder.startDate.day,
            reminder.reminderTimeHour,
            reminder.reminderTimeMinute,
          );

          if (scheduledTime.isAfter(DateTime.now())) {
            await _notificationService.scheduleMedicationReminder(
              id: reminder.notificationId,
              title: 'Medication Reminder',
              body:
                  'Time to take ${reminder.medicationName} (${reminder.dosage})',
              scheduledTime: scheduledTime,
              payload: 'local_medication_reminder:${reminder.id}',
            );
          }
          break;

        case 'Every 3 Days':
          // Schedule multiple notifications every 3 days
          DateTime currentDate = reminder.startDate;
          int notificationCounter = 0;

          while (currentDate.isBefore(reminder.endDate) ||
              currentDate.isAtSameMomentAs(reminder.endDate)) {
            final scheduledTime = DateTime(
              currentDate.year,
              currentDate.month,
              currentDate.day,
              reminder.reminderTimeHour,
              reminder.reminderTimeMinute,
            );

            if (scheduledTime.isAfter(DateTime.now())) {
              await _notificationService.scheduleMedicationReminder(
                id: reminder.notificationId + notificationCounter,
                title: 'Medication Reminder',
                body:
                    'Time to take ${reminder.medicationName} (${reminder.dosage})',
                scheduledTime: scheduledTime,
                payload: 'local_medication_reminder:${reminder.id}',
              );
              notificationCounter++;
            }

            currentDate = currentDate.add(const Duration(days: 3));
          }
          break;
      }

      print('🔔 Notifications scheduled for ${reminder.medicationName}');

      // Debug: Show all pending notifications
      await _notificationService.debugPendingNotifications();
    } catch (e) {
      print('❌ Error scheduling notifications: $e');
    }
  }

  /// Cancel notifications for a medication reminder
  Future<void> _cancelNotifications(MedicationReminder reminder) async {
    try {
      await _notificationService.cancelNotification(reminder.notificationId);

      // For 'Every 3 Days', we might have multiple notifications
      if (reminder.frequency == 'Every 3 Days') {
        // Cancel up to 100 potential notifications (should be more than enough)
        for (int i = 0; i < 100; i++) {
          await _notificationService
              .cancelNotification(reminder.notificationId + i);
        }
      }

      print('🔕 Notifications cancelled for ${reminder.medicationName}');
    } catch (e) {
      print('❌ Error cancelling notifications: $e');
    }
  }

  /// Clear all medication reminders (for testing or reset)
  Future<void> clearAllReminders() async {
    try {
      await initialize();

      final box = Hive.box<MedicationReminder>(_medicationRemindersBox);

      // Cancel all notifications first
      for (final reminder in box.values) {
        if (reminder.notificationEnabled) {
          await _cancelNotifications(reminder);
        }
      }

      await box.clear();
      print('🧹 All medication reminders cleared');
    } catch (e) {
      print('❌ Error clearing all reminders: $e');
      rethrow;
    }
  }

  /// Get reminder statistics
  Future<Map<String, int>> getReminderStatistics(String uid) async {
    try {
      await initialize();

      final reminders = await getMedicationReminders(uid);
      final todaysReminders = await getTodaysMedicationReminders(uid);

      final takenToday = todaysReminders.where((r) => r.isTakenToday).length;
      final pendingToday = todaysReminders.where((r) => !r.isTakenToday).length;

      return {
        'total': reminders.length,
        'active': reminders.where((r) => r.isActiveToday).length,
        'todayTotal': todaysReminders.length,
        'todayTaken': takenToday,
        'todayPending': pendingToday,
      };
    } catch (e) {
      print('❌ Error getting reminder statistics: $e');
      return {};
    }
  }

  /// Comprehensive notification diagnostic method
  Future<Map<String, dynamic>> diagnoseNotificationIssues() async {
    final results = <String, dynamic>{};

    try {
      await initialize();
      results['service_initialized'] = true;

      // Test notification service initialization
      await _notificationService.initialize();
      results['notification_service_initialized'] = true;

      // Test permissions
      final permissions = await _notificationService.requestPermissions();
      results['permissions_granted'] = permissions;

      // Check pending notifications
      try {
        final pending = await _notificationService.getPendingNotifications();
        results['pending_notifications_count'] = pending.length;
        results['pending_notifications'] = pending
            .map((n) => {
                  'id': n.id,
                  'title': n.title,
                  'body': n.body,
                  'payload': n.payload,
                })
            .toList();
      } catch (e) {
        results['pending_notifications'] = 'failed: $e';
      }

      results['diagnosis'] = 'completed successfully';
    } catch (e) {
      results['error'] = e.toString();
      results['diagnosis'] = 'failed';
    }

    // Print results for debugging
    print('=== NOTIFICATION DIAGNOSIS ===');
    results.forEach((key, value) {
      print('$key: $value');
    });
    print('=== END DIAGNOSIS ===');

    return results;
  }

  /// Send a test notification to verify the system is working
  Future<void> sendTestNotification() async {
    try {
      await initialize();
      print('🧪 Testing local notification...');

      await _notificationService.showImmediateNotification(
        id: 999999,
        title: 'Test Notification',
        body: 'This is a test notification from Flutter Local Notifications',
        payload: 'test_notification',
      );
      print('✅ Test notification sent successfully');
    } catch (e) {
      print('❌ Error sending test notification: $e');
      rethrow;
    }
  }
}
