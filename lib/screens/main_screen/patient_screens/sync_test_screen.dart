import 'package:flutter/material.dart';
import '../../../services/offline_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Test widget to demonstrate and verify Firestore sync functionality
class SyncTestScreen extends StatefulWidget {
  const SyncTestScreen({super.key});

  @override
  State<SyncTestScreen> createState() => _SyncTestScreenState();
}

class _SyncTestScreenState extends State<SyncTestScreen> {
  final OfflineService _offlineService = OfflineService();
  String _syncStatus = 'Initializing...';
  List<String> _syncLogs = [];
  bool _isOnline = false;
  Map<String, int> _syncCounts = {};

  @override
  void initState() {
    super.initState();
    _initializeAndTest();
  }

  Future<void> _initializeAndTest() async {
    try {
      // Initialize offline service
      await _offlineService.initialize();

      // Check connectivity status
      final online = await _offlineService.isOnline();
      final syncStatus = await _offlineService.getSyncStatus();

      setState(() {
        _isOnline = online;
        _syncCounts = syncStatus;
        _syncStatus = online
            ? 'Online - Ready to sync'
            : 'Offline - Will sync when connected';
      });

      _addLog('✅ OfflineService initialized');
      _addLog('📡 Connection: ${online ? "Online" : "Offline"}');
      _addLog('📊 Pending sync items: ${syncStatus}');
    } catch (e) {
      setState(() {
        _syncStatus = 'Error: $e';
      });
      _addLog('❌ Initialization error: $e');
    }
  }

  void _addLog(String message) {
    setState(() {
      _syncLogs.insert(0,
          '${DateTime.now().toIso8601String().substring(11, 19)} - $message');
      if (_syncLogs.length > 20) {
        _syncLogs.removeLast();
      }
    });
  }

  Future<void> _testCreateOfflineEntry() async {
    try {
      _addLog('📝 Creating test infusion log...');

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _addLog('❌ No authenticated user found');
        return;
      }

      // Create a test infusion log offline
      await _offlineService.saveInfusionLogOffline(
        medication: 'Test Factor VIII',
        doseIU: 1000,
        date: DateTime.now().toString().substring(0, 10),
        time: TimeOfDay.now().format(context),
        notes: 'Test entry created at ${DateTime.now()}',
        lotNumber: 'TEST123',
      );

      _addLog('✅ Test infusion log created locally');

      // Update sync status
      final syncStatus = await _offlineService.getSyncStatus();
      setState(() {
        _syncCounts = syncStatus;
      });

      _addLog('📊 Updated sync status: $syncStatus');
    } catch (e) {
      _addLog('❌ Error creating test entry: $e');
    }
  }

  Future<void> _testManualSync() async {
    try {
      _addLog('🔄 Starting manual sync...');

      final online = await _offlineService.isOnline();
      if (!online) {
        _addLog('❌ Device is offline - cannot sync');
        return;
      }

      await _offlineService.syncAllData();

      final syncStatus = await _offlineService.getSyncStatus();
      setState(() {
        _syncCounts = syncStatus;
      });

      _addLog('✅ Manual sync completed');
      _addLog('📊 Post-sync status: $syncStatus');
    } catch (e) {
      _addLog('❌ Sync error: $e');
    }
  }

  Future<void> _checkConnectivity() async {
    final online = await _offlineService.isOnline();
    setState(() {
      _isOnline = online;
      _syncStatus = online
          ? 'Online - Ready to sync'
          : 'Offline - Will sync when connected';
    });

    _addLog('📡 Connection check: ${online ? "Online" : "Offline"}');
  }

  Future<void> _viewLocalData() async {
    try {
      final infusionLogs = await _offlineService.getInfusionLogs();
      final bleedLogs = await _offlineService.getBleedLogs();

      _addLog('📋 Local infusion logs: ${infusionLogs.length}');
      _addLog('📋 Local bleed logs: ${bleedLogs.length}');

      // Show details of unsynced items
      final unsyncedInfusions =
          infusionLogs.where((log) => log.needsSync).length;
      final unsyncedBleeds = bleedLogs.where((log) => log.needsSync).length;

      _addLog('⏳ Unsynced infusions: $unsyncedInfusions');
      _addLog('⏳ Unsynced bleeds: $unsyncedBleeds');
    } catch (e) {
      _addLog('❌ Error viewing local data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firestore Sync Test'),
        backgroundColor: _isOnline ? Colors.green : Colors.orange,
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _isOnline ? 'ONLINE' : 'OFFLINE',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sync Status',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(_syncStatus),
                    const SizedBox(height: 8),
                    Text(
                      'Pending Sync Items:',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text('Infusion Logs: ${_syncCounts['infusionLogs'] ?? 0}'),
                    Text('Bleed Logs: ${_syncCounts['bleedLogs'] ?? 0}'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Test Buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _testCreateOfflineEntry,
                  icon: const Icon(Icons.add),
                  label: const Text('Create Test Entry'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                ),
                ElevatedButton.icon(
                  onPressed: _testManualSync,
                  icon: const Icon(Icons.sync),
                  label: const Text('Manual Sync'),
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.green),
                ),
                ElevatedButton.icon(
                  onPressed: _checkConnectivity,
                  icon: const Icon(Icons.wifi),
                  label: const Text('Check Connection'),
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                ),
                ElevatedButton.icon(
                  onPressed: _viewLocalData,
                  icon: const Icon(Icons.storage),
                  label: const Text('View Local Data'),
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Sync Logs
            Text(
              'Sync Logs',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),

            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  itemCount: _syncLogs.length,
                  itemBuilder: (context, index) {
                    final log = _syncLogs[index];
                    Color? textColor;

                    if (log.contains('✅'))
                      textColor = Colors.green;
                    else if (log.contains('❌'))
                      textColor = Colors.red;
                    else if (log.contains('🔄'))
                      textColor = Colors.blue;
                    else if (log.contains('📡')) textColor = Colors.orange;

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: Text(
                        log,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: textColor,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Instructions
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How to Test Sync:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '1. Create test entries (stored locally)\n'
                    '2. Check pending sync count\n'
                    '3. Run manual sync (uploads to Firestore)\n'
                    '4. Verify sync count drops to 0\n'
                    '5. Check Firestore console to confirm data',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
