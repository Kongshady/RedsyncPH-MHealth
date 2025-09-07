import 'package:hive_flutter/hive_flutter.dart';

class DebugUtils {
  static Future<void> resetAllLocalData() async {
    try {
      print('Starting local data reset...');

      // List of all Hive boxes used in the app
      final boxNames = [
        'infusion_logs',
        'bleed_logs',
        'medication_reminders',
        'notifications',
        'sync_queue',
        'user_data',
        'settings',
        'community_posts'
      ];

      // Close and delete each box
      for (String boxName in boxNames) {
        try {
          if (Hive.isBoxOpen(boxName)) {
            await Hive.box(boxName).close();
            print('Closed box: $boxName');
          }

          await Hive.deleteBoxFromDisk(boxName);
          print('Deleted box: $boxName');
        } catch (e) {
          print('Error handling box $boxName: $e');
        }
      }

      print('Local data reset completed successfully!');
      print('Please restart the app to reinitialize with clean data.');
    } catch (e) {
      print('Error during local data reset: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getDatabaseStatus() async {
    Map<String, dynamic> status = {};

    final boxNames = [
      'infusion_logs',
      'bleed_logs',
      'medication_reminders',
      'notifications',
      'sync_queue',
      'user_data',
      'settings',
      'community_posts'
    ];

    for (String boxName in boxNames) {
      try {
        if (Hive.isBoxOpen(boxName)) {
          final box = Hive.box(boxName);
          status[boxName] = {
            'isOpen': true,
            'length': box.length,
            'keys': box.keys.toList(),
          };
        } else {
          status[boxName] = {
            'isOpen': false,
            'exists': await _boxExists(boxName),
          };
        }
      } catch (e) {
        status[boxName] = {
          'error': e.toString(),
        };
      }
    }

    return status;
  }

  static Future<bool> _boxExists(String boxName) async {
    try {
      final box = await Hive.openBox(boxName);
      await box.close();
      return true;
    } catch (e) {
      return false;
    }
  }

  static void printDatabaseStatus() async {
    final status = await getDatabaseStatus();
    print('\n=== DATABASE STATUS ===');
    status.forEach((boxName, info) {
      print('$boxName: $info');
    });
    print('========================\n');
  }
}
