import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // USER METHODS
  // Create
  Future<void> createUser(
    String uid,
    String name,
    String email,
    String role,
  ) async {
    await _db.collection('users').doc(uid).set({
      'name': name,
      'email': email,
      'role': role,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Read
  Future<Map<String, dynamic>?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.exists ? doc.data() : null;
  }

  // Update
  Future<void> updateUser(
    String uid,
    String name,
    String email,
    String? role, {
    Map<String, dynamic>? extra,
  }) async {
    final data = {
      'name': name,
      'email': email,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (role != null) data['role'] = role;
    if (extra != null) {
      data.addAll(extra.map((key, value) => MapEntry(key, value)));
    }
    await _db.collection('users').doc(uid).update(data);
  }

  // Delete
  Future<void> deleteUser(String uid) async {
    await _db.collection('users').doc(uid).delete();
  }

  // Check and delete expired unverified medical accounts
  Future<void> cleanupExpiredUnverifiedAccounts() async {
    try {
      final now = DateTime.now();
      final snapshot = await _db
          .collection('users')
          .where('role', isEqualTo: 'medical')
          .where('isVerified', isEqualTo: false)
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final verificationExpiry = data['verificationExpiry'] as String?;

        if (verificationExpiry != null) {
          final expiryDate = DateTime.parse(verificationExpiry);
          if (now.isAfter(expiryDate)) {
            // Delete expired unverified account
            await deleteUser(doc.id);
            print('Deleted expired unverified account: ${doc.id}');
          }
        }
      }
    } catch (e) {
      print('Error cleaning up expired accounts: $e');
    }
  }

  // Get user profile with hemophilia type
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      print('Error getting user profile: $e');
      rethrow;
    }
  }

  // Get user role for login routing
  Future<String?> getUserRole(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data();
        return data?['role'] as String?;
      }
      return null;
    } catch (e) {
      print('Error getting user role: $e');
      rethrow;
    }
  }

  // =============================================================================================================

  // NOTIFICATION METHODS
  Future<void> createNotification(String uid, String text) async {
    await _db.collection('notifications').add({
      'uid': uid,
      'text': text,
      'read': false,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // Enhanced notification creation with navigation data
  Future<void> createNotificationWithData({
    required String uid,
    required String text,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    await _db.collection('notifications').add({
      'uid': uid,
      'text': text,
      'type': type,
      'data': data ?? {},
      'read': false,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getNotifications(String uid) {
    try {
      if (uid.isEmpty) {
        throw Exception('User ID is empty');
      }
      return _db
          .collection('notifications')
          .where('uid', isEqualTo: uid)
          .orderBy('timestamp', descending: true)
          .snapshots();
    } catch (e) {
      print('Error in getNotifications: $e');
      rethrow;
    }
  }

  // Get unread notification count stream
  Stream<int> getUnreadNotificationCount(String uid) {
    try {
      if (uid.isEmpty) {
        return Stream.value(0);
      }
      return _db
          .collection('notifications')
          .where('uid', isEqualTo: uid)
          .where('read', isEqualTo: false)
          .snapshots()
          .map((snapshot) => snapshot.docs.length);
    } catch (e) {
      print('Error in getUnreadNotificationCount: $e');
      return Stream.value(0);
    }
  }

  Future<void> markAllNotificationsAsRead(String uid) async {
    try {
      if (uid.isEmpty) return;

      final notifications = await _db
          .collection('notifications')
          .where('uid', isEqualTo: uid)
          .where('read', isEqualTo: false)
          .get();

      if (notifications.docs.isEmpty) return;

      final batch = _db.batch();
      for (var doc in notifications.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
    } catch (e) {
      print('Error marking notifications as read: $e');
      rethrow;
    }
  }

  Future<void> deleteAllNotifications(String uid) async {
    try {
      if (uid.isEmpty) return;

      final notifications = await _db
          .collection('notifications')
          .where('uid', isEqualTo: uid)
          .get();

      if (notifications.docs.isEmpty) return;

      final batch = _db.batch();
      for (var doc in notifications.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      print('Error deleting notifications: $e');
      rethrow;
    }
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    await _db.collection('notifications').doc(notificationId).update({
      'read': true,
    });
  }

  // =============================================================================================================

  // HEALTHCARE PROVIDER METHODS
  Stream<QuerySnapshot> getHealthcareProviders() {
    try {
      return _db
          .collection('users')
          .where('role', isEqualTo: 'medical')
          // Removed .orderBy('name') to avoid composite index requirement
          .snapshots();
    } catch (e) {
      print('Error getting healthcare providers: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> searchHealthcareProviders(
    String query,
  ) async {
    try {
      final snapshot = await _db
          .collection('users')
          .where('role', isEqualTo: 'medical')
          .where('isVerified',
              isEqualTo: true) // Only show verified medical professionals
          .get();

      final providers = snapshot.docs
          .map((doc) => {...doc.data(), 'id': doc.id})
          .where((provider) {
        final name = provider['name']?.toString().toLowerCase() ?? '';
        return name.contains(query.toLowerCase());
      }).toList();

      return providers;
    } catch (e) {
      print('Error searching healthcare providers: $e');
      rethrow;
    }
  }

  // EMERGENCY CONTACT METHODS
  Future<void> addEmergencyContact(
    String patientUid,
    String contactPhone,
  ) async {
    try {
      // Check if emergency contact already exists
      final existing = await _db
          .collection('emergency_contacts')
          .where('patientUid', isEqualTo: patientUid)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        throw Exception(
          'Emergency contact already exists. You can only have one emergency contact.',
        );
      }

      await _db.collection('emergency_contacts').add({
        'patientUid': patientUid,
        'contactPhone': contactPhone,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error adding emergency contact: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getEmergencyContact(String patientUid) async {
    try {
      final snapshot = await _db
          .collection('emergency_contacts')
          .where('patientUid', isEqualTo: patientUid)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return {'id': snapshot.docs.first.id, ...snapshot.docs.first.data()};
      }
      return null;
    } catch (e) {
      print('Error getting emergency contact: $e');
      rethrow;
    }
  }

  Future<void> updateEmergencyContact(String contactId, String newPhone) async {
    try {
      await _db.collection('emergency_contacts').doc(contactId).update({
        'contactPhone': newPhone,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating emergency contact: $e');
      rethrow;
    }
  }

  Future<void> deleteEmergencyContact(String contactId) async {
    try {
      await _db.collection('emergency_contacts').doc(contactId).delete();
    } catch (e) {
      print('Error deleting emergency contact: $e');
      rethrow;
    }
  }

  Stream<QuerySnapshot> getEmergencyContacts(String patientUid) {
    try {
      return _db
          .collection('emergency_contacts')
          .where('patientUid', isEqualTo: patientUid)
          // Remove .orderBy to avoid index requirement
          .snapshots();
    } catch (e) {
      print('Error getting emergency contacts: $e');
      rethrow;
    }
  }

  // DOSAGE CALCULATION METHODS

  // Save dosage calculation to history
  Future<String> saveDosageCalculation({
    required String uid,
    required String hemophiliaType,
    required double weight,
    required double targetFactorLevel,
    required double calculatedDosage,
    String? notes,
  }) async {
    try {
      final doc = await _db.collection('dosage_calculations').add({
        'uid': uid,
        'hemophiliaType': hemophiliaType,
        'weight': weight,
        'targetFactorLevel': targetFactorLevel,
        'calculatedDosage': calculatedDosage,
        'notes': notes ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('Dosage calculation saved successfully');
      return doc.id;
    } catch (e) {
      print('Error saving dosage calculation: $e');
      rethrow;
    }
  }

  // Get dosage calculation history for a user
  Future<List<Map<String, dynamic>>> getDosageCalculationHistory(
    String uid, {
    int limit = 20,
  }) async {
    try {
      final querySnapshot = await _db
          .collection('dosage_calculations')
          .where('uid', isEqualTo: uid)
          .limit(limit)
          .get();

      // Sort the results locally by createdAt timestamp
      final docs = querySnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();

      docs.sort((a, b) {
        final aTime =
            a['createdAt']?.millisecondsSinceEpoch ?? a['timestamp'] ?? 0;
        final bTime =
            b['createdAt']?.millisecondsSinceEpoch ?? b['timestamp'] ?? 0;
        return bTime.compareTo(aTime); // Descending order (newest first)
      });

      return docs;
    } catch (e) {
      print('Error getting dosage calculation history: $e');
      rethrow;
    }
  }

  // Get recent dosage calculations stream for real-time updates
  Stream<QuerySnapshot> getDosageCalculationStream(
    String uid, {
    int limit = 10,
  }) {
    try {
      return _db
          .collection('dosage_calculations')
          .where('uid', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots();
    } catch (e) {
      print('Error getting dosage calculation stream: $e');
      rethrow;
    }
  }

  // Update dosage calculation notes
  Future<void> updateDosageCalculationNotes(
    String calculationId,
    String notes,
  ) async {
    try {
      await _db.collection('dosage_calculations').doc(calculationId).update({
        'notes': notes,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('Dosage calculation notes updated successfully');
    } catch (e) {
      print('Error updating dosage calculation notes: $e');
      rethrow;
    }
  }

  // Delete dosage calculation
  Future<void> deleteDosageCalculation(String calculationId) async {
    try {
      await _db.collection('dosage_calculations').doc(calculationId).delete();
      print('Dosage calculation deleted successfully');
    } catch (e) {
      print('Error deleting dosage calculation: $e');
      rethrow;
    }
  }

  // Get user's preferred calculation settings
  Future<Map<String, dynamic>?> getUserCalculationSettings(String uid) async {
    try {
      final doc =
          await _db.collection('user_calculation_settings').doc(uid).get();
      return doc.exists ? doc.data() : null;
    } catch (e) {
      print('Error getting user calculation settings: $e');
      rethrow;
    }
  }

  // Save/Update user's preferred calculation settings
  Future<void> saveUserCalculationSettings({
    required String uid,
    double? defaultWeight,
    double? defaultTargetLevel,
    String? preferredUnits,
    bool? autoSaveCalculations,
  }) async {
    try {
      final data = <String, dynamic>{'updatedAt': FieldValue.serverTimestamp()};

      if (defaultWeight != null) data['defaultWeight'] = defaultWeight;
      if (defaultTargetLevel != null) {
        data['defaultTargetLevel'] = defaultTargetLevel;
      }
      if (preferredUnits != null) data['preferredUnits'] = preferredUnits;
      if (autoSaveCalculations != null) {
        data['autoSaveCalculations'] = autoSaveCalculations;
      }

      await _db
          .collection('user_calculation_settings')
          .doc(uid)
          .set(data, SetOptions(merge: true));
      print('User calculation settings saved successfully');
    } catch (e) {
      print('Error saving user calculation settings: $e');
      rethrow;
    }
  }

  // BLEED LOG METHODS

  // Save bleed log to Firestore
  Future<String> saveBleedLog({
    required String uid,
    required String date,
    required String time,
    required String bodyRegion,
    required String severity,
    String? specificRegion,
    String? notes,
    String? photoUrl,
  }) async {
    try {
      final doc = await _db.collection('bleed_logs').add({
        'uid': uid,
        'date': date,
        'time': time,
        'bodyRegion': bodyRegion,
        'specificRegion': specificRegion ?? '',
        'severity': severity,
        'notes': notes ?? '',
        'photoUrl': photoUrl ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Notify healthcare providers who have access to this patient's data
      await _notifyHealthcareProvidersOfBleedLog(
        uid,
        date,
        bodyRegion,
        severity,
        doc.id,
      );

      print('Bleed log saved successfully');
      return doc.id;
    } catch (e) {
      print('Error saving bleed log: $e');
      rethrow;
    }
  }

  // Notify healthcare providers when patient logs a bleeding episode
  Future<void> _notifyHealthcareProvidersOfBleedLog(
    String patientUid,
    String date,
    String bodyRegion,
    String severity,
    String bleedLogId,
  ) async {
    try {
      // Find all healthcare providers who have active data sharing with this patient
      final dataSharingSnapshot = await _db
          .collection('data_sharing')
          .where('patientUid', isEqualTo: patientUid)
          .where('active', isEqualTo: true)
          .get();

      // Get patient's name for the notification
      String patientName = 'A patient';
      try {
        final userDoc = await _db.collection('users').doc(patientUid).get();
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          patientName = userData['name'] ?? 'A patient';
        }
      } catch (e) {
        print('Error getting patient name: $e');
      }

      // Send notification to each healthcare provider
      for (final doc in dataSharingSnapshot.docs) {
        final data = doc.data();
        final providerUid = data['providerUid'] as String;

        await createNotificationWithData(
          uid: providerUid,
          text:
              '$patientName logged a $severity bleeding episode in $bodyRegion on $date',
          type: 'bleeding_log',
          data: {
            'patientUid': patientUid,
            'patientName': patientName,
            'bleedLogId': bleedLogId,
            'date': date,
            'bodyRegion': bodyRegion,
            'severity': severity,
          },
        );
      }

      print(
        'Bleeding log notifications sent to ${dataSharingSnapshot.docs.length} healthcare providers',
      );
    } catch (e) {
      print('Error notifying healthcare providers of bleeding log: $e');
      // Don't rethrow - bleeding log should still be saved even if notifications fail
    }
  }

  // Get bleed logs for a user
  Future<List<Map<String, dynamic>>> getBleedLogs(
    String uid, {
    int limit = 50,
    bool forceRefresh = false,
  }) async {
    try {
      Query query = _db
          .collection('bleed_logs')
          .where('uid', isEqualTo: uid)
          .limit(limit);

      final QuerySnapshot querySnapshot;
      if (forceRefresh) {
        // Force server fetch to bypass cache
        querySnapshot =
            await query.get(const GetOptions(source: Source.server));
      } else {
        querySnapshot = await query.get();
      }

      // Convert to list with document IDs and sort locally by createdAt
      final docs = querySnapshot.docs
          .map((doc) => <String, dynamic>{
                'id': doc.id,
                ...?doc.data() as Map<String, dynamic>?
              })
          .toList();

      // Sort locally by createdAt timestamp (most recent first)
      docs.sort((a, b) {
        final aTime = _extractTimestampValue(a['createdAt']) ?? 0;
        final bTime = _extractTimestampValue(b['createdAt']) ?? 0;
        return bTime.compareTo(aTime);
      });

      return docs;
    } catch (e) {
      print('Error getting bleed logs: $e');
      rethrow;
    }
  }

  // Helper method to extract timestamp value from various Firestore timestamp formats
  int? _extractTimestampValue(dynamic timestamp) {
    if (timestamp == null) return null;

    // If it's already a DateTime
    if (timestamp is DateTime) {
      return timestamp.millisecondsSinceEpoch;
    }

    // If it's a Firestore Timestamp
    if (timestamp.runtimeType.toString() == 'Timestamp') {
      return (timestamp as dynamic).toDate().millisecondsSinceEpoch;
    }

    // If it's already milliseconds
    if (timestamp is int) {
      return timestamp;
    }

    return null;
  }

  // Get bleed logs stream for real-time updates
  Stream<QuerySnapshot> getBleedLogsStream(String uid, {int limit = 20}) {
    try {
      return _db
          .collection('bleed_logs')
          .where('uid', isEqualTo: uid)
          .limit(limit)
          .snapshots();
    } catch (e) {
      print('Error getting bleed logs stream: $e');
      rethrow;
    }
  }

  // Update bleed log
  Future<void> updateBleedLog(String logId, Map<String, dynamic> data) async {
    try {
      data['updatedAt'] = FieldValue.serverTimestamp();
      await _db.collection('bleed_logs').doc(logId).update(data);
      print('Bleed log updated successfully');
    } catch (e) {
      print('Error updating bleed log: $e');
      rethrow;
    }
  }

  // Delete bleed log
  Future<void> deleteBleedLog(String logId) async {
    try {
      await _db.collection('bleed_logs').doc(logId).delete();
      print('Bleed log deleted successfully');
    } catch (e) {
      print('Error deleting bleed log: $e');
      rethrow;
    }
  }

  // Get bleed log statistics
  Future<Map<String, dynamic>> getBleedLogStats(String uid) async {
    try {
      final querySnapshot =
          await _db.collection('bleed_logs').where('uid', isEqualTo: uid).get();

      final logs = querySnapshot.docs.map((doc) => doc.data()).toList();

      // Calculate statistics
      final totalLogs = logs.length;
      final severityCounts = <String, int>{};
      final regionCounts = <String, int>{};

      for (final log in logs) {
        final severity = log['severity'] as String? ?? '';
        final region = log['bodyRegion'] as String? ?? '';

        severityCounts[severity] = (severityCounts[severity] ?? 0) + 1;
        regionCounts[region] = (regionCounts[region] ?? 0) + 1;
      }

      return {
        'totalLogs': totalLogs,
        'severityCounts': severityCounts,
        'regionCounts': regionCounts,
        'lastWeekCount': _getLogsInTimeframe(logs, 7),
        'lastMonthCount': _getLogsInTimeframe(logs, 30),
      };
    } catch (e) {
      print('Error getting bleed log stats: $e');
      rethrow;
    }
  }

  // Helper method to count logs in timeframe
  int _getLogsInTimeframe(List<Map<String, dynamic>> logs, int days) {
    final cutoffDate = DateTime.now().subtract(Duration(days: days));
    int count = 0;

    for (final log in logs) {
      final createdAt = log['createdAt'] as Timestamp?;
      if (createdAt != null && createdAt.toDate().isAfter(cutoffDate)) {
        count++;
      }
    }

    return count;
  }

  // =============================================================================================================

  // MEDICATION SCHEDULE METHODS

  // Save medication schedule
  Future<String> saveMedicationSchedule({
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
      final scheduleData = {
        'uid': uid,
        'medicationName': medicationName,
        'dosage': dosage,
        'administrationType': administrationType,
        'frequency': frequency,
        'reminderTimeHour': reminderTime.hour,
        'reminderTimeMinute': reminderTime.minute,
        'notificationEnabled': notificationEnabled,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'notes': notes ?? '',
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final docRef =
          await _db.collection('medication_schedules').add(scheduleData);
      return docRef.id;
    } catch (e) {
      print('Error saving medication schedule: $e');
      rethrow;
    }
  }

  // Get medication schedules for a user
  Future<List<Map<String, dynamic>>> getMedicationSchedules(String uid) async {
    try {
      print('Fetching medication schedules for user: $uid'); // Debug log

      final querySnapshot = await _db
          .collection('medication_schedules')
          .where('uid', isEqualTo: uid)
          .where('isActive', isEqualTo: true)
          .get();

      print(
        'Found ${querySnapshot.docs.length} medication schedules',
      ); // Debug log

      final schedules = querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      // Sort locally by createdAt (most recent first)
      schedules.sort((a, b) {
        final timeA = a['createdAt'] as Timestamp?;
        final timeB = b['createdAt'] as Timestamp?;
        if (timeA == null && timeB == null) return 0;
        if (timeA == null) return 1;
        if (timeB == null) return -1;
        return timeB.compareTo(timeA);
      });

      return schedules;
    } catch (e) {
      print('Error getting medication schedules: $e');
      return [];
    }
  }

  // Get today's medication reminders
  Future<List<Map<String, dynamic>>> getTodaysMedicationReminders(
    String uid,
  ) async {
    try {
      print(
        'Getting today\'s medication reminders for user: $uid',
      ); // Debug log

      final schedules = await getMedicationSchedules(uid);
      print('Retrieved ${schedules.length} total schedules'); // Debug log

      // Get already taken medications for today
      final takenMedications = await getTakenMedicationsToday(uid);
      print('Taken medications today: $takenMedications'); // Debug log

      final todaysReminders = <Map<String, dynamic>>[];
      final now = DateTime.now();
      print('Current time: $now'); // Debug log

      for (final schedule in schedules) {
        print(
          'Processing schedule: ${schedule['medicationName']}',
        ); // Debug log
        print(
          'Notification enabled: ${schedule['notificationEnabled']}',
        ); // Debug log

        // Skip if medication was already taken today
        if (takenMedications.contains(schedule['id'])) {
          print(
            'Skipping ${schedule['medicationName']} - already taken today',
          ); // Debug log
          continue;
        }

        if (schedule['notificationEnabled'] == true) {
          final reminderHour = schedule['reminderTimeHour'] as int? ?? 9;
          final reminderMinute = schedule['reminderTimeMinute'] as int? ?? 0;

          final reminderTime = DateTime(
            now.year,
            now.month,
            now.day,
            reminderHour,
            reminderMinute,
          );

          print('Reminder time: $reminderTime'); // Debug log

          // Check if medication should be taken today based on frequency
          bool shouldTakeToday = _shouldTakeMedicationToday(schedule, now);
          print('Should take today: $shouldTakeToday'); // Debug log

          if (shouldTakeToday) {
            final reminderData = Map<String, dynamic>.from(schedule);
            reminderData['reminderDateTime'] = reminderTime;
            reminderData['isPending'] = reminderTime.isAfter(now);
            reminderData['isOverdue'] = reminderTime.isBefore(now) &&
                reminderTime.isAfter(now.subtract(Duration(hours: 2)));
            todaysReminders.add(reminderData);
            print(
              'Added reminder for: ${schedule['medicationName']}',
            ); // Debug log
          }
        }
      }

      print('Total today\'s reminders: ${todaysReminders.length}'); // Debug log

      // Sort by reminder time
      todaysReminders.sort((a, b) {
        final timeA = a['reminderDateTime'] as DateTime;
        final timeB = b['reminderDateTime'] as DateTime;
        return timeA.compareTo(timeB);
      });

      return todaysReminders;
    } catch (e) {
      print('Error getting today\'s medication reminders: $e');
      return [];
    }
  }

  // Helper method to determine if medication should be taken today
  bool _shouldTakeMedicationToday(
    Map<String, dynamic> schedule,
    DateTime today,
  ) {
    final frequency = schedule['frequency'] as String? ?? 'Daily';
    final createdAt = schedule['createdAt'] as Timestamp?;

    print('Checking frequency: $frequency'); // Debug log
    print('Created at: $createdAt'); // Debug log

    if (createdAt == null) {
      print('No creation date, returning true'); // Debug log
      return true;
    }

    final scheduleDate = createdAt.toDate();
    final daysDifference = today.difference(scheduleDate).inDays;

    print('Schedule date: $scheduleDate'); // Debug log
    print('Days difference: $daysDifference'); // Debug log

    switch (frequency) {
      case 'Daily':
        print('Daily frequency - returning true'); // Debug log
        return true;
      case 'Every 2 days':
        final shouldTake = daysDifference % 2 == 0;
        print('Every 2 days - should take: $shouldTake'); // Debug log
        return shouldTake;
      case 'Every 3 days':
        final shouldTake = daysDifference % 3 == 0;
        print('Every 3 days - should take: $shouldTake'); // Debug log
        return shouldTake;
      case 'Weekly':
        final shouldTake = daysDifference % 7 == 0;
        print('Weekly - should take: $shouldTake'); // Debug log
        return shouldTake;
      case 'As needed':
        print('As needed - returning false'); // Debug log
        return false; // Manual only
      default:
        print('Default case - returning true'); // Debug log
        return true;
    }
  }

  // Update medication schedule
  Future<void> updateMedicationSchedule(
    String scheduleId,
    Map<String, dynamic> data,
  ) async {
    try {
      data['updatedAt'] = FieldValue.serverTimestamp();
      await _db.collection('medication_schedules').doc(scheduleId).update(data);
    } catch (e) {
      print('Error updating medication schedule: $e');
      rethrow;
    }
  }

  // Delete/deactivate medication schedule
  Future<void> deleteMedicationSchedule(String scheduleId) async {
    try {
      await _db.collection('medication_schedules').doc(scheduleId).update({
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error deleting medication schedule: $e');
      rethrow;
    }
  }

  // Mark medication as taken for today
  Future<void> markMedicationTaken(String uid, String scheduleId) async {
    try {
      final today = DateTime.now();
      final dateKey =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      await _db.collection('medication_taken').add({
        'uid': uid,
        'scheduleId': scheduleId,
        'date': dateKey,
        'takenAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      print('Medication marked as taken for schedule: $scheduleId on $dateKey');
    } catch (e) {
      print('Error marking medication as taken: $e');
      rethrow;
    }
  }

  // Check if medication was taken today
  Future<bool> isMedicationTakenToday(String uid, String scheduleId) async {
    try {
      final today = DateTime.now();
      final dateKey =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final snapshot = await _db
          .collection('medication_taken')
          .where('uid', isEqualTo: uid)
          .where('scheduleId', isEqualTo: scheduleId)
          .where('date', isEqualTo: dateKey)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking if medication was taken: $e');
      return false;
    }
  }

  // Get taken medications for today
  Future<Set<String>> getTakenMedicationsToday(String uid) async {
    try {
      final today = DateTime.now();
      final dateKey =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final snapshot = await _db
          .collection('medication_taken')
          .where('uid', isEqualTo: uid)
          .where('date', isEqualTo: dateKey)
          .get();

      return snapshot.docs
          .map((doc) => doc.data()['scheduleId'] as String)
          .toSet();
    } catch (e) {
      print('Error getting taken medications: $e');
      return <String>{};
    }
  }

  // INFUSION LOG METHODS

  // Save infusion log to Firestore
  Future<String> saveInfusionLog({
    required String uid,
    required String medication,
    required int doseIU,
    required String date,
    required String time,
    required String notes,
    String lotNumber = '',
  }) async {
    try {
      final logData = {
        'uid': uid,
        'medication': medication,
        'doseIU': doseIU,
        'date': date,
        'time': time,
        'notes': notes,
        'lotNumber': lotNumber,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final docRef = await _db.collection('infusion_logs').add(logData);
      print('Infusion log saved with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('Error saving infusion log: $e');
      rethrow;
    }
  }

  // Get infusion logs for a user
  Future<List<Map<String, dynamic>>> getInfusionLogs(String uid) async {
    try {
      print('Fetching infusion logs for user: $uid');

      final querySnapshot = await _db
          .collection('infusion_logs')
          .where('uid', isEqualTo: uid)
          .get();

      print('Found ${querySnapshot.docs.length} infusion logs');

      final logs = querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      // Sort by createdAt in descending order (most recent first)
      logs.sort((a, b) {
        final aTime = a['createdAt'];
        final bTime = b['createdAt'];

        // Handle null values
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;

        // Convert Firestore Timestamps to milliseconds for comparison
        int aMillis = 0;
        int bMillis = 0;

        if (aTime.runtimeType.toString() == 'Timestamp') {
          aMillis = (aTime as dynamic).toDate().millisecondsSinceEpoch;
        } else if (aTime is DateTime) {
          aMillis = aTime.millisecondsSinceEpoch;
        } else if (aTime is int) {
          aMillis = aTime;
        }

        if (bTime.runtimeType.toString() == 'Timestamp') {
          bMillis = (bTime as dynamic).toDate().millisecondsSinceEpoch;
        } else if (bTime is DateTime) {
          bMillis = bTime.millisecondsSinceEpoch;
        } else if (bTime is int) {
          bMillis = bTime;
        }

        return bMillis.compareTo(aMillis); // Descending order
      });

      return logs;
    } catch (e) {
      print('Error getting infusion logs: $e');
      return [];
    }
  }

  // Get infusion logs for a specific date range
  Future<List<Map<String, dynamic>>> getInfusionLogsByDateRange({
    required String uid,
    required String startDate,
    required String endDate,
  }) async {
    try {
      final querySnapshot = await _db
          .collection('infusion_logs')
          .where('uid', isEqualTo: uid)
          .where('date', isGreaterThanOrEqualTo: startDate)
          .where('date', isLessThanOrEqualTo: endDate)
          .orderBy('date', descending: true)
          .orderBy('time', descending: true)
          .get();

      final logs = querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      return logs;
    } catch (e) {
      print('Error getting infusion logs by date range: $e');
      return [];
    }
  }

  // Update infusion log
  Future<void> updateInfusionLog({
    required String logId,
    required String medication,
    required int doseIU,
    required String date,
    required String time,
    required String notes,
  }) async {
    try {
      await _db.collection('infusion_logs').doc(logId).update({
        'medication': medication,
        'doseIU': doseIU,
        'date': date,
        'time': time,
        'notes': notes,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('Infusion log updated: $logId');
    } catch (e) {
      print('Error updating infusion log: $e');
      rethrow;
    }
  }

  // Delete infusion log
  Future<void> deleteInfusionLog(String logId) async {
    try {
      await _db.collection('infusion_logs').doc(logId).delete();
      print('Infusion log deleted: $logId');
    } catch (e) {
      print('Error deleting infusion log: $e');
      rethrow;
    }
  }

  // =============================================================================================================
  // ADMIN METHODS

  // Get all pending medical professional verifications
  Stream<QuerySnapshot> getPendingVerifications() {
    return _db.collection('users').where('role', isEqualTo: 'medical').where(
        'verificationStatus',
        whereIn: ['pending', 'pending_contact']).snapshots();
  }

  // Get all verified medical professionals
  Stream<QuerySnapshot> getVerifiedDoctors() {
    return _db
        .collection('users')
        .where('role', isEqualTo: 'medical')
        .where('verificationStatus', isEqualTo: 'approved')
        .snapshots();
  }

  // Get all medical professionals for analytics
  Stream<QuerySnapshot> getAllMedicalProfessionals() {
    return _db
        .collection('users')
        .where('role', isEqualTo: 'medical')
        .snapshots();
  }

  // Approve a medical professional
  Future<void> approveMedicalProfessional(
      String uid, String name, String email) async {
    try {
      await updateUser(
        uid,
        name,
        email,
        'medical',
        extra: {
          'verificationStatus': 'approved',
          'isVerified': true,
          'verificationApprovedAt': DateTime.now().toIso8601String(),
          'verificationExpiry': null, // Remove expiry date for approved doctors
        },
      );

      // Send approval notification
      await createNotificationWithData(
        uid: uid,
        text:
            'Congratulations! Your medical professional account has been verified and approved.',
        type: 'verification_approved',
        data: {
          'verificationStatus': 'approved',
          'approvedAt': DateTime.now().toIso8601String(),
        },
      );

      print('Medical professional approved: $uid');
    } catch (e) {
      print('Error approving medical professional: $e');
      rethrow;
    }
  }

  // Reject a medical professional
  Future<void> rejectMedicalProfessional(
      String uid, String name, String email, String reason) async {
    try {
      await updateUser(
        uid,
        name,
        email,
        'medical',
        extra: {
          'verificationStatus': 'rejected',
          'isVerified': false,
          'rejectionReason': reason,
          'verificationRejectedAt': DateTime.now().toIso8601String(),
        },
      );

      // Send rejection notification
      await createNotificationWithData(
        uid: uid,
        text:
            'Your medical professional verification has been rejected. Reason: $reason',
        type: 'verification_rejected',
        data: {
          'verificationStatus': 'rejected',
          'rejectionReason': reason,
          'rejectedAt': DateTime.now().toIso8601String(),
        },
      );

      print('Medical professional rejected: $uid');
    } catch (e) {
      print('Error rejecting medical professional: $e');
      rethrow;
    }
  }

  // Revoke verification for a medical professional
  Future<void> revokeMedicalVerification(
      String uid, String name, String email) async {
    try {
      await updateUser(
        uid,
        name,
        email,
        'medical',
        extra: {
          'verificationStatus': 'rejected',
          'isVerified': false,
          'verificationRevokedAt': DateTime.now().toIso8601String(),
          'rejectionReason': 'Verification revoked by admin',
        },
      );

      // Send revocation notification
      await createNotificationWithData(
        uid: uid,
        text:
            'Your medical professional verification has been revoked by the administrator.',
        type: 'verification_revoked',
        data: {
          'verificationStatus': 'revoked',
          'revokedAt': DateTime.now().toIso8601String(),
        },
      );

      print('Medical professional verification revoked: $uid');
    } catch (e) {
      print('Error revoking medical verification: $e');
      rethrow;
    }
  }

  // Get statistics for admin dashboard
  Future<Map<String, int>> getAdminStatistics() async {
    try {
      final medicalSnapshot = await _db
          .collection('users')
          .where('role', isEqualTo: 'medical')
          .get();

      int totalDoctors = medicalSnapshot.docs.length;
      int pendingDoctors = 0;
      int approvedDoctors = 0;
      int rejectedDoctors = 0;

      for (var doc in medicalSnapshot.docs) {
        final data = doc.data();
        final status = data['verificationStatus'] ?? 'pending';

        switch (status) {
          case 'pending':
          case 'pending_contact':
            pendingDoctors++;
            break;
          case 'approved':
            approvedDoctors++;
            break;
          case 'rejected':
            rejectedDoctors++;
            break;
        }
      }

      return {
        'total': totalDoctors,
        'pending': pendingDoctors,
        'approved': approvedDoctors,
        'rejected': rejectedDoctors,
      };
    } catch (e) {
      print('Error getting admin statistics: $e');
      rethrow;
    }
  }
}
