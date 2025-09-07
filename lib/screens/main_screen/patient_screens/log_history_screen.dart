import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/firestore.dart';
import '../../../services/offline_service.dart';
import '../../../widgets/offline_indicator.dart';

class LogHistoryScreen extends StatefulWidget {
  const LogHistoryScreen({super.key});

  @override
  State<LogHistoryScreen> createState() => _LogHistoryScreenState();
}

class _LogHistoryScreenState extends State<LogHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirestoreService _firestoreService = FirestoreService();
  final OfflineService _offlineService = OfflineService();
  List<Map<String, dynamic>> _bleedLogs = [];
  List<Map<String, dynamic>> _infusionLogs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void didUpdateWidget(LogHistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload data when widget updates
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        print('Loading data for user: ${user.uid}'); // Debug log

        // Initialize offline service
        await _offlineService.initialize();

        // Load both online and offline data
        await Future.wait([
          _loadOnlineData(user.uid),
          _loadOfflineData(),
        ]);

        setState(() {
          _isLoading = false;
        });
      } else {
        print('No user logged in'); // Debug log
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading data: $e'); // Debug log for troubleshooting
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadOnlineData(String uid) async {
    try {
      // Load bleed logs from Firestore
      final bleeds = await _firestoreService.getBleedLogs(uid, limit: 50);
      print('Loaded ${bleeds.length} online bleed logs');

      // Load infusion logs from Firestore
      final infusions = await _firestoreService.getInfusionLogs(uid);
      print('Loaded ${infusions.length} online infusion logs');

      // Convert to unified format with sync status
      final onlineBleedLogs = bleeds
          .map((log) => {
                ...log,
                'isOffline': false,
                'needsSync': false,
                'syncStatus': 'synced',
              })
          .toList();

      final onlineInfusionLogs = infusions
          .map((log) => {
                ...log,
                'isOffline': false,
                'needsSync': false,
                'syncStatus': 'synced',
              })
          .toList();

      setState(() {
        // Merge online data with offline data, avoiding duplicates
        final allBleedLogs = [..._bleedLogs, ...onlineBleedLogs];
        final allInfusionLogs = [..._infusionLogs, ...onlineInfusionLogs];

        // Remove duplicates by ID (prefer online version if both exist)
        _bleedLogs = _removeDuplicates(allBleedLogs);
        _infusionLogs = _removeDuplicates(allInfusionLogs);

        // Sort by date (most recent first)
        _bleedLogs.sort((a, b) => _compareLogDates(b, a));
        _infusionLogs.sort((a, b) => _compareLogDates(b, a));
      });
    } catch (e) {
      print('Error loading online data: $e');
    }
  }

  Future<void> _loadOfflineData() async {
    try {
      // Load offline bleed logs
      final offlineBleedLogs = await _offlineService.getBleedLogs();
      print('Loaded ${offlineBleedLogs.length} offline bleed logs');

      // Load offline infusion logs
      final offlineInfusionLogs = await _offlineService.getInfusionLogs();
      print('Loaded ${offlineInfusionLogs.length} offline infusion logs');

      // Convert offline models to display format
      final formattedBleedLogs = offlineBleedLogs
          .map((log) => {
                'id': log.id,
                'date': log.date,
                'time': log.time,
                'bodyRegion': log.bodyRegion,
                'severity': log.severity,
                'specificRegion': log.specificRegion,
                'notes': log.notes,
                'createdAt': log.createdAt,
                'isOffline': true,
                'needsSync': log.needsSync,
                'syncStatus': log.needsSync ? 'pending' : 'synced',
                'syncedAt': log.syncedAt,
              })
          .toList();

      final formattedInfusionLogs = offlineInfusionLogs
          .map((log) => {
                'id': log.id,
                'date': log.date,
                'time': log.time,
                'medication': log.medication,
                'doseIU': log.doseIU,
                'notes': log.notes,
                'lotNumber': log.lotNumber,
                'createdAt': log.createdAt,
                'isOffline': true,
                'needsSync': log.needsSync,
                'syncStatus': log.needsSync ? 'pending' : 'synced',
                'syncedAt': log.syncedAt,
              })
          .toList();

      setState(() {
        _bleedLogs = formattedBleedLogs;
        _infusionLogs = formattedInfusionLogs;
      });
    } catch (e) {
      print('Error loading offline data: $e');
    }
  }

  int _compareLogDates(Map<String, dynamic> a, Map<String, dynamic> b) {
    try {
      // Use createdAt if available, otherwise use date + time
      DateTime dateA;
      DateTime dateB;

      if (a['createdAt'] != null) {
        dateA = a['createdAt'] is DateTime
            ? a['createdAt']
            : DateTime.parse(a['createdAt'].toString());
      } else {
        dateA = DateTime.parse('${a['date']} ${a['time'] ?? '00:00'}');
      }

      if (b['createdAt'] != null) {
        dateB = b['createdAt'] is DateTime
            ? b['createdAt']
            : DateTime.parse(b['createdAt'].toString());
      } else {
        dateB = DateTime.parse('${b['date']} ${b['time'] ?? '00:00'}');
      }

      return dateA.compareTo(dateB);
    } catch (e) {
      print('Error comparing dates: $e');
      return 0;
    }
  }

  // Remove duplicates from logs, preferring online version over offline
  List<Map<String, dynamic>> _removeDuplicates(
      List<Map<String, dynamic>> logs) {
    final Map<String, Map<String, dynamic>> uniqueLogs = {};

    for (final log in logs) {
      final String id = log['id']?.toString() ?? '';

      if (id.isNotEmpty) {
        // If this ID already exists, prefer the online version (isOffline == false)
        if (uniqueLogs.containsKey(id)) {
          final existing = uniqueLogs[id]!;
          final isExistingOffline = existing['isOffline'] == true;
          final isCurrentOffline = log['isOffline'] == true;

          // Keep online version if we have both
          if (isExistingOffline && !isCurrentOffline) {
            uniqueLogs[id] = log; // Replace offline with online
          }
          // If both are online or both are offline, keep the first one
        } else {
          uniqueLogs[id] = log;
        }
      } else {
        // If no ID, try to deduplicate by content (date + time + other fields)
        final String contentKey = _generateContentKey(log);
        if (!uniqueLogs.containsKey(contentKey)) {
          uniqueLogs[contentKey] = log;
        }
      }
    }

    return uniqueLogs.values.toList();
  }

  // Generate a content-based key for logs without IDs
  String _generateContentKey(Map<String, dynamic> log) {
    final date = log['date']?.toString() ?? '';
    final time = log['time']?.toString() ?? '';
    final bodyRegion = log['bodyRegion']?.toString() ?? '';
    final medication = log['medication']?.toString() ?? '';
    final severity = log['severity']?.toString() ?? '';
    final dose = log['doseIU']?.toString() ?? '';

    return '$date-$time-$bodyRegion-$medication-$severity-$dose';
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Log History',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _showCalendarView,
            icon: const Icon(Icons.calendar_month),
            tooltip: 'Calendar View',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
          tabs: const [
            Tab(text: 'Bleeding Episodes'),
            Tab(text: 'Infusion Taken'),
          ],
        ),
      ),
      // TODO: Add a calendar icon and if opened, show a calendar view of logs
      body: Column(
        children: [
          const OfflineIndicator(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Bleeding Episodes tab: show Hive logs
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.bloodtype,
                              color: Colors.redAccent, size: 28),
                          SizedBox(width: 12),
                          Text(
                            'Bleeding Episodes',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Track and monitor your bleeding episodes',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 16),
                      ),
                      const SizedBox(height: 24),
                      Expanded(
                        child: _isLoading
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.redAccent,
                                ),
                              )
                            : _bleedLogs.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.history,
                                          size: 80,
                                          color: Colors.grey.shade400,
                                        ),
                                        const SizedBox(height: 24),
                                        Text(
                                          'No bleeding episodes yet',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Your bleeding episodes will appear here',
                                          style: TextStyle(
                                            color: Colors.grey.shade500,
                                            fontSize: 16,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  )
                                : RefreshIndicator(
                                    onRefresh: _loadData,
                                    child: ListView.separated(
                                      itemCount: _bleedLogs.length,
                                      separatorBuilder: (context, index) =>
                                          Container(
                                        height: 1,
                                        margin: const EdgeInsets.symmetric(
                                            vertical: 8),
                                        color: Colors.grey.shade200,
                                      ),
                                      itemBuilder: (context, index) {
                                        final log = _bleedLogs[index];

                                        return GestureDetector(
                                          onTap: () =>
                                              _showBleedingEpisodeDetails(log),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 16,
                                              horizontal: 20,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 48,
                                                  height: 48,
                                                  decoration: BoxDecoration(
                                                    color: _getSeverityColor(
                                                      log['severity'] ?? 'Mild',
                                                    ).withValues(alpha: 0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  child: Icon(
                                                    Icons.bloodtype,
                                                    color: _getSeverityColor(
                                                      log['severity'] ?? 'Mild',
                                                    ),
                                                    size: 24,
                                                  ),
                                                ),
                                                const SizedBox(width: 16),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Text(
                                                            log['bodyRegion'] ??
                                                                'Unknown',
                                                            style:
                                                                const TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 16,
                                                              color: Colors
                                                                  .black87,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              width: 8),
                                                          Container(
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                              horizontal: 8,
                                                              vertical: 4,
                                                            ),
                                                            decoration:
                                                                BoxDecoration(
                                                              color:
                                                                  _getSeverityColor(
                                                                log['severity'] ??
                                                                    'Mild',
                                                              ).withValues(
                                                                      alpha:
                                                                          0.1),
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          6),
                                                            ),
                                                            child: Text(
                                                              log['severity'] ??
                                                                  'Mild',
                                                              style: TextStyle(
                                                                color:
                                                                    _getSeverityColor(
                                                                  log['severity'] ??
                                                                      'Mild',
                                                                ),
                                                                fontSize: 12,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              width: 8),
                                                          _buildSyncStatusIndicator(
                                                              log),
                                                        ],
                                                      ),
                                                      if (log['specificRegion'] !=
                                                              null &&
                                                          log['specificRegion']
                                                              .toString()
                                                              .isNotEmpty)
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .only(top: 4),
                                                          child: Text(
                                                            log['specificRegion'],
                                                            style: TextStyle(
                                                              color: Colors.grey
                                                                  .shade600,
                                                              fontSize: 14,
                                                            ),
                                                          ),
                                                        ),
                                                      const SizedBox(height: 8),
                                                      Row(
                                                        children: [
                                                          Icon(
                                                            Icons
                                                                .calendar_today,
                                                            size: 16,
                                                            color: Colors
                                                                .grey.shade600,
                                                          ),
                                                          const SizedBox(
                                                              width: 4),
                                                          Text(
                                                            log['date'] ??
                                                                _formatDate(
                                                                  log['createdAt'],
                                                                ),
                                                            style: TextStyle(
                                                              color: Colors.grey
                                                                  .shade600,
                                                              fontSize: 14,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              width: 16),
                                                          Icon(
                                                            Icons.access_time,
                                                            size: 16,
                                                            color: Colors
                                                                .grey.shade600,
                                                          ),
                                                          const SizedBox(
                                                              width: 4),
                                                          Text(
                                                            log['time'] ??
                                                                _formatTime(
                                                                  log['createdAt'],
                                                                ),
                                                            style: TextStyle(
                                                              color: Colors.grey
                                                                  .shade600,
                                                              fontSize: 14,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      if (log['notes'] !=
                                                              null &&
                                                          log['notes']
                                                              .toString()
                                                              .isNotEmpty)
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .only(top: 8),
                                                          child: Row(
                                                            children: [
                                                              Icon(
                                                                Icons.note,
                                                                size: 16,
                                                                color: Colors
                                                                    .grey
                                                                    .shade600,
                                                              ),
                                                              const SizedBox(
                                                                  width: 4),
                                                              Expanded(
                                                                child: Text(
                                                                  log['notes'],
                                                                  style:
                                                                      TextStyle(
                                                                    color: Colors
                                                                        .grey
                                                                        .shade600,
                                                                    fontSize:
                                                                        14,
                                                                    fontStyle:
                                                                        FontStyle
                                                                            .italic,
                                                                  ),
                                                                  maxLines: 2,
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                                Icon(
                                                  Icons.chevron_right,
                                                  color: Colors.grey.shade400,
                                                  size: 20,
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                      ),
                    ],
                  ),
                ),
                // Infusion Taken tab
                _buildInfusionTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: "log_history_fab", // Unique tag to avoid conflicts
        foregroundColor: Colors.white,
        tooltip: 'Add New Log',
        onPressed: () {
          showModalBottomSheet(
            context: context,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (context) {
              return SafeArea(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Add New Log',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildActionTile(
                        icon: Icons.bloodtype,
                        title: 'Log New Bleeding Episode',
                        subtitle: 'Record a new bleeding incident',
                        color: Colors.redAccent,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/log_bleed');
                        },
                      ),
                      const SizedBox(height: 10),
                      _buildActionTile(
                        icon: Icons.medical_services,
                        title: 'Log New Infusion Taken',
                        subtitle: 'Record treatment administration',
                        color: Colors.green,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/log_infusion');
                        },
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              );
            },
          );
        },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
        backgroundColor: Colors.amber,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildInfusionTab() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.medical_services, color: Colors.green, size: 28),
              SizedBox(width: 12),
              Text(
                'Infusion Taken',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Track your treatment history',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.green))
                : _infusionLogs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.history,
                              size: 80,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'No infusion logs yet',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Your infusion treatment history will appear here',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        child: ListView.separated(
                          itemCount: _infusionLogs.length,
                          separatorBuilder: (context, index) => Container(
                            height: 1,
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            color: Colors.grey.shade200,
                          ),
                          itemBuilder: (context, index) {
                            final log = _infusionLogs[index];
                            return GestureDetector(
                              onTap: () => _showInfusionDetails(log),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                  horizontal: 20,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.green.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.medical_services,
                                        color: Colors.green,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  '${log['medication'] ?? 'Unknown Medication'}',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                              ),
                                              _buildSyncStatusIndicator(log),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Dose: ${log['doseIU'] ?? '0'} IU',
                                            style: TextStyle(
                                              color: Colors.grey.shade700,
                                              fontSize: 14,
                                            ),
                                          ),
                                          if (log['lotNumber'] != null &&
                                              log['lotNumber']
                                                  .toString()
                                                  .isNotEmpty)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.only(top: 4),
                                              child: Text(
                                                'Lot: ${log['lotNumber']}',
                                                style: TextStyle(
                                                  color: Colors.grey.shade700,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.access_time,
                                                size: 16,
                                                color: Colors.grey.shade600,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${log['time'] ?? 'N/A'}',
                                                style: TextStyle(
                                                  color: Colors.grey.shade600,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                              Icon(
                                                Icons.calendar_today,
                                                size: 16,
                                                color: Colors.grey.shade600,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${log['date'] ?? 'N/A'}',
                                                style: TextStyle(
                                                  color: Colors.grey.shade600,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right,
                                      color: Colors.grey.shade400,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey.shade400,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'mild':
        return Colors.green;
      case 'moderate':
        return Colors.orange;
      case 'severe':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(dynamic timestamp) {
    try {
      if (timestamp != null) {
        DateTime date;
        if (timestamp is int) {
          date = DateTime.fromMillisecondsSinceEpoch(timestamp);
        } else if (timestamp.toDate != null) {
          date = timestamp.toDate();
        } else {
          return 'Unknown';
        }
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      // Handle error silently
    }
    return 'Unknown';
  }

  String _formatTime(dynamic timestamp) {
    try {
      if (timestamp != null) {
        DateTime date;
        if (timestamp is int) {
          date = DateTime.fromMillisecondsSinceEpoch(timestamp);
        } else if (timestamp.toDate != null) {
          date = timestamp.toDate();
        } else {
          return 'Unknown';
        }
        return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      // Handle error silently
    }
    return 'Unknown';
  }

  void _showBleedingEpisodeDetails(Map<String, dynamic> log) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _getSeverityColor(log['severity'] ?? 'Mild')
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.bloodtype,
                      color: _getSeverityColor(log['severity'] ?? 'Mild'),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bleeding Episode',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          log['bodyRegion'] ?? 'Unknown Region',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: Colors.grey.shade600),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey.shade100,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailSection(
                      title: 'Location Details',
                      icon: Icons.location_on,
                      items: [
                        {
                          'label': 'Body Region',
                          'value': log['bodyRegion'] ?? 'Not specified'
                        },
                        if (log['specificRegion'] != null &&
                            log['specificRegion'].toString().isNotEmpty)
                          {
                            'label': 'Specific Area',
                            'value': log['specificRegion']
                          },
                        if (log['sideOfBody'] != null &&
                            log['sideOfBody'].toString().isNotEmpty)
                          {'label': 'Side of Body', 'value': log['sideOfBody']},
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildDetailSection(
                      title: 'Severity & Symptoms',
                      icon: Icons.warning,
                      items: [
                        {
                          'label': 'Severity',
                          'value': log['severity'] ?? 'Not specified'
                        },
                        if (log['painLevel'] != null)
                          {
                            'label': 'Pain Level',
                            'value': '${log['painLevel']}/10'
                          },
                        if (log['symptoms'] != null &&
                            log['symptoms'].toString().isNotEmpty)
                          {'label': 'Symptoms', 'value': log['symptoms']},
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildDetailSection(
                      title: 'Date & Time',
                      icon: Icons.schedule,
                      items: [
                        {
                          'label': 'Date',
                          'value': log['date'] ?? _formatDate(log['createdAt'])
                        },
                        {
                          'label': 'Time',
                          'value': log['time'] ?? _formatTime(log['createdAt'])
                        },
                        if (log['createdAt'] != null)
                          {
                            'label': 'Logged on',
                            'value': _formatDate(log['createdAt'])
                          },
                      ],
                    ),
                    if (log['notes'] != null &&
                        log['notes'].toString().isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _buildDetailSection(
                        title: 'Additional Notes',
                        icon: Icons.note,
                        items: [
                          {'label': 'Notes', 'value': log['notes']},
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInfusionDetails(Map<String, dynamic> log) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.medical_services,
                      color: Colors.green,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Infusion Treatment',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          log['medication'] ?? 'Unknown Medication',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: Colors.grey.shade600),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey.shade100,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailSection(
                      title: 'Medication Details',
                      icon: Icons.medication,
                      items: [
                        {
                          'label': 'Medication',
                          'value': log['medication'] ?? 'Not specified'
                        },
                        {
                          'label': 'Dose (IU)',
                          'value': '${log['doseIU'] ?? '0'} IU'
                        },
                        if (log['reason'] != null &&
                            log['reason'].toString().isNotEmpty)
                          {'label': 'Reason', 'value': log['reason']},
                        if (log['bodyWeight'] != null)
                          {
                            'label': 'Body Weight',
                            'value': '${log['bodyWeight']} kg'
                          },
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildDetailSection(
                      title: 'Administration',
                      icon: Icons.schedule,
                      items: [
                        {
                          'label': 'Date',
                          'value': log['date'] ?? 'Not specified'
                        },
                        {
                          'label': 'Time',
                          'value': log['time'] ?? 'Not specified'
                        },
                        if (log['administeredBy'] != null &&
                            log['administeredBy'].toString().isNotEmpty)
                          {
                            'label': 'Administered by',
                            'value': log['administeredBy']
                          },
                        if (log['location'] != null &&
                            log['location'].toString().isNotEmpty)
                          {'label': 'Location', 'value': log['location']},
                      ],
                    ),
                    if (log['sideEffects'] != null &&
                        log['sideEffects'].toString().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _buildDetailSection(
                        title: 'Side Effects',
                        icon: Icons.warning_amber,
                        items: [
                          {
                            'label': 'Side Effects',
                            'value': log['sideEffects']
                          },
                        ],
                      ),
                    ],
                    if (log['notes'] != null &&
                        log['notes'].toString().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _buildDetailSection(
                        title: 'Additional Notes',
                        icon: Icons.note,
                        items: [
                          {'label': 'Notes', 'value': log['notes']},
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection({
    required String title,
    required IconData icon,
    required List<Map<String, String>> items,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.redAccent, size: 16),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(
                        '${item['label']}:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item['value'] ?? 'Not specified',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildSyncStatusIndicator(Map<String, dynamic> log) {
    final syncStatus = log['syncStatus'] ?? 'synced';

    switch (syncStatus) {
      case 'pending':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.sync,
                size: 12,
                color: Colors.orange.shade700,
              ),
              const SizedBox(width: 4),
              Text(
                'Offline',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade700,
                ),
              ),
            ],
          ),
        );
      case 'synced':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle,
                size: 12,
                color: Colors.green.shade700,
              ),
              const SizedBox(width: 4),
              Text(
                'Synced',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  void _showCalendarView() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CalendarViewWidget(
        bleedLogs: _bleedLogs,
        infusionLogs: _infusionLogs,
      ),
    );
  }
}

class _CalendarViewWidget extends StatefulWidget {
  final List<Map<String, dynamic>> bleedLogs;
  final List<Map<String, dynamic>> infusionLogs;

  const _CalendarViewWidget({
    required this.bleedLogs,
    required this.infusionLogs,
  });

  @override
  State<_CalendarViewWidget> createState() => _CalendarViewWidgetState();
}

class _CalendarViewWidgetState extends State<_CalendarViewWidget> {
  DateTime _selectedMonth = DateTime.now();
  DateTime? _selectedDate;
  List<Map<String, dynamic>> _selectedDateLogs = [];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.calendar_month,
                    color: Colors.amber,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Calendar View',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        'View bleeding episodes and infusions by date',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),

          // Month Navigation
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      _selectedMonth = DateTime(
                        _selectedMonth.year,
                        _selectedMonth.month - 1,
                      );
                    });
                  },
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    _getMonthYearString(_selectedMonth),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _selectedMonth = DateTime(
                        _selectedMonth.year,
                        _selectedMonth.month + 1,
                      );
                    });
                  },
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),

          // Calendar Grid
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Weekday headers
                  Row(
                    children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                        .map((day) => Expanded(
                              child: Center(
                                child: Text(
                                  day,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 8),

                  // Calendar grid
                  Expanded(
                    child: _buildCalendarGrid(),
                  ),

                  // Legend
                  if (_hasAnyLogs())
                    Container(
                      margin: const EdgeInsets.only(top: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildLegendItem(
                            color: Colors.redAccent,
                            label: 'Bleeding',
                            icon: Icons.bloodtype,
                          ),
                          _buildLegendItem(
                            color: Colors.green,
                            label: 'Infusion',
                            icon: Icons.medical_services,
                          ),
                          _buildLegendItem(
                            color: Colors.purple,
                            label: 'Both',
                            icon: Icons.circle,
                          ),
                        ],
                      ),
                    ),

                  // Selected date details
                  if (_selectedDate != null && _selectedDateLogs.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Logs for ${_formatSelectedDate(_selectedDate!)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ..._selectedDateLogs.map((log) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  children: [
                                    Icon(
                                      _getLogIcon(log),
                                      size: 16,
                                      color: _getLogColor(log),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _getLogSummary(log),
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final firstDayOfMonth =
        DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final lastDayOfMonth =
        DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    final firstWeekday =
        firstDayOfMonth.weekday % 7; // Convert to 0-based index
    final daysInMonth = lastDayOfMonth.day;

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1.0,
      ),
      itemCount: 42, // 6 weeks × 7 days
      itemBuilder: (context, index) {
        if (index < firstWeekday || index >= firstWeekday + daysInMonth) {
          return const SizedBox(); // Empty cell
        }

        final day = index - firstWeekday + 1;
        final currentDate =
            DateTime(_selectedMonth.year, _selectedMonth.month, day);
        final logsForDate = _getLogsForDate(currentDate);
        final isSelected = _selectedDate?.day == day &&
            _selectedDate?.month == _selectedMonth.month &&
            _selectedDate?.year == _selectedMonth.year;
        final isToday = _isToday(currentDate);

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedDate = currentDate;
              _selectedDateLogs = logsForDate;
            });
          },
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.amber
                  : isToday
                      ? Colors.amber.withValues(alpha: 0.3)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isToday && !isSelected
                  ? Border.all(color: Colors.amber, width: 2)
                  : null,
            ),
            child: Stack(
              children: [
                Center(
                  child: Text(
                    day.toString(),
                    style: TextStyle(
                      fontWeight: isSelected || isToday
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected
                          ? Colors.white
                          : isToday
                              ? Colors.amber.shade700
                              : Colors.black87,
                    ),
                  ),
                ),
                if (logsForDate.isNotEmpty)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: _buildDateIndicator(logsForDate),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDateIndicator(List<Map<String, dynamic>> logs) {
    // Check for bleeding episodes using multiple possible field names
    final hasBleed = logs.any((log) =>
        log['bodyRegion'] != null ||
        log['bodyPart'] != null ||
        log['location'] != null ||
        log['severity'] != null ||
        log.containsKey('bodyRegion') ||
        log.containsKey('bodyPart') ||
        log.containsKey('location') ||
        log.containsKey('severity'));

    // Check for infusions using multiple possible field names
    final hasInfusion = logs.any((log) =>
        log['medication'] != null ||
        log['doseIU'] != null ||
        log['dose'] != null ||
        log.containsKey('medication') ||
        log.containsKey('doseIU') ||
        log.containsKey('dose'));

    Color color;
    if (hasBleed && hasInfusion) {
      color = Colors.purple;
    } else if (hasBleed) {
      color = Colors.redAccent;
    } else {
      color = Colors.green;
    }

    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required String label,
    required IconData icon,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _getLogsForDate(DateTime date) {
    final dateString =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final logs = <Map<String, dynamic>>[];

    // Add bleeding episodes for this date
    for (final log in widget.bleedLogs) {
      final logDateStr = _normalizeDate(log['date']?.toString() ?? '');
      if (logDateStr == dateString) {
        logs.add(log);
      }
    }

    // Add infusion logs for this date
    for (final log in widget.infusionLogs) {
      final logDateStr = _normalizeDate(log['date']?.toString() ?? '');
      if (logDateStr == dateString) {
        logs.add(log);
      }
    }

    return logs;
  }

  // Helper method to normalize different date formats to YYYY-MM-DD
  String _normalizeDate(String dateStr) {
    if (dateStr.isEmpty) return '';

    try {
      // If already in YYYY-MM-DD format
      if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dateStr)) {
        return dateStr;
      }

      // If in "Mon DD, YYYY" format (e.g., "Sep 06, 2025")
      if (RegExp(r'^[A-Z][a-z]{2} \d{2}, \d{4}$').hasMatch(dateStr)) {
        final parts = dateStr.split(' ');
        final monthName = parts[0];
        final day = parts[1].replaceAll(',', '');
        final year = parts[2];

        const monthMap = {
          'Jan': '01',
          'Feb': '02',
          'Mar': '03',
          'Apr': '04',
          'May': '05',
          'Jun': '06',
          'Jul': '07',
          'Aug': '08',
          'Sep': '09',
          'Oct': '10',
          'Nov': '11',
          'Dec': '12'
        };

        final monthNum = monthMap[monthName] ?? '01';
        return '$year-$monthNum-${day.padLeft(2, '0')}';
      }

      // Try parsing as DateTime and reformatting
      final parsedDate = DateTime.tryParse(dateStr);
      if (parsedDate != null) {
        return '${parsedDate.year}-${parsedDate.month.toString().padLeft(2, '0')}-${parsedDate.day.toString().padLeft(2, '0')}';
      }

      return dateStr;
    } catch (e) {
      return dateStr;
    }
  }

  bool _hasAnyLogs() {
    return widget.bleedLogs.isNotEmpty || widget.infusionLogs.isNotEmpty;
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  String _getMonthYearString(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  String _formatSelectedDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  IconData _getLogIcon(Map<String, dynamic> log) {
    if (log['bodyRegion'] != null) {
      return Icons.bloodtype;
    } else {
      return Icons.medical_services;
    }
  }

  Color _getLogColor(Map<String, dynamic> log) {
    if (log['bodyRegion'] != null) {
      return Colors.redAccent;
    } else {
      return Colors.green;
    }
  }

  String _getLogSummary(Map<String, dynamic> log) {
    if (log['bodyRegion'] != null) {
      return '${log['bodyRegion']} - ${log['severity'] ?? 'Unknown'}';
    } else {
      return '${log['medication'] ?? 'Infusion'} - ${log['doseIU'] ?? '0'} IU';
    }
  }
}

// TODO: Logic for viewing and managing logs in bleeding episodes and infusion taken
