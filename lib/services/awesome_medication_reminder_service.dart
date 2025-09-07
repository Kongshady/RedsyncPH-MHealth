import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/offline/medication_reminder.dart';
import 'awesome_notification_service.dart';

class AwesomeMedicationReminderService {
  static final AwesomeMedicationReminderService _instance =
      AwesomeMedicationReminderService._internal();
  factory AwesomeMedicationReminderService() => _instance;
  AwesomeMedicationReminderService._internal();

  static const String _medicationRemindersBox = 'medication_reminders';
  final AwesomeNotificationService _notificationService =
      AwesomeNotificationService();
  bool _isInitialized = false;

  /// Initialize the awesome medication reminder service
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
      print('✅ Awesome Medication Reminder Service initialized');
    } catch (e) {
      print('❌ Error initializing Awesome Medication Reminder Service: $e');
      rethrow;
    }
  }

  /// Save a medication reminder locally with awesome notifications
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

      final box = Hive.box<MedicationReminder>(_medicationRemindersBox);

      // Generate unique ID and notification ID
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      final notificationId = DateTime.now().millisecondsSinceEpoch;

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
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        notificationId: notificationId,
      );

      await box.put(id, reminder);
      print('✅ Medication reminder saved locally: $medicationName');

      // Schedule notifications if enabled
      if (notificationEnabled) {
        await _scheduleAwesomeNotifications(reminder);
      }

      return id;
    } catch (e) {
      print('❌ Error saving medication reminder: $e');
      rethrow;
    }
  }

  /// Get all medication reminders for a user
  Future<List<MedicationReminder>> getMedicationReminders(String uid) async {
    try {
      await initialize();

      final box = Hive.box<MedicationReminder>(_medicationRemindersBox);
      return box.values
          .where((reminder) => reminder.uid == uid && reminder.isActive)
          .toList();
    } catch (e) {
      print('❌ Error getting medication reminders: $e');
      return [];
    }
  }

  /// Get a specific medication reminder by ID
  Future<MedicationReminder?> getMedicationReminder(String id) async {
    try {
      await initialize();

      final box = Hive.box<MedicationReminder>(_medicationRemindersBox);
      return box.get(id);
    } catch (e) {
      print('❌ Error getting medication reminder: $e');
      return null;
    }
  }

  /// Update a medication reminder
  Future<void> updateMedicationReminder(MedicationReminder reminder) async {
    try {
      await initialize();

      final box = Hive.box<MedicationReminder>(_medicationRemindersBox);
      await box.put(reminder.id, reminder);

      // Cancel existing notifications and reschedule if notifications are enabled
      await _notificationService.cancelNotification(reminder.notificationId);
      if (reminder.notificationEnabled && reminder.isActive) {
        await _scheduleAwesomeNotifications(reminder);
      }

      print('✅ Medication reminder updated: ${reminder.medicationName}');
    } catch (e) {
      print('❌ Error updating medication reminder: $e');
      rethrow;
    }
  }

  /// Delete a medication reminder
  Future<void> deleteMedicationReminder(String id) async {
    try {
      await initialize();

      final box = Hive.box<MedicationReminder>(_medicationRemindersBox);
      final reminder = box.get(id);

      if (reminder != null) {
        // Cancel associated notifications
        await _notificationService.cancelNotification(reminder.notificationId);

        // Mark as inactive instead of deleting (for audit trail)
        reminder.isActive = false;
        await box.put(id, reminder);

        print('✅ Medication reminder deleted: ${reminder.medicationName}');
      }
    } catch (e) {
      print('❌ Error deleting medication reminder: $e');
      rethrow;
    }
  }

  /// Schedule awesome notifications for a medication reminder
  Future<void> _scheduleAwesomeNotifications(
      MedicationReminder reminder) async {
    try {
      print(
          '🔔 Starting awesome notification scheduling for ${reminder.medicationName}');

      // Request permissions
      bool permissionsGranted = false;
      try {
        permissionsGranted = await _notificationService.requestPermissions();
      } catch (e) {
        print('⚠️ Permission request failed: $e');
        print('📱 Attempting to schedule anyway...');
        permissionsGranted = true;
      }

      if (!permissionsGranted) {
        print('⚠️ Notification permissions not granted');
        return;
      }

      print('✅ Notification permissions confirmed');
      print(
          '📋 Reminder details: ${reminder.frequency} at ${reminder.reminderTime}');

      switch (reminder.frequency) {
        case 'Daily':
          print('📅 Scheduling daily repeating notification...');
          await _notificationService.scheduleRepeatingMedicationReminder(
            id: reminder.notificationId,
            title: 'Medication Reminder',
            body:
                'Time to take ${reminder.medicationName} (${reminder.dosage})',
            time: reminder.reminderTime,
            repeatInterval: 'daily',
            payload: 'medication_reminder:${reminder.id}',
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
              payload: 'medication_reminder:${reminder.id}',
            );
          }
          break;

        case 'Every 3 Days':
          // Schedule multiple notifications every 3 days
          DateTime currentDate = reminder.startDate;
          int notificationCounter = 0;
          const int maxNotifications =
              10; // Limit to prevent too many scheduled notifications

          while (currentDate.isBefore(reminder.endDate) ||
              currentDate.isAtSameMomentAs(reminder.endDate)) {
            if (notificationCounter >= maxNotifications) break;

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
                payload: 'medication_reminder:${reminder.id}',
              );
              notificationCounter++;
            }

            currentDate = currentDate.add(const Duration(days: 3));
          }
          break;

        case 'Weekly':
          print('📅 Scheduling weekly repeating notification...');
          await _notificationService.scheduleRepeatingMedicationReminder(
            id: reminder.notificationId,
            title: 'Medication Reminder',
            body:
                'Time to take ${reminder.medicationName} (${reminder.dosage})',
            time: reminder.reminderTime,
            repeatInterval: 'weekly',
            payload: 'medication_reminder:${reminder.id}',
          );
          break;

        case 'Every Other Day':
          // Schedule multiple notifications every other day
          DateTime currentDate = reminder.startDate;
          int notificationCounter = 0;
          const int maxNotifications =
              15; // Limit to prevent too many scheduled notifications

          while (currentDate.isBefore(reminder.endDate) ||
              currentDate.isAtSameMomentAs(reminder.endDate)) {
            if (notificationCounter >= maxNotifications) break;

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
                payload: 'medication_reminder:${reminder.id}',
              );
              notificationCounter++;
            }

            currentDate = currentDate.add(const Duration(days: 2));
          }
          break;

        default:
          print(
              '⚠️ Unknown frequency: ${reminder.frequency}, defaulting to daily');
          await _notificationService.scheduleRepeatingMedicationReminder(
            id: reminder.notificationId,
            title: 'Medication Reminder',
            body:
                'Time to take ${reminder.medicationName} (${reminder.dosage})',
            time: reminder.reminderTime,
            repeatInterval: 'daily',
            payload: 'medication_reminder:${reminder.id}',
          );
      }

      print(
          '✅ Awesome notifications scheduled successfully for ${reminder.medicationName}');
    } catch (e) {
      print('❌ Error scheduling awesome notifications: $e');
      // Don't rethrow to prevent app crashes - just log the error
    }
  }

  /// Reschedule all active notifications (useful after app restart)
  Future<void> rescheduleAllNotifications(String uid) async {
    try {
      print('🔄 Rescheduling all notifications for user: $uid');

      final reminders = await getMedicationReminders(uid);
      for (final reminder in reminders) {
        if (reminder.notificationEnabled && reminder.isActive) {
          await _scheduleAwesomeNotifications(reminder);
        }
      }

      print('✅ All notifications rescheduled');
    } catch (e) {
      print('❌ Error rescheduling notifications: $e');
    }
  }

  /// Get diagnostic information about the service
  Future<Map<String, dynamic>> getDiagnosticInfo(String uid) async {
    final results = <String, dynamic>{};

    try {
      await initialize();

      results['service_initialized'] = _isInitialized;
      results['notification_service_initialized'] = true;

      // Get reminders count
      final reminders = await getMedicationReminders(uid);
      results['total_reminders'] = reminders.length;
      results['active_reminders'] = reminders.where((r) => r.isActive).length;
      results['notification_enabled_reminders'] =
          reminders.where((r) => r.notificationEnabled && r.isActive).length;

      // Get scheduled notifications count
      final scheduledNotifications =
          await _notificationService.getScheduledNotifications();
      results['scheduled_notifications_count'] = scheduledNotifications.length;

      results['hive_box_open'] = Hive.isBoxOpen(_medicationRemindersBox);

      if (Hive.isBoxOpen(_medicationRemindersBox)) {
        final box = Hive.box<MedicationReminder>(_medicationRemindersBox);
        results['hive_box_length'] = box.length;
      }

      print('📊 Diagnostic info: $results');
    } catch (e) {
      results['error'] = e.toString();
      print('❌ Error getting diagnostic info: $e');
    }

    return results;
  }

  /// Test notification (for debugging)
  Future<void> sendTestNotification() async {
    try {
      // Ensure the service is initialized
      await initialize();

      print('🧪 Testing awesome notification...');

      // Check if notifications are allowed
      bool isAllowed = await _notificationService.requestPermissions();
      if (!isAllowed) {
        throw Exception('Notification permissions not granted');
      }

      print('🔔 Permissions granted, sending test notification...');

      await _notificationService.showInstantNotification(
        id: 999999,
        title: 'Test Notification',
        body: 'This is a test notification from Awesome Notifications',
        payload: 'test_notification',
        channelKey: 'medication_reminders',
      );
      print('✅ Test notification sent successfully');
    } catch (e) {
      print('❌ Error sending test notification: $e');
      rethrow;
    }
  }
}
