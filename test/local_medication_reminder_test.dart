import 'package:flutter_test/flutter_test.dart';
import 'package:hemophilia_manager/services/local_medication_reminder_service.dart';
import 'package:hemophilia_manager/models/offline/medication_reminder.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() {
  group('Local Medication Reminder Service Tests', () {
    late LocalMedicationReminderService service;

    setUpAll(() async {
      // Initialize Hive for testing
      await Hive.initFlutter();

      // Register adapter
      if (!Hive.isAdapterRegistered(4)) {
        Hive.registerAdapter(MedicationReminderAdapter());
      }
    });

    setUp(() async {
      service = LocalMedicationReminderService();
      await service.initialize();

      // Clear any existing test data
      await service.clearAllReminders();
    });

    tearDown(() async {
      // Clean up after each test
      await service.clearAllReminders();
    });

    test('should save medication reminder locally', () async {
      final reminderId = await service.saveMedicationReminder(
        uid: 'test_user',
        medicationName: 'Test Medicine',
        dosage: '10mg',
        administrationType: 'Oral',
        frequency: 'Daily',
        reminderTime: const TimeOfDay(hour: 9, minute: 0),
        notificationEnabled: true,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 7)),
        notes: 'Test notes',
      );

      expect(reminderId, isNotNull);
      expect(reminderId.startsWith('reminder_'), isTrue);
    });

    test('should retrieve medication reminders for user', () async {
      // Save a test reminder
      await service.saveMedicationReminder(
        uid: 'test_user',
        medicationName: 'Test Medicine',
        dosage: '10mg',
        administrationType: 'Oral',
        frequency: 'Daily',
        reminderTime: const TimeOfDay(hour: 9, minute: 0),
        notificationEnabled: true,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 7)),
        notes: 'Test notes',
      );

      final reminders = await service.getMedicationReminders('test_user');
      expect(reminders.length, equals(1));
      expect(reminders.first.medicationName, equals('Test Medicine'));
      expect(reminders.first.uid, equals('test_user'));
    });

    test('should get today\'s medication reminders', () async {
      // Save a test reminder for today
      await service.saveMedicationReminder(
        uid: 'test_user',
        medicationName: 'Daily Medicine',
        dosage: '5mg',
        administrationType: 'Oral',
        frequency: 'Daily',
        reminderTime: const TimeOfDay(hour: 10, minute: 0),
        notificationEnabled: true,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 7)),
        notes: 'Daily medication',
      );

      final todaysReminders =
          await service.getTodaysMedicationReminders('test_user');
      expect(todaysReminders.length, equals(1));
      expect(todaysReminders.first.medicationName, equals('Daily Medicine'));
      expect(todaysReminders.first.shouldTakeToday(), isTrue);
    });

    test('should mark medication as taken', () async {
      // Save a test reminder
      final reminderId = await service.saveMedicationReminder(
        uid: 'test_user',
        medicationName: 'Test Medicine',
        dosage: '10mg',
        administrationType: 'Oral',
        frequency: 'Daily',
        reminderTime: const TimeOfDay(hour: 9, minute: 0),
        notificationEnabled: true,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 7)),
        notes: 'Test notes',
      );

      // Mark as taken
      await service.markMedicationTaken(reminderId);

      // Verify it's marked as taken
      final reminders = await service.getMedicationReminders('test_user');
      expect(reminders.first.isTakenToday, isTrue);
    });

    test('should handle different frequencies correctly', () async {
      // Test Once frequency
      final onceReminderId = await service.saveMedicationReminder(
        uid: 'test_user',
        medicationName: 'Once Medicine',
        dosage: '20mg',
        administrationType: 'Oral',
        frequency: 'Once',
        reminderTime: const TimeOfDay(hour: 9, minute: 0),
        notificationEnabled: true,
        startDate: DateTime.now(),
        endDate: DateTime.now(),
        notes: 'One time only',
      );

      // Test Every 3 Days frequency
      final every3DaysReminderId = await service.saveMedicationReminder(
        uid: 'test_user',
        medicationName: 'Every 3 Days Medicine',
        dosage: '15mg',
        administrationType: 'IV Injection',
        frequency: 'Every 3 Days',
        reminderTime: const TimeOfDay(hour: 14, minute: 30),
        notificationEnabled: true,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 14)),
        notes: 'Every 3 days',
      );

      final reminders = await service.getMedicationReminders('test_user');
      expect(reminders.length, equals(2));

      final onceReminder = reminders.firstWhere((r) => r.id == onceReminderId);
      final every3DaysReminder =
          reminders.firstWhere((r) => r.id == every3DaysReminderId);

      expect(onceReminder.frequency, equals('Once'));
      expect(every3DaysReminder.frequency, equals('Every 3 Days'));
    });

    test('should get reminder statistics', () async {
      // Save multiple reminders
      await service.saveMedicationReminder(
        uid: 'test_user',
        medicationName: 'Medicine 1',
        dosage: '10mg',
        administrationType: 'Oral',
        frequency: 'Daily',
        reminderTime: const TimeOfDay(hour: 9, minute: 0),
        notificationEnabled: true,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 7)),
        notes: 'Medicine 1',
      );

      await service.saveMedicationReminder(
        uid: 'test_user',
        medicationName: 'Medicine 2',
        dosage: '20mg',
        administrationType: 'Oral',
        frequency: 'Daily',
        reminderTime: const TimeOfDay(hour: 18, minute: 0),
        notificationEnabled: true,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 7)),
        notes: 'Medicine 2',
      );

      final stats = await service.getReminderStatistics('test_user');
      expect(stats['total'], equals(2));
      expect(stats['active'], equals(2));
      expect(stats['todayTotal'], equals(2));
      expect(stats['todayTaken'], equals(0));
      expect(stats['todayPending'], equals(2));
    });
  });
}
