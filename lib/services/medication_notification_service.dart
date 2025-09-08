import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/offline/medication_reminder.dart';
import '../services/firestore.dart';

class MedicationNotificationService {
  static final MedicationNotificationService _instance =
      MedicationNotificationService._internal();
  factory MedicationNotificationService() => _instance;
  MedicationNotificationService._internal();

  static const String _medicationRemindersBox = 'medication_reminders';
  final FirestoreService _firestoreService = FirestoreService();
  Timer? _reminderCheckTimer;
  bool _isInitialized = false;

  /// Initialize the medication notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Start periodic check for due medications
      await _startPeriodicReminderCheck();
      _isInitialized = true;
      print('✅ Medication Notification Service initialized');
    } catch (e) {
      print('❌ Error initializing Medication Notification Service: $e');
    }
  }

  /// Start periodic checking for due medication reminders
  Future<void> _startPeriodicReminderCheck() async {
    // Cancel existing timer if any
    _reminderCheckTimer?.cancel();

    // Check every 5 minutes for due medications
    _reminderCheckTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _checkForDueMedications();
    });

    // Also check immediately when starting
    await _checkForDueMedications();
  }

  /// Check for due medication reminders and create in-app notifications
  Future<void> _checkForDueMedications() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final uid = user.uid;
      final now = DateTime.now();
      final currentTime = TimeOfDay.fromDateTime(now);

      if (!Hive.isBoxOpen(_medicationRemindersBox)) {
        await Hive.openBox<MedicationReminder>(_medicationRemindersBox);
      }

      final box = Hive.box<MedicationReminder>(_medicationRemindersBox);
      final allReminders = box.values
          .where(
              (reminder) => reminder.uid == uid && reminder.notificationEnabled)
          .toList();

      for (final reminder in allReminders) {
        if (await _shouldCreateNotification(reminder, now, currentTime)) {
          await _createInAppNotification(reminder);
        }
      }
    } catch (e) {
      print('Error checking for due medications: $e');
    }
  }

  /// Determine if a notification should be created for this reminder
  Future<bool> _shouldCreateNotification(
    MedicationReminder reminder,
    DateTime now,
    TimeOfDay currentTime,
  ) async {
    try {
      // Check if reminder is within active date range
      if (now.isBefore(reminder.startDate) || now.isAfter(reminder.endDate)) {
        return false;
      }

      final reminderTime = TimeOfDay(
        hour: reminder.reminderTimeHour,
        minute: reminder.reminderTimeMinute,
      );

      // Check if current time matches reminder time (within 5-minute window)
      final currentMinutes = currentTime.hour * 60 + currentTime.minute;
      final reminderMinutes = reminderTime.hour * 60 + reminderTime.minute;
      final timeDifference = (currentMinutes - reminderMinutes).abs();

      if (timeDifference > 5) {
        return false; // Not within the 5-minute window
      }

      // Check frequency
      if (!_shouldNotifyBasedOnFrequency(reminder, now)) {
        return false;
      }

      // Check if we already sent a notification today for this reminder
      final lastNotificationKey = 'last_notification_${reminder.id}';
      final box = await Hive.openBox('notification_tracking');
      final lastNotificationDate = box.get(lastNotificationKey);

      if (lastNotificationDate != null) {
        final lastDate = DateTime.parse(lastNotificationDate);
        final today = DateTime(now.year, now.month, now.day);
        final lastDateDay =
            DateTime(lastDate.year, lastDate.month, lastDate.day);

        if (today.isAtSameMomentAs(lastDateDay)) {
          return false; // Already notified today
        }
      }

      return true;
    } catch (e) {
      print('Error checking notification criteria: $e');
      return false;
    }
  }

  /// Check if reminder should notify based on frequency
  bool _shouldNotifyBasedOnFrequency(
      MedicationReminder reminder, DateTime now) {
    switch (reminder.frequency.toLowerCase()) {
      case 'once':
        // Only notify on start date
        final startDay = DateTime(
          reminder.startDate.year,
          reminder.startDate.month,
          reminder.startDate.day,
        );
        final todayDay = DateTime(now.year, now.month, now.day);
        return startDay.isAtSameMomentAs(todayDay);

      case 'daily':
        // Notify every day within the date range
        return true;

      case 'every 3 days':
        // Notify every 3 days starting from start date
        final daysDifference = now.difference(reminder.startDate).inDays;
        return daysDifference >= 0 && daysDifference % 3 == 0;

      default:
        return true;
    }
  }

  /// Create an in-app notification for the medication reminder
  Future<void> _createInAppNotification(MedicationReminder reminder) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final reminderTime = TimeOfDay(
        hour: reminder.reminderTimeHour,
        minute: reminder.reminderTimeMinute,
      );

      // Format time as 24-hour format
      final timeString =
          '${reminderTime.hour.toString().padLeft(2, '0')}:${reminderTime.minute.toString().padLeft(2, '0')}';

      await _firestoreService.createNotificationWithData(
        uid: user.uid,
        text: '💊 Time for your ${reminder.medicationName}!\n'
            '${reminder.dosage} - ${reminder.administrationType}\n'
            'Scheduled for $timeString',
        type: 'medication_reminder',
        data: {
          'reminderId': reminder.id,
          'medicationName': reminder.medicationName,
          'dosage': reminder.dosage,
          'administrationType': reminder.administrationType,
          'scheduledTime': timeString,
          'frequency': reminder.frequency,
        },
      );

      // Track that we sent a notification for this reminder today
      final lastNotificationKey = 'last_notification_${reminder.id}';
      final box = await Hive.openBox('notification_tracking');
      await box.put(lastNotificationKey, DateTime.now().toIso8601String());

      print(
          '✅ In-app notification created for medication: ${reminder.medicationName}');
    } catch (e) {
      print('Error creating in-app notification: $e');
    }
  }

  /// Manually check for due medications (can be called from UI)
  Future<void> checkNow() async {
    await _checkForDueMedications();
  }

  /// Stop the periodic reminder check
  void dispose() {
    _reminderCheckTimer?.cancel();
    _reminderCheckTimer = null;
    _isInitialized = false;
  }
}
