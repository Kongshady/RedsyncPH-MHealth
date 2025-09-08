import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/firestore.dart';
import '../../../services/medication_notification_service.dart';
import '../../../widgets/offline_indicator.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final MedicationNotificationService _medicationNotificationService =
      MedicationNotificationService();
  final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
  }

  Future<void> _markAllAsRead() async {
    if (uid.isNotEmpty) {
      await _firestoreService.markAllNotificationsAsRead(uid);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All notifications marked as read'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _deleteAll() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            'Delete All Notifications',
            style:
                TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Are you sure you want to delete all notifications? This action cannot be undone.',
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                if (uid.isNotEmpty) {
                  await _firestoreService.deleteAllNotifications(uid);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('All notifications deleted'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              child:
                  const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // Method to manually check for due medications (for testing)
  Future<void> _checkMedicationReminders() async {
    try {
      await _medicationNotificationService.checkNow();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Checked for medication reminders'),
          backgroundColor: Colors.blue,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error checking medications: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.redAccent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _checkMedicationReminders,
            icon: const Icon(Icons.medication, size: 18),
            tooltip: 'Check medication reminders',
          ),
          IconButton(
            onPressed: _markAllAsRead,
            icon: const Icon(FontAwesomeIcons.checkDouble, size: 18),
            tooltip: 'Mark all as read',
          ),
          IconButton(
            onPressed: _deleteAll,
            icon: const Icon(FontAwesomeIcons.trash, size: 18),
            tooltip: 'Delete all',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          const OfflineIndicator(),
          Expanded(
            child: SafeArea(
              child: uid.isEmpty
                  ? _buildLoadingState()
                  : StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('notifications')
                          .where('uid', isEqualTo: uid)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return _buildLoadingState();
                        }

                        if (snapshot.hasError) {
                          return _buildErrorState();
                        }

                        final docs = snapshot.data?.docs ?? [];

                        // Sort docs on client side by timestamp
                        docs.sort((a, b) {
                          final dataA = a.data() as Map<String, dynamic>;
                          final dataB = b.data() as Map<String, dynamic>;
                          final timestampA = dataA['timestamp'] as Timestamp?;
                          final timestampB = dataB['timestamp'] as Timestamp?;

                          if (timestampA != null && timestampB != null) {
                            return timestampB.compareTo(timestampA);
                          }
                          return 0;
                        });

                        if (docs.isEmpty) {
                          return _buildEmptyState();
                        }

                        return _buildNotificationsList(docs);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: Colors.redAccent,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading notifications...',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(40),
            ),
            child: Icon(
              FontAwesomeIcons.triangleExclamation,
              color: Colors.red.shade400,
              size: 32,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Error loading notifications',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please try again later',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => setState(() {}),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(
                FontAwesomeIcons.bell,
                color: Colors.grey.shade400,
                size: 40,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'No notifications yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Important updates and messages will appear here',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 16,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsList(List<DocumentSnapshot> docs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text(
            'Recent',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              return _buildNotificationItem(doc, data);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationItem(
    DocumentSnapshot doc,
    Map<String, dynamic> data,
  ) {
    final isRead = data['read'] ?? false;
    final text = data['text'] ?? 'No message';
    final timestamp = data['timestamp'];
    final type = data['type'] as String?;

    // Get icon and color based on notification type
    final iconData = _getNotificationIcon(type);
    final iconColor = _getNotificationColor(type, isRead);
    final backgroundColor = _getNotificationBackgroundColor(type, isRead);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isRead ? Colors.grey.shade200 : Colors.red.shade200,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () async {
          if (!isRead) {
            await _firestoreService.markNotificationAsRead(doc.id);
          }
          // Handle navigation based on notification type
          _handleNotificationTap(data);
        },
        borderRadius: BorderRadius.circular(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isRead
                    ? Colors.grey.shade200
                    : _getNotificationIconBackgroundColor(type),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                iconData,
                color: iconColor,
                size: 16,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          text,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight:
                                isRead ? FontWeight.w500 : FontWeight.w600,
                            color: Colors.black87,
                            height: 1.4,
                          ),
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(top: 4, left: 8),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatTime(timestamp),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Handle notification navigation
  void _handleNotificationTap(Map<String, dynamic> notificationData) {
    final type = notificationData['type'] as String?;
    final data = notificationData['data'] as Map<String, dynamic>?;

    if (type == null || data == null) {
      // For old notifications without type, just show a message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notification details not available'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    switch (type) {
      case 'post_like':
      case 'post_comment':
      case 'post_share':
        _navigateToPost(data['postId'] as String?);
        break;
      case 'message':
        _navigateToMessages(data['senderId'] as String?);
        break;
      case 'bleeding_log':
        _navigateToBleedingLog(data);
        break;
      case 'medication_reminder':
        _navigateToMedicationReminder(data);
        break;
      default:
        // Unknown notification type
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unknown notification type: $type'),
            backgroundColor: Colors.grey,
          ),
        );
    }
  }

  // Navigate to specific post
  void _navigateToPost(String? postId) {
    if (postId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Post not found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Navigate to Community Screen with the specific post
    Navigator.of(context).pop(); // Close notifications screen
    Navigator.pushNamed(
      context,
      '/community',
      arguments: {'openPostId': postId}, // Pass the post ID as an argument
    );
  }

  // Navigate to messages/chat with specific user
  void _navigateToMessages(String? senderId) {
    if (senderId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sender not found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Navigate to Messages Screen with specific user
    Navigator.of(context).pop(); // Close notifications screen
    Navigator.pushNamed(
      context,
      '/messages',
      arguments: {
        'openChatWithUserId': senderId,
      }, // Pass the sender ID as an argument
    );
  }

  // Navigate to bleeding log details or patient details for healthcare providers
  void _navigateToBleedingLog(Map<String, dynamic> data) {
    final patientUid = data['patientUid'] as String?;
    final patientName = data['patientName'] as String?;

    if (patientUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Patient information not found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if this is a healthcare provider viewing patient data
    Navigator.of(context).pop(); // Close notifications screen

    // For healthcare providers, navigate to patient details screen
    // We'll show a detailed view that includes the bleeding log information
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bleeding Episode Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Patient: ${patientName ?? 'Unknown'}'),
            const SizedBox(height: 8),
            Text('Date: ${data['date'] ?? 'Unknown'}'),
            Text('Body Region: ${data['bodyRegion'] ?? 'Unknown'}'),
            Text('Severity: ${data['severity'] ?? 'Unknown'}'),
            const SizedBox(height: 16),
            Text(
              'This patient has logged a bleeding episode. You can view their complete medical history by accessing their patient profile.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              // Navigate to patient details if available
              // This would require importing the patient details screen
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('View patient details in your patients list'),
                  backgroundColor: Colors.blue,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('View Patient',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Navigate to medication reminder details
  void _navigateToMedicationReminder(Map<String, dynamic> data) {
    final medicationName = data['medicationName'] as String?;
    final dosage = data['dosage'] as String?;
    final administrationType = data['administrationType'] as String?;
    final scheduledTime = data['scheduledTime'] as String?;
    final frequency = data['frequency'] as String?;

    // Close notifications screen first
    Navigator.of(context).pop();

    // Show medication reminder details
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.medication,
                color: Colors.blue.shade700,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Medication Reminder',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (medicationName != null) ...[
              Text(
                'Medication: $medicationName',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (dosage != null) ...[
              Text('Dosage: $dosage'),
              const SizedBox(height: 4),
            ],
            if (administrationType != null) ...[
              Text('Type: $administrationType'),
              const SizedBox(height: 4),
            ],
            if (scheduledTime != null) ...[
              Text('Scheduled Time: $scheduledTime'),
              const SizedBox(height: 4),
            ],
            if (frequency != null) ...[
              Text('Frequency: $frequency'),
              const SizedBox(height: 8),
            ],
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.green.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Remember to take your medication as prescribed. If you have any questions, consult your healthcare provider.',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to medication reminders screen
              Navigator.pushNamed(context, '/medication-reminders');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
            ),
            child: const Text(
              'View All Reminders',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods for notification styling
  IconData _getNotificationIcon(String? type) {
    switch (type) {
      case 'medication_reminder':
        return Icons.medication;
      case 'post_like':
      case 'post_comment':
      case 'post_share':
        return FontAwesomeIcons.heart;
      case 'message':
        return FontAwesomeIcons.message;
      case 'bleeding_log':
        return FontAwesomeIcons.droplet;
      default:
        return FontAwesomeIcons.bell;
    }
  }

  Color _getNotificationColor(String? type, bool isRead) {
    if (isRead) return Colors.grey.shade500;

    switch (type) {
      case 'medication_reminder':
        return Colors.blue.shade600;
      case 'post_like':
      case 'post_comment':
      case 'post_share':
        return Colors.pink.shade600;
      case 'message':
        return Colors.green.shade600;
      case 'bleeding_log':
        return Colors.red.shade600;
      default:
        return Colors.redAccent;
    }
  }

  Color _getNotificationBackgroundColor(String? type, bool isRead) {
    if (isRead) return Colors.grey.shade50;

    switch (type) {
      case 'medication_reminder':
        return Colors.blue.shade50;
      case 'post_like':
      case 'post_comment':
      case 'post_share':
        return Colors.pink.shade50;
      case 'message':
        return Colors.green.shade50;
      case 'bleeding_log':
        return Colors.red.shade50;
      default:
        return Colors.red.shade50;
    }
  }

  Color _getNotificationIconBackgroundColor(String? type) {
    switch (type) {
      case 'medication_reminder':
        return Colors.blue.withOpacity(0.1);
      case 'post_like':
      case 'post_comment':
      case 'post_share':
        return Colors.pink.withOpacity(0.1);
      case 'message':
        return Colors.green.withOpacity(0.1);
      case 'bleeding_log':
        return Colors.red.withOpacity(0.1);
      default:
        return Colors.redAccent.withOpacity(0.1);
    }
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final dt = timestamp.toDate();
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';

      return '${dt.day}/${dt.month}/${dt.year}';
    }
    return 'Unknown time';
  }
}
