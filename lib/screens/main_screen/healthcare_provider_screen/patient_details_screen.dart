import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/firestore.dart';
import '../shared/chat_screen.dart';

class PatientDetailsScreen extends StatefulWidget {
  final String patientUid;
  final Map<String, dynamic> patientData;

  const PatientDetailsScreen({
    super.key,
    required this.patientUid,
    required this.patientData,
  });

  @override
  State<PatientDetailsScreen> createState() => _PatientDetailsScreenState();
}

class _PatientDetailsScreenState extends State<PatientDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirestoreService _firestoreService = FirestoreService();

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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.patientData['name'] ?? 'Patient Details',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.redAccent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {
              _showPatientActionsMenu();
            },
            icon: const Icon(FontAwesomeIcons.ellipsisVertical, size: 18),
          ),
        ],
      ),
      body: Column(
        children: [
          // Patient Header
          _buildPatientHeader(),

          // Tab Bar
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200, width: 1),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.redAccent,
              labelColor: Colors.redAccent,
              unselectedLabelColor: Colors.grey.shade600,
              indicatorWeight: 3,
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              unselectedLabelStyle:
                  const TextStyle(fontWeight: FontWeight.w500),
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'History'),
                Tab(text: 'Logs'),
              ],
            ),
          ),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildMedicalHistoryTab(),
                _buildLogsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientHeader() {
    final isCaregiver = widget.patientData['role'] == 'caregiver';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.redAccent, Colors.red.shade700],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        (widget.patientData['name'] ?? 'P')[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.patientData['name'] ?? 'Unknown User',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isCaregiver ? 'Caregiver' : 'Patient',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.patientData['email'] ?? 'No email',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              participant: {
                                'id': widget.patientUid,
                                'name': widget.patientData['name'],
                                'role': isCaregiver ? 'caregiver' : 'patient',
                                'profilePicture':
                                    widget.patientData['profilePicture'],
                              },
                              currentUserRole: 'medical',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(
                        FontAwesomeIcons.message,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
              if (!isCaregiver) ...[
                const SizedBox(height: 24),
                Row(
                  children: [
                    _buildHeaderStat(
                      'Hemophilia Type',
                      widget.patientData['hemophiliaType'] ?? 'Hemophilia A',
                    ),
                    _buildHeaderStat(
                        'Age', _calculateAge(widget.patientData['dob'])),
                    _buildHeaderStat(
                      'Blood Type',
                      widget.patientData['bloodType'] ?? 'Not specified',
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderStat(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    final isCaregiver = widget.patientData['role'] == 'caregiver';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Personal Information'),
          const SizedBox(height: 20),
          _buildInfoList([
            _buildInfoRow(
                'Full Name', widget.patientData['name'] ?? 'Not specified'),
            _buildInfoRow(
                'Email', widget.patientData['email'] ?? 'Not specified'),
            _buildInfoRow(
                'Gender', widget.patientData['gender'] ?? 'Not specified'),
            _buildInfoRow(
                'Date of Birth', _formatDate(widget.patientData['dob'])),
            if (!isCaregiver) ...[
              _buildInfoRow(
                  'Weight', _formatWeight(widget.patientData['weight'])),
              _buildInfoRow('Blood Type',
                  widget.patientData['bloodType'] ?? 'Not specified'),
            ],
            if (isCaregiver) ...[
              _buildInfoRow('Relationship to Patient',
                  widget.patientData['relationship'] ?? 'Not specified'),
            ],
          ]),

          // Show Medical Information and Emergency Contact only for non-caregivers
          if (!isCaregiver) ...[
            const SizedBox(height: 40),
            _buildSectionTitle('Medical Information'),
            const SizedBox(height: 20),
            _buildInfoList([
              _buildInfoRow('Hemophilia Type',
                  widget.patientData['hemophiliaType'] ?? 'Hemophilia A'),
              _buildInfoRow('Inhibitor Status',
                  widget.patientData['inhibitorStatus'] ?? 'Not specified'),
            ]),
            const SizedBox(height: 40),
            _buildSectionTitle('Emergency Contact'),
            const SizedBox(height: 20),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('emergency_contacts')
                  .where('patientUid', isEqualTo: widget.patientUid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                  final contact =
                      snapshot.data!.docs.first.data() as Map<String, dynamic>;
                  return _buildInfoList([
                    _buildInfoRow('Emergency Phone',
                        contact['contactPhone'] ?? 'Not specified'),
                    _buildInfoRow('Contact Name',
                        contact['contactName'] ?? 'Not specified'),
                    _buildInfoRow('Relationship',
                        contact['relationship'] ?? 'Not specified'),
                  ]);
                }
                return _buildEmptyState(
                  icon: FontAwesomeIcons.phoneSlash,
                  title: 'No emergency contact',
                  subtitle:
                      'Patient hasn\'t provided emergency contact information',
                );
              },
            ),
          ],

          // Show Patient Information only for caregivers
          if (isCaregiver) ...[
            const SizedBox(height: 40),
            _buildSectionTitle('Patient Information'),
            const SizedBox(height: 20),
            _buildCaregiverPatientInfo(),
          ],
        ],
      ),
    );
  }

  Widget _buildMedicalHistoryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Recent Treatments'),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('infusions')
                .where('patientUid', isEqualTo: widget.patientUid)
                .orderBy('date', descending: true)
                .limit(10)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                return Column(
                  children: snapshot.data!.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return _buildTreatmentItem(data);
                  }).toList(),
                );
              }
              return _buildEmptyState(
                icon: FontAwesomeIcons.syringe,
                title: 'No treatment history',
                subtitle: 'Patient hasn\'t logged any treatments yet',
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLogsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Bleeding Episodes'),
          const SizedBox(height: 16),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _firestoreService.getBleedLogs(
              widget.patientUid,
              limit: 15,
            ),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                final logs = snapshot.data!;
                return Column(
                  children: logs.map((log) => _buildBleedLogItem(log)).toList(),
                );
              }
              return _buildEmptyState(
                icon: FontAwesomeIcons.droplet,
                title: 'No bleeding episodes',
                subtitle: 'Patient hasn\'t logged any bleeding episodes yet',
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.redAccent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoList(List<Widget> items) {
    return Column(
      children: items
          .map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: item,
              ))
          .toList(),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade50,
            offset: const Offset(0, 2),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTreatmentItem(Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              FontAwesomeIcons.syringe,
              color: Colors.purple,
              size: 16,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['medication'] ?? 'Unknown medication',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${data['doseIU'] ?? 0} IU',
                  style: const TextStyle(
                    color: Colors.purple,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _formatTimestamp(data['date']),
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBleedLogItem(Map<String, dynamic> log) {
    final severity = log['severity'] ?? 'Mild';
    final color = _getSeverityColor(severity);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: InkWell(
        onTap: () => _showBleedLogDetails(log),
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(FontAwesomeIcons.droplet, color: color, size: 16),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          log['bodyRegion'] ?? 'Unknown',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          severity,
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '${log['date'] ?? 'Unknown'} • ${log['time'] ?? 'Unknown'}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        FontAwesomeIcons.chevronRight,
                        color: Colors.grey.shade400,
                        size: 12,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showPatientActionsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Patient Actions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            _buildActionItem(
              icon: FontAwesomeIcons.message,
              title: 'Send Message',
              subtitle: 'Start a conversation',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(
                      participant: {
                        'id': widget.patientUid,
                        'name': widget.patientData['name'],
                        'role': 'patient',
                        'profilePicture': widget.patientData['profilePicture'],
                      },
                      currentUserRole: 'medical',
                    ),
                  ),
                );
              },
            ),
            _buildActionItem(
              icon: FontAwesomeIcons.userXmark,
              title: 'Remove Access',
              subtitle: 'Revoke data sharing',
              onTap: () {
                Navigator.pop(context);
                _confirmRemoveAccess();
              },
              isDestructive: true,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isDestructive
              ? Colors.red.withOpacity(0.1)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: isDestructive ? Colors.red : Colors.grey.shade700,
          size: 16,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isDestructive ? Colors.red : Colors.black87,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
      ),
      onTap: onTap,
    );
  }

  void _confirmRemoveAccess() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Data Access'),
        content: const Text(
          'Are you sure you want to revoke data sharing access for this patient? This action cannot be undone.',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _removeDataAccess();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _removeDataAccess() async {
    try {
      // Find and delete the data sharing relationship
      final dataSharingQuery = await FirebaseFirestore.instance
          .collection('data_sharing')
          .where('patientUid', isEqualTo: widget.patientUid)
          .where(
            'providerUid',
            isEqualTo: FirebaseAuth.instance.currentUser?.uid,
          )
          .get();

      for (var doc in dataSharingQuery.docs) {
        await doc.reference.delete();
      }

      // Send notification to patient
      await _firestoreService.createNotification(
        widget.patientUid,
        'Your healthcare provider has revoked data sharing access.',
      );

      // Show success message and navigate back
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data access removed successfully'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.of(context).pop(); // Go back to patients list
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error removing access: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showBleedLogDetails(Map<String, dynamic> log) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _getSeverityColor(log['severity'] ?? 'Mild'),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          FontAwesomeIcons.droplet,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Bleeding Episode',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${log['date'] ?? 'Unknown'} at ${log['time'] ?? 'Unknown'}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailSection('Episode Information', [
                          _buildDetailRow(
                            'Body Region',
                            log['bodyRegion'] ?? 'Not specified',
                          ),
                          _buildDetailRow(
                            'Specific Region',
                            log['specificRegion']?.isNotEmpty == true
                                ? log['specificRegion']
                                : 'Not specified',
                          ),
                          _buildDetailRow(
                            'Severity',
                            log['severity'] ?? 'Not specified',
                          ),
                          _buildDetailRow(
                            'Date',
                            log['date'] ?? 'Not specified',
                          ),
                          _buildDetailRow(
                            'Time',
                            log['time'] ?? 'Not specified',
                          ),
                        ]),

                        const SizedBox(height: 24),

                        if (log['notes']?.isNotEmpty == true) ...[
                          _buildDetailSection('Additional Notes', [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Text(
                                log['notes'],
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ]),
                          const SizedBox(height: 24),
                        ],

                        _buildDetailSection('Patient Information', [
                          _buildDetailRow(
                            'Patient Name',
                            widget.patientData['name'] ?? 'Unknown',
                          ),
                          _buildDetailRow(
                            'Hemophilia Type',
                            widget.patientData['hemophiliaType'] ??
                                'Not specified',
                          ),
                          _buildDetailRow(
                            'Severity Level',
                            widget.patientData['severity'] ?? 'Not specified',
                          ),
                        ]),

                        const SizedBox(height: 24),

                        if (log['createdAt'] != null) ...[
                          _buildDetailSection('Log Information', [
                            _buildDetailRow(
                              'Logged At',
                              _formatTimestamp(log['createdAt']),
                            ),
                            _buildDetailRow('Log ID', log['id'] ?? 'Unknown'),
                          ]),
                          const SizedBox(height: 24),
                        ],

                        // Severity indicator
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _getSeverityColor(
                              log['severity'] ?? 'Mild',
                            ).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _getSeverityColor(
                                log['severity'] ?? 'Mild',
                              ).withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _getSeverityIcon(log['severity'] ?? 'Mild'),
                                color: _getSeverityColor(
                                  log['severity'] ?? 'Mild',
                                ),
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${log['severity'] ?? 'Mild'} Severity',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _getSeverityColor(
                                          log['severity'] ?? 'Mild',
                                        ),
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      _getSeverityDescription(
                                        log['severity'] ?? 'Mild',
                                      ),
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
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    try {
      if (timestamp != null) {
        DateTime date;
        if (timestamp is Timestamp) {
          date = timestamp.toDate();
        } else if (timestamp is String) {
          date = DateTime.parse(timestamp);
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

  IconData _getSeverityIcon(String severity) {
    switch (severity.toLowerCase()) {
      case 'mild':
        return Icons.sentiment_satisfied;
      case 'moderate':
        return Icons.sentiment_neutral;
      case 'severe':
        return Icons.sentiment_very_dissatisfied;
      default:
        return Icons.help_outline;
    }
  }

  String _getSeverityDescription(String severity) {
    switch (severity.toLowerCase()) {
      case 'mild':
        return 'Minor bleeding episode that may not require immediate treatment';
      case 'moderate':
        return 'Moderate bleeding that may require factor replacement therapy';
      case 'severe':
        return 'Serious bleeding episode requiring immediate medical attention';
      default:
        return 'Severity level not specified';
    }
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

  String _calculateAge(String? dob) {
    if (dob == null || dob.isEmpty) return 'Unknown';
    try {
      final birthDate = DateTime.parse(dob);
      final now = DateTime.now();
      int age = now.year - birthDate.year;
      if (now.month < birthDate.month ||
          (now.month == birthDate.month && now.day < birthDate.day)) {
        age--;
      }
      return '$age years';
    } catch (e) {
      return 'Unknown';
    }
  }

  String _formatDate(String? date) {
    if (date == null || date.isEmpty) return 'Not specified';
    try {
      final dateTime = DateTime.parse(date);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } catch (e) {
      return 'Not specified';
    }
  }

  String _formatWeight(String? weight) {
    if (weight == null || weight.isEmpty) return 'Not specified';
    return '$weight kg';
  }

  Widget _buildCaregiverPatientInfo() {
    final patientData = widget.patientData;

    // Get patient information from caregiver data
    final patientName = patientData['patientName'] ?? 'Not specified';
    final patientAge = patientData['patientAge'] ?? 'Not specified';
    final patientGender = patientData['patientGender'] ?? 'Not specified';
    final patientHemophiliaType =
        patientData['patientHemophiliaType'] ?? 'Not specified';
    final patientWeight = patientData['patientWeight'] ?? 'Not specified';
    final patientBloodType = patientData['patientBloodType'] ?? 'Not specified';
    final patientDob = _formatDate(patientData['patientDob']);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.shade50,
            Colors.indigo.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.shade100, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade100.withOpacity(0.3),
            offset: const Offset(0, 4),
            blurRadius: 12,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade600,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.shade600.withOpacity(0.3),
                      offset: const Offset(0, 2),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.child_care,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                'Patient Under Care',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildInfoList([
            _buildPatientInfoRow('Patient Name', patientName),
            _buildPatientInfoRow('Age', patientAge),
            _buildPatientInfoRow('Gender', patientGender),
            _buildPatientInfoRow('Date of Birth', patientDob),
            _buildPatientInfoRow('Hemophilia Type', patientHemophiliaType),
            _buildPatientInfoRow(
                'Weight',
                patientWeight == 'Not specified'
                    ? patientWeight
                    : '$patientWeight kg'),
            _buildPatientInfoRow('Blood Type', patientBloodType),
          ]),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.blue.shade700,
                  size: 18,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'This information is provided by the caregiver and may need verification.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientInfoRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.blue.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
