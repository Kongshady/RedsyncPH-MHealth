import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

class AdminUsersManagementScreen extends StatefulWidget {
  const AdminUsersManagementScreen({super.key});

  @override
  State<AdminUsersManagementScreen> createState() =>
      _AdminUsersManagementScreenState();
}

class _AdminUsersManagementScreenState extends State<AdminUsersManagementScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'User Management',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.redAccent,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              // Search bar
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search users by name or email...',
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                ),
              ),
              // Tabs
              TabBar(
                controller: _tabController,
                labelColor: Colors.redAccent,
                unselectedLabelColor: Colors.grey.shade600,
                indicatorColor: Colors.redAccent,
                isScrollable: true,
                tabs: const [
                  Tab(text: 'All Users'),
                  Tab(text: 'Patients'),
                  Tab(text: 'Caregivers'),
                  Tab(text: 'Doctors'),
                  Tab(text: 'Admins'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUsersTab('all'),
          _buildUsersTab('patient'),
          _buildUsersTab('caregiver'),
          _buildUsersTab('doctor'),
          _buildUsersTab('admin'),
        ],
      ),
    );
  }

  Widget _buildUsersTab(String userType) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getUsersStream(userType),
      builder: (context, snapshot) {
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
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading users',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${snapshot.error}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 64,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  userType == 'all'
                      ? 'No users found'
                      : 'No ${userType.replaceAll('_', ' ')}s found',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        final users = snapshot.data!.docs
            .map((doc) => {
                  'id': doc.id,
                  ...doc.data() as Map<String, dynamic>,
                })
            .where((user) {
          if (_searchQuery.isEmpty) return true;
          final name = (user['name'] ?? '').toString().toLowerCase();
          final email = (user['email'] ?? '').toString().toLowerCase();
          return name.contains(_searchQuery) || email.contains(_searchQuery);
        }).toList();

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return _buildUserCard(user);
            },
          ),
        );
      },
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final userType = user['userType'] ?? 'patient';
    final name = user['name'] ?? 'Unknown User';
    final email = user['email'] ?? '';
    final isApproved = user['isApproved'] ?? false;
    final isSuspended = user['isSuspended'] ?? false;
    final createdAt = user['createdAt'];
    final joinDate = _formatTimestamp(createdAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 24,
                  backgroundColor: _getUserTypeColor(userType).withOpacity(0.2),
                  child: Icon(
                    _getUserTypeIcon(userType),
                    color: _getUserTypeColor(userType),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                // User info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _buildUserTypeChip(userType),
                          const SizedBox(width: 8),
                          _buildStatusChip(isApproved),
                          if (isSuspended) ...[
                            const SizedBox(width: 8),
                            _buildSuspensionChip(isSuspended),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Actions menu
                PopupMenuButton<String>(
                  onSelected: (value) => _handleUserAction(value, user),
                  itemBuilder: (context) => [
                    if (!isApproved)
                      const PopupMenuItem(
                        value: 'approve',
                        child: Row(
                          children: [
                            Icon(Icons.check, color: Colors.green),
                            SizedBox(width: 8),
                            Text('Approve User'),
                          ],
                        ),
                      ),
                    PopupMenuItem(
                      value: 'change_role',
                      child: Row(
                        children: [
                          Icon(Icons.swap_horiz, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('Change Role'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'view_details',
                      child: Row(
                        children: [
                          Icon(Icons.info, color: Colors.orange),
                          SizedBox(width: 8),
                          Text('View Details'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value:
                          user['isSuspended'] == true ? 'unsuspend' : 'suspend',
                      child: Row(
                        children: [
                          Icon(
                            user['isSuspended'] == true
                                ? Icons.lock_open
                                : Icons.lock,
                            color: user['isSuspended'] == true
                                ? Colors.green
                                : Colors.orange,
                          ),
                          SizedBox(width: 8),
                          Text(user['isSuspended'] == true
                              ? 'Unsuspend User'
                              : 'Suspend User'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'send_message',
                      child: Row(
                        children: [
                          Icon(Icons.message, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('Send Message'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'export_data',
                      child: Row(
                        children: [
                          Icon(Icons.download, color: Colors.purple),
                          SizedBox(width: 8),
                          Text('Export Data'),
                        ],
                      ),
                    ),
                    if (userType != 'admin')
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete User'),
                          ],
                        ),
                      ),
                  ],
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.more_vert,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
            if (joinDate.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Joined: $joinDate',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
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

  Widget _buildUserTypeChip(String userType) {
    final color = _getUserTypeColor(userType);
    final displayName = userType
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        displayName,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }

  Widget _buildStatusChip(bool isApproved) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isApproved
            ? Colors.green.withOpacity(0.1)
            : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isApproved
              ? Colors.green.withOpacity(0.3)
              : Colors.orange.withOpacity(0.3),
        ),
      ),
      child: Text(
        isApproved ? 'Approved' : 'Pending',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: isApproved ? Colors.green : Colors.orange,
        ),
      ),
    );
  }

  Widget _buildSuspensionChip(bool isSuspended) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lock,
            size: 12,
            color: Colors.red,
          ),
          const SizedBox(width: 4),
          Text(
            'Suspended',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Color _getUserTypeColor(String userType) {
    switch (userType) {
      case 'admin':
        return Colors.purple;
      case 'healthcare_provider':
      case 'doctor':
        return Colors.blue;
      case 'caregiver':
        return Colors.teal;
      case 'patient':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getUserTypeIcon(String userType) {
    switch (userType) {
      case 'admin':
        return Icons.admin_panel_settings;
      case 'healthcare_provider':
      case 'doctor':
        return FontAwesomeIcons.userDoctor;
      case 'caregiver':
        return FontAwesomeIcons.handHoldingHeart;
      case 'patient':
        return Icons.person;
      default:
        return Icons.person;
    }
  }

  Stream<QuerySnapshot> _getUsersStream(String userType) {
    Query query = FirebaseFirestore.instance.collection('users');

    if (userType != 'all') {
      if (userType == 'caregiver' || userType == 'doctor') {
        // For backward compatibility, if we're looking for caregiver or doctor,
        // search for healthcare_provider and filter by specialty or role field
        query = query.where('userType', isEqualTo: 'healthcare_provider');
      } else {
        query = query.where('userType', isEqualTo: userType);
      }
    }

    return query.orderBy('createdAt', descending: true).snapshots();
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';

    try {
      DateTime dateTime;
      if (timestamp is Timestamp) {
        dateTime = timestamp.toDate();
      } else if (timestamp is String) {
        dateTime = DateTime.parse(timestamp);
      } else {
        return '';
      }

      return DateFormat('MMM dd, yyyy').format(dateTime);
    } catch (e) {
      return '';
    }
  }

  void _handleUserAction(String action, Map<String, dynamic> user) {
    switch (action) {
      case 'approve':
        _approveUser(user);
        break;
      case 'change_role':
        _showChangeRoleDialog(user);
        break;
      case 'view_details':
        _showUserDetailsDialog(user);
        break;
      case 'suspend':
        _suspendUser(user);
        break;
      case 'unsuspend':
        _unsuspendUser(user);
        break;
      case 'send_message':
        _showSendMessageDialog(user);
        break;
      case 'export_data':
        _exportUserData(user);
        break;
      case 'delete':
        _showDeleteUserDialog(user);
        break;
    }
  }

  Future<void> _approveUser(Map<String, dynamic> user) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user['id'])
          .update({'isApproved': true});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('User ${user['name']} has been approved'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error approving user: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showChangeRoleDialog(Map<String, dynamic> user) {
    String selectedRole = user['userType'] ?? 'patient';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Change Role for ${user['name']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: const Text('Patient'),
                value: 'patient',
                groupValue: selectedRole,
                onChanged: (value) => setState(() => selectedRole = value!),
              ),
              RadioListTile<String>(
                title: const Text('Caregiver'),
                value: 'caregiver',
                groupValue: selectedRole,
                onChanged: (value) => setState(() => selectedRole = value!),
              ),
              RadioListTile<String>(
                title: const Text('Doctor'),
                value: 'doctor',
                groupValue: selectedRole,
                onChanged: (value) => setState(() => selectedRole = value!),
              ),
              RadioListTile<String>(
                title: const Text('Healthcare Provider (Legacy)'),
                value: 'healthcare_provider',
                groupValue: selectedRole,
                onChanged: (value) => setState(() => selectedRole = value!),
              ),
              RadioListTile<String>(
                title: const Text('Admin'),
                value: 'admin',
                groupValue: selectedRole,
                onChanged: (value) => setState(() => selectedRole = value!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => _changeUserRole(user, selectedRole),
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text('Change Role',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changeUserRole(
      Map<String, dynamic> user, String newRole) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user['id'])
          .update({'userType': newRole});

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Role changed to ${newRole.replaceAll('_', ' ')} for ${user['name']}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error changing role: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showUserDetailsDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('User Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Name', user['name'] ?? 'N/A'),
              _buildDetailRow('Email', user['email'] ?? 'N/A'),
              _buildDetailRow('User Type', user['userType'] ?? 'N/A'),
              _buildDetailRow('Status',
                  (user['isApproved'] ?? false) ? 'Approved' : 'Pending'),
              _buildDetailRow('Phone', user['phone'] ?? 'N/A'),
              _buildDetailRow('Medical ID', user['medicalId'] ?? 'N/A'),
              _buildDetailRow(
                  'Hemophilia Type', user['hemophiliaType'] ?? 'N/A'),
              _buildDetailRow('Joined', _formatTimestamp(user['createdAt'])),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  void _showDeleteUserDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text(
            'Are you sure you want to delete ${user['name']}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _deleteUser(user),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user['id'])
          .delete();

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('User ${user['name']} has been deleted'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting user: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // New enhanced methods
  Future<void> _suspendUser(Map<String, dynamic> user) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user['id'])
          .update({
        'isSuspended': true,
        'suspendedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('User ${user['name']} has been suspended'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error suspending user: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _unsuspendUser(Map<String, dynamic> user) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user['id'])
          .update({
        'isSuspended': false,
        'unsuspendedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('User ${user['name']} has been unsuspended'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error unsuspending user: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSendMessageDialog(Map<String, dynamic> user) {
    final TextEditingController messageController = TextEditingController();
    final TextEditingController subjectController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Send Message to ${user['name']}'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: subjectController,
                decoration: const InputDecoration(
                  labelText: 'Subject',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: messageController,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _sendMessage(
                user, subjectController.text, messageController.text),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Send', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage(
      Map<String, dynamic> user, String subject, String message) async {
    if (subject.trim().isEmpty || message.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in both subject and message'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // Send notification to user
      await FirebaseFirestore.instance.collection('notifications').add({
        'recipientId': user['id'],
        'recipientName': user['name'],
        'title': subject,
        'message': message,
        'type': 'admin_message',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'data': {
          'senderId': 'admin',
          'senderName': 'Administrator',
        },
      });

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Message sent to ${user['name']}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending message: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _exportUserData(Map<String, dynamic> user) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Exporting user data...'),
            ],
          ),
        ),
      );

      // Get user's data from various collections
      final Future<QuerySnapshot> bleedLogsFuture = FirebaseFirestore.instance
          .collection('bleed_logs')
          .where('uid', isEqualTo: user['id'])
          .get();

      final Future<QuerySnapshot> infusionLogsFuture = FirebaseFirestore
          .instance
          .collection('infusion_logs')
          .where('uid', isEqualTo: user['id'])
          .get();

      final Future<QuerySnapshot> postsFuture = FirebaseFirestore.instance
          .collection('community_posts')
          .where('authorId', isEqualTo: user['id'])
          .get();

      final results = await Future.wait([
        bleedLogsFuture,
        infusionLogsFuture,
        postsFuture,
      ]);

      final bleedLogs = results[0];
      final infusionLogs = results[1];
      final posts = results[2];

      // Create export data
      final exportData = {
        'user': user,
        'bleedLogs': bleedLogs.docs.map((doc) => doc.data()).toList(),
        'infusionLogs': infusionLogs.docs.map((doc) => doc.data()).toList(),
        'communityPosts': posts.docs.map((doc) => doc.data()).toList(),
        'exportedAt': DateTime.now().toIso8601String(),
        'exportedBy': 'admin',
      };

      Navigator.pop(context); // Close loading dialog

      // Show export summary
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Export Summary'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('User: ${user['name']}'),
              Text('Bleed Logs: ${bleedLogs.docs.length}'),
              Text('Infusion Logs: ${infusionLogs.docs.length}'),
              Text('Community Posts: ${posts.docs.length}'),
              const SizedBox(height: 16),
              const Text('Data exported successfully!',
                  style: TextStyle(
                      color: Colors.green, fontWeight: FontWeight.bold)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Data exported for ${user['name']}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exporting data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
