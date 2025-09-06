import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/post_reports_service.dart';

class AdminPostReportsScreen extends StatefulWidget {
  const AdminPostReportsScreen({super.key});

  @override
  State<AdminPostReportsScreen> createState() => _AdminPostReportsScreenState();
}

class _AdminPostReportsScreenState extends State<AdminPostReportsScreen>
    with TickerProviderStateMixin {
  final PostReportsService _reportsService = PostReportsService();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Post Reports',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.redAccent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.redAccent,
          unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: Colors.redAccent,
          tabs: const [
            Tab(text: 'All Reports'),
            Tab(text: 'Pending'),
            Tab(text: 'Reviewed'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildReportsTab('all'),
          _buildReportsTab('pending'),
          _buildReportsTab('reviewed'),
        ],
      ),
    );
  }

  Widget _buildReportsTab(String filter) {
    Stream<List<Map<String, dynamic>>> stream;

    switch (filter) {
      case 'pending':
        // Use fallback method for better reliability
        stream = _reportsService.getReportsByStatusFallback('pending');
        break;
      case 'reviewed':
        // Combine approved and dismissed reports for reviewed tab
        stream = _reportsService.getPostReportsStream().map((allReports) {
          return allReports
              .where((report) =>
                  report['status'] == 'approved' ||
                  report['status'] == 'dismissed')
              .toList();
        });
        break;
      default:
        stream = _reportsService.getPostReportsStream();
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        print('=== POST REPORTS DEBUG ($filter) ===');
        print('ConnectionState: ${snapshot.connectionState}');
        print('HasError: ${snapshot.hasError}');
        if (snapshot.hasError) {
          print('Error: ${snapshot.error}');
        }
        print('HasData: ${snapshot.hasData}');
        if (snapshot.hasData) {
          print('Reports count: ${snapshot.data?.length ?? 0}');
          for (var i = 0; i < (snapshot.data?.length ?? 0); i++) {
            final report = snapshot.data![i];
            print(
                'Report $i: postId=${report['postId']}, status=${report['status']}, reason=${report['reason']}');
          }
        }
        print('=== END POST REPORTS DEBUG ($filter) ===');

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.redAccent),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  FontAwesomeIcons.triangleExclamation,
                  size: 48,
                  color: Colors.orange.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading reports',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please try again later',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        final reports = snapshot.data ?? [];

        if (reports.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  FontAwesomeIcons.shieldHeart,
                  size: 48,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  filter == 'pending'
                      ? 'No pending reports'
                      : filter == 'reviewed'
                          ? 'No reviewed reports'
                          : 'No reports found',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  filter == 'pending'
                      ? 'All reports have been reviewed'
                      : filter == 'reviewed'
                          ? 'No reports have been reviewed yet'
                          : 'No posts have been reported',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: reports.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) => _buildReportCard(reports[index]),
        );
      },
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
    final status = report['status'] ?? 'pending';
    final timestamp = report['timestamp'] as dynamic;
    final postTimestamp = report['postTimestamp'] as dynamic;

    Color statusColor = Colors.orange;
    IconData statusIcon = FontAwesomeIcons.clock;

    if (status == 'approved') {
      statusColor = Colors.red;
      statusIcon = FontAwesomeIcons.check;
    } else if (status == 'dismissed') {
      statusColor = Colors.green;
      statusIcon = FontAwesomeIcons.xmark;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 6),
                      Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  _formatTimestamp(timestamp),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Report reason
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade100),
              ),
              child: Row(
                children: [
                  Icon(FontAwesomeIcons.flag,
                      size: 16, color: Colors.red.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Reported for: ${report['reason']}',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Post content
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.redAccent.withOpacity(0.1),
                        child: Text(
                          (report['postAuthorName'] ?? 'U')[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              report['postAuthorName'] ?? 'Unknown User',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            if (postTimestamp != null)
                              Text(
                                _formatTimestamp(postTimestamp),
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    report['postContent'] ?? 'No content',
                    style: const TextStyle(fontSize: 14),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Reporter info
            Row(
              children: [
                Icon(FontAwesomeIcons.user,
                    size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  'Reported by: ${report['reporterName'] ?? 'Unknown User'}',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
              ],
            ),

            if (report['adminNotes']?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(FontAwesomeIcons.noteSticky,
                        size: 14, color: Colors.blue.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Admin Notes:',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            report['adminNotes'],
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (status == 'pending') ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showResolveDialog(report, 'dismissed'),
                      icon: const Icon(FontAwesomeIcons.xmark, size: 16),
                      label: const Text('Dismiss'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green,
                        side: const BorderSide(color: Colors.green),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showResolveDialog(report, 'approved'),
                      icon: const Icon(FontAwesomeIcons.trash, size: 16),
                      label: const Text('Delete Post'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showResolveDialog(Map<String, dynamic> report, String action) {
    final TextEditingController notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(action == 'approved' ? 'Delete Post' : 'Dismiss Report'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              action == 'approved'
                  ? 'Are you sure you want to delete this post? This action cannot be undone.'
                  : 'Are you sure you want to dismiss this report?',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Admin Notes (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _resolveReport(report, action, notesController.text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: action == 'approved' ? Colors.red : Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text(action == 'approved' ? 'Delete' : 'Dismiss'),
          ),
        ],
      ),
    );
  }

  Future<void> _resolveReport(
      Map<String, dynamic> report, String action, String notes) async {
    try {
      await _reportsService.resolveReport(
        reportId: report['id'],
        action: action,
        adminNotes: notes,
      );

      if (action == 'approved') {
        await _reportsService.deleteReportedPost(report['postId']);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              action == 'approved'
                  ? 'Post deleted successfully'
                  : 'Report dismissed',
            ),
            backgroundColor: action == 'approved' ? Colors.red : Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';

    DateTime dateTime;
    if (timestamp is Timestamp) {
      dateTime = timestamp.toDate();
    } else if (timestamp is DateTime) {
      dateTime = timestamp;
    } else {
      return 'Unknown';
    }

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return DateFormat('MMM dd, yyyy').format(dateTime);
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
