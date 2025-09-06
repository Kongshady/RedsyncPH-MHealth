import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  // Add a navigation callback for handling notification taps
  static void Function(String)? _onNotificationTap;

  // Set the callback for handling notification navigation
  static void setNavigationCallback(void Function(String) callback) {
    _onNotificationTap = callback;
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize timezone data safely - this should work offline
    try {
      tz.initializeTimeZones();
      print('✅ Timezone data initialized successfully');
    } catch (e) {
      print('Warning: Could not initialize timezone data: $e');
      // Continue without timezone support for basic functionality
      // This might happen in some offline scenarios
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
      defaultPresentAlert: true,
      defaultPresentSound: true,
      defaultPresentBadge: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    try {
      await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          // Handle notification tap safely
          try {
            print('Notification tapped: ${response.payload}');
            _handleNotificationTap(response);
          } catch (e) {
            print('Error handling notification tap: $e');
            // Don't crash the app if notification handling fails
          }
        },
      );

      _isInitialized = true;
      print(
          '✅ Notification service initialized successfully (offline-compatible)');
    } catch (e) {
      print('❌ Failed to initialize notification service: $e');
      // Still mark as initialized to prevent constant retry
      _isInitialized = true;
      rethrow;
    }
  }

  // Handle notification tap safely
  void _handleNotificationTap(NotificationResponse response) {
    try {
      final payload = response.payload;
      if (payload != null) {
        print('Notification tapped with payload: $payload');

        // Use the navigation callback if available
        if (_onNotificationTap != null) {
          _onNotificationTap!(payload);
        } else {
          print('No navigation callback set for notification handling');
        }

        // Handle different types of notifications
        if (payload.startsWith('medication_reminder:')) {
          print('Medication reminder notification tapped');
        } else if (payload.startsWith('schedule_created:')) {
          print('Schedule creation notification tapped');
        } else if (payload.startsWith('post_like:') ||
            payload.startsWith('post_comment:') ||
            payload.startsWith('post_share:')) {
          print('Post-related notification tapped');
        } else if (payload.startsWith('message:')) {
          print('Message notification tapped');
        } else if (payload == 'test_notification' ||
            payload == 'test_scheduled_notification') {
          print('Test notification tapped');
        }
      }
    } catch (e) {
      print('Error in notification tap handler: $e');
      // Don't let notification handling crash the app
    }
  }

  Future<bool> requestPermissions() async {
    try {
      if (!_isInitialized) {
        print('🔄 Notification service not initialized, initializing now...');
        await initialize();
      }

      print('🔐 Requesting notification permissions...');

      // For iOS, permissions are requested during initialization
      // The DarwinInitializationSettings already handles permission requests
      try {
        // Request permissions using the plugin's own method
        if (await _flutterLocalNotificationsPlugin
                .resolvePlatformSpecificImplementation<
                    IOSFlutterLocalNotificationsPlugin>()
                ?.requestPermissions(
                  alert: true,
                  badge: true,
                  sound: true,
                ) !=
            null) {
          print('✅ iOS notification permissions requested');
        }
      } catch (e) {
        print('ℹ️ Note: iOS permissions handled during initialization: $e');
      }

      // Handle Android permissions
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        try {
          // Request notification permission with timeout for offline scenarios
          final bool? notificationGranted = await androidImplementation
              .requestNotificationsPermission()
              .timeout(Duration(seconds: 5), onTimeout: () {
            print(
                '⏰ Notification permission request timed out, assuming granted');
            return true;
          });

          // Request exact alarm permission for Android 12+ with timeout
          final bool? exactAlarmGranted = await androidImplementation
              .requestExactAlarmsPermission()
              .timeout(Duration(seconds: 5), onTimeout: () {
            print(
                '⏰ Exact alarm permission request timed out, assuming granted');
            return true;
          });

          print('✅ Notification permission granted: $notificationGranted');
          print('✅ Exact alarm permission granted: $exactAlarmGranted');

          // Both permissions are needed for scheduled notifications to work properly
          final result =
              (notificationGranted ?? false) && (exactAlarmGranted ?? true);
          print('🔐 Final permission result: $result');
          return result;
        } catch (e) {
          print('⚠️ Error requesting permissions (may be offline): $e');
          print('📱 Assuming permissions are granted for offline mode');
          return true; // Assume permissions are granted when offline
        }
      }

      // For other platforms, assume permissions are granted
      print('✅ Platform permissions assumed granted');
      return true;
    } catch (e) {
      print('❌ Critical error in permission request: $e');
      print('📱 Assuming permissions granted to prevent blocking');
      return true; // Don't block the app due to permission issues
    }
  }

  Future<void> scheduleMedicationReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) async {
    try {
      if (!_isInitialized) await initialize();

      // Validate inputs
      if (title.isEmpty || body.isEmpty) {
        print('Warning: Notification title or body is empty');
        return;
      }

      if (scheduledTime.isBefore(DateTime.now())) {
        print('Warning: Scheduled time is in the past, adjusting to future');
        scheduledTime = DateTime.now().add(Duration(minutes: 1));
      }

      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'medication_reminders',
        'Medication Reminders',
        channelDescription: 'Notifications for medication reminders',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        sound: RawResourceAndroidNotificationSound('notification_sound'),
        enableVibration: true,
        playSound: true,
      );

      const DarwinNotificationDetails iosPlatformChannelSpecifics =
          DarwinNotificationDetails(
        sound: 'default',
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iosPlatformChannelSpecifics,
      );

      final tzDateTime = _convertToTZDateTime(scheduledTime);
      print('Scheduling notification ID $id for $tzDateTime');
      print('Current time: ${DateTime.now()}');
      print(
        'Time difference: ${scheduledTime.difference(DateTime.now()).inMinutes} minutes',
      );

      await _flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tzDateTime,
        platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );

      print('Notification scheduled successfully!');
    } catch (e) {
      print('Error scheduling medication reminder: $e');
      // Don't rethrow to prevent app crashes - just log the error
      // The app should continue functioning even if notifications fail
    }
  }

  Future<void> scheduleRepeatingMedicationReminder({
    required int id,
    required String title,
    required String body,
    required TimeOfDay time,
    required RepeatInterval repeatInterval,
    String? payload,
  }) async {
    try {
      print('🔔 Starting notification scheduling (offline-compatible)...');

      if (!_isInitialized) {
        print('🔄 Initializing notification service...');
        await initialize();
      }

      // Validate inputs
      if (title.isEmpty || body.isEmpty) {
        print('⚠️ Warning: Notification title or body is empty');
        return;
      }

      print('📝 Scheduling notification: $title - $body');

      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'medication_reminders',
        'Medication Reminders',
        channelDescription: 'Notifications for medication reminders',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        enableVibration: true,
        playSound: true,
      );

      const DarwinNotificationDetails iosPlatformChannelSpecifics =
          DarwinNotificationDetails(
        sound: 'default',
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iosPlatformChannelSpecifics,
      );

      // Calculate the next occurrence of the specified time
      final now = DateTime.now();
      var scheduledDate = DateTime(
        now.year,
        now.month,
        now.day,
        time.hour,
        time.minute,
      );

      // If the time has already passed today, schedule for tomorrow
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(Duration(days: 1));
        print(
            '⏰ Time has passed today, scheduling for tomorrow: $scheduledDate');
      }

      // Try to convert to timezone-aware datetime with fallbacks for offline
      tz.TZDateTime tzDateTime;
      try {
        tzDateTime = _convertToTZDateTime(scheduledDate);
        print('✅ Timezone conversion successful: $tzDateTime');
      } catch (e) {
        print('⚠️ Timezone conversion failed (offline?), using fallback: $e');
        // Fallback for offline scenarios - use basic scheduled notification
        await _scheduleBasicNotification(
          id: id,
          title: title,
          body: body,
          scheduledTime: scheduledDate,
          payload: payload,
        );
        return;
      }

      print(
          '🕐 Scheduling repeating notification ID $id for $tzDateTime with interval $repeatInterval');

      await _flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tzDateTime,
        platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
        matchDateTimeComponents:
            DateTimeComponents.time, // This makes it repeat daily
      );

      print('✅ Repeating notification scheduled successfully!');
    } catch (e) {
      print('❌ Error scheduling repeating medication reminder: $e');
      print('🔄 Attempting fallback scheduling method...');

      // Fallback: try basic scheduling without timezone
      try {
        final now = DateTime.now();
        var fallbackTime = DateTime(
          now.year,
          now.month,
          now.day,
          time.hour,
          time.minute,
        );

        if (fallbackTime.isBefore(now)) {
          fallbackTime = fallbackTime.add(Duration(days: 1));
        }

        await _scheduleBasicNotification(
          id: id,
          title: title,
          body: body,
          scheduledTime: fallbackTime,
          payload: payload,
        );
        print('✅ Fallback notification scheduled successfully!');
      } catch (fallbackError) {
        print('❌ Fallback scheduling also failed: $fallbackError');
        // Don't rethrow to prevent app crashes - just log the error
      }
    }
  }

  // Fallback method for basic notification scheduling without timezone complexities
  Future<void> _scheduleBasicNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) async {
    try {
      print('📱 Using basic notification scheduling for offline compatibility');

      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'medication_reminders_basic',
        'Basic Medication Reminders',
        channelDescription:
            'Basic notifications for medication reminders (offline mode)',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        enableVibration: true,
        playSound: true,
      );

      const DarwinNotificationDetails iosPlatformChannelSpecifics =
          DarwinNotificationDetails(
        sound: 'default',
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iosPlatformChannelSpecifics,
      );

      // Create a simple TZDateTime for the basic notification
      tz.TZDateTime basicTzDateTime;
      try {
        basicTzDateTime = tz.TZDateTime.from(scheduledTime, tz.local);
      } catch (e) {
        // If local timezone fails, use UTC
        basicTzDateTime = tz.TZDateTime.utc(
          scheduledTime.year,
          scheduledTime.month,
          scheduledTime.day,
          scheduledTime.hour,
          scheduledTime.minute,
        );
      }

      await _flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        basicTzDateTime,
        platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );

      print('✅ Basic notification scheduled for: $scheduledTime');
    } catch (e) {
      print('❌ Basic notification scheduling failed: $e');
      rethrow;
    }
  }

  Future<void> cancelNotification(int id) async {
    await _flutterLocalNotificationsPlugin.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _flutterLocalNotificationsPlugin.pendingNotificationRequests();
  }

  // Convert DateTime to TZDateTime (using local timezone)
  tz.TZDateTime _convertToTZDateTime(DateTime dateTime) {
    try {
      // First try to get the local timezone
      tz.Location? location;
      try {
        location = tz.local;
      } catch (e) {
        print('Warning: Could not get local timezone, using UTC: $e');
        location = tz.UTC;
      }

      // Convert to TZDateTime with additional safety checks
      tz.TZDateTime tzDateTime;
      try {
        tzDateTime = tz.TZDateTime.from(dateTime, location);
      } catch (e) {
        print(
          'Warning: Failed to convert with tz.TZDateTime.from, trying manual creation: $e',
        );
        try {
          tzDateTime = tz.TZDateTime(
            location,
            dateTime.year,
            dateTime.month,
            dateTime.day,
            dateTime.hour,
            dateTime.minute,
            dateTime.second,
          );
        } catch (e2) {
          print(
            'Warning: Manual TZDateTime creation failed, using UTC fallback: $e2',
          );
          tzDateTime = tz.TZDateTime.utc(
            dateTime.year,
            dateTime.month,
            dateTime.day,
            dateTime.hour,
            dateTime.minute,
            dateTime.second,
          );
        }
      }

      print(
        'Converted DateTime $dateTime to TZDateTime $tzDateTime in timezone ${location.name}',
      );
      return tzDateTime;
    } catch (e) {
      print(
        'Error: Timezone conversion failed completely, using current time in UTC: $e',
      );
      // As a last resort, create a TZDateTime in UTC for the current time + 1 minute
      final fallbackTime = DateTime.now().add(Duration(minutes: 1));
      return tz.TZDateTime.utc(
        fallbackTime.year,
        fallbackTime.month,
        fallbackTime.day,
        fallbackTime.hour,
        fallbackTime.minute,
        fallbackTime.second,
      );
    }
  }

  // Show immediate notification (for testing)
  Future<void> showImmediateNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized) await initialize();

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'medication_reminders',
      'Medication Reminders',
      channelDescription: 'Notifications for medication reminders',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      enableVibration: true,
      playSound: true,
    );

    const DarwinNotificationDetails iosPlatformChannelSpecifics =
        DarwinNotificationDetails(
      sound: 'default',
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iosPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  // Test notification to verify notifications are working (offline-compatible)
  Future<void> showTestNotification() async {
    try {
      print('🧪 Starting offline-compatible test notification...');

      await showImmediateNotification(
        id: 999,
        title: 'Test Notification (Offline Compatible)',
        body:
            'This test notification works offline! System is functioning correctly.',
        payload: 'test_notification',
      );

      print('✅ Test notification sent successfully (offline mode supported)');
    } catch (e) {
      print('❌ Test notification failed: $e');
      rethrow;
    }
  }

  // Schedule a test notification for 5 seconds from now
  Future<void> scheduleTestNotification() async {
    final scheduledTime = DateTime.now().add(Duration(seconds: 5));

    print('Scheduling test notification for: $scheduledTime');
    print('Current time: ${DateTime.now()}');

    await scheduleMedicationReminder(
      id: 998,
      title: 'Test Scheduled Notification',
      body: 'This test notification was scheduled for 5 seconds ago.',
      scheduledTime: scheduledTime,
      payload: 'test_scheduled_notification',
    );

    // Check pending notifications
    final pendingNotifications = await getPendingNotifications();
    print('Total pending notifications: ${pendingNotifications.length}');
    for (final notification in pendingNotifications) {
      print(
        'Pending notification: ID ${notification.id}, title: ${notification.title}',
      );
    }
  }

  // Get all pending notifications for debugging
  Future<void> debugPendingNotifications() async {
    try {
      final pendingNotifications = await getPendingNotifications();
      print('=== DEBUG: Pending Notifications ===');
      print('Total count: ${pendingNotifications.length}');
      for (final notification in pendingNotifications) {
        print('ID: ${notification.id}');
        print('Title: ${notification.title}');
        print('Body: ${notification.body}');
        print('Payload: ${notification.payload}');
        print('---');
      }
      print('=== END DEBUG ===');
    } catch (e) {
      print('Error getting pending notifications: $e');
    }
  }

  // Create notification for post interactions (like, comment, share)
  Future<void> showPostNotification({
    required int id,
    required String title,
    required String body,
    required String postId,
    required String type, // 'like', 'comment', 'share'
  }) async {
    try {
      if (!_isInitialized) await initialize();

      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'post_notifications',
        'Post Notifications',
        channelDescription: 'Notifications for post interactions',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        enableVibration: true,
        playSound: true,
        styleInformation: BigTextStyleInformation(''),
      );

      const DarwinNotificationDetails iosPlatformChannelSpecifics =
          DarwinNotificationDetails(
        sound: 'default',
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iosPlatformChannelSpecifics,
      );

      final payload = 'post_${type}:$postId';

      await _flutterLocalNotificationsPlugin.show(
        id,
        title,
        body,
        platformChannelSpecifics,
        payload: payload,
      );

      print('Post notification sent: $payload');
    } catch (e) {
      print('Error showing post notification: $e');
    }
  }

  // Create notification for messages
  Future<void> showMessageNotification({
    required int id,
    required String title,
    required String body,
    required String senderId,
    required String conversationId,
  }) async {
    try {
      if (!_isInitialized) await initialize();

      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'message_notifications',
        'Message Notifications',
        channelDescription: 'Notifications for new messages',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        enableVibration: true,
        playSound: true,
        styleInformation: BigTextStyleInformation(''),
      );

      const DarwinNotificationDetails iosPlatformChannelSpecifics =
          DarwinNotificationDetails(
        sound: 'default',
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iosPlatformChannelSpecifics,
      );

      final payload = 'message:$senderId:$conversationId';

      await _flutterLocalNotificationsPlugin.show(
        id,
        title,
        body,
        platformChannelSpecifics,
        payload: payload,
      );

      print('Message notification sent: $payload');
    } catch (e) {
      print('Error showing message notification: $e');
    }
  }

  // Enhanced medication reminder notification that appears in notification center
  Future<void> showMedicationReminderNotification({
    required int id,
    required String title,
    required String body,
    required String scheduleId,
  }) async {
    try {
      if (!_isInitialized) await initialize();

      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'medication_reminders',
        'Medication Reminders',
        channelDescription: 'Reminders for medication intake',
        importance: Importance.max,
        priority: Priority.max,
        icon: '@mipmap/ic_launcher',
        enableVibration: true,
        playSound: true,
        styleInformation: BigTextStyleInformation(''),
        ongoing: false,
        autoCancel: true,
        fullScreenIntent: false,
      );

      const DarwinNotificationDetails iosPlatformChannelSpecifics =
          DarwinNotificationDetails(
        sound: 'default',
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        badgeNumber: 1,
      );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iosPlatformChannelSpecifics,
      );

      final payload = 'medication_reminder:$scheduleId';

      await _flutterLocalNotificationsPlugin.show(
        id,
        title,
        body,
        platformChannelSpecifics,
        payload: payload,
      );

      print('Medication reminder notification sent: $payload');
    } catch (e) {
      print('Error showing medication reminder notification: $e');
    }
  }
}
