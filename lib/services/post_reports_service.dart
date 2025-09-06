import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PostReportsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get all post reports with real-time updates
  Stream<List<Map<String, dynamic>>> getPostReportsStream() {
    print('PostReportsService: Starting to stream all post reports');
    return _firestore
        .collection('post_reports')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      print(
          'PostReportsService: Received ${snapshot.docs.length} post reports from Firestore');
      for (var doc in snapshot.docs) {
        final data = doc.data();
        print(
            'PostReport: ${doc.id} - postId: ${data['postId']}, status: ${data['status']}, reason: ${data['reason']}');
      }
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'postId': data['postId'],
          'postContent': data['postContent'],
          'postAuthorId': data['postAuthorId'],
          'postAuthorName': data['postAuthorName'],
          'postTimestamp': data['postTimestamp'],
          'reporterId': data['reporterId'],
          'reporterName': data['reporterName'],
          'reason': data['reason'],
          'timestamp': data['timestamp'],
          'status': data['status'] ?? 'pending',
          'reviewedBy': data['reviewedBy'],
          'reviewedAt': data['reviewedAt'],
          'adminNotes': data['adminNotes'] ?? '',
        };
      }).toList();
    });
  }

  // Get reports by status
  Stream<List<Map<String, dynamic>>> getReportsByStatus(String status) {
    print(
        'PostReportsService: Starting to stream post reports with status: $status');

    // Use a simpler query and sort in memory to avoid index issues
    return _firestore
        .collection('post_reports')
        .where('status', isEqualTo: status)
        .snapshots()
        .map((snapshot) {
      print(
          'PostReportsService: Received ${snapshot.docs.length} post reports with status "$status" from Firestore');

      final reports = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'postId': data['postId'],
          'postContent': data['postContent'],
          'postAuthorId': data['postAuthorId'],
          'postAuthorName': data['postAuthorName'],
          'postTimestamp': data['postTimestamp'],
          'reporterId': data['reporterId'],
          'reporterName': data['reporterName'],
          'reason': data['reason'],
          'timestamp': data['timestamp'],
          'status': data['status'] ?? 'pending',
          'reviewedBy': data['reviewedBy'],
          'reviewedAt': data['reviewedAt'],
          'adminNotes': data['adminNotes'] ?? '',
        };
      }).toList();

      // Sort by timestamp in memory (most recent first)
      reports.sort((a, b) {
        final aTime = a['timestamp'];
        final bTime = b['timestamp'];
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;

        // Handle Firestore Timestamp objects
        if (aTime.runtimeType.toString() == 'Timestamp' &&
            bTime.runtimeType.toString() == 'Timestamp') {
          return (bTime as dynamic).compareTo(aTime as dynamic);
        }

        return 0;
      });

      return reports;
    });
  }

  // Get reports by status - Alternative method using filter from all reports
  Stream<List<Map<String, dynamic>>> getReportsByStatusFallback(String status) {
    print('PostReportsService: Using fallback method for status: $status');
    return getPostReportsStream().map((allReports) {
      return allReports.where((report) {
        final reportStatus = report['status'] ?? 'pending';
        return reportStatus == status;
      }).toList();
    });
  }

  Stream<int> getPendingReportsCount() {
    return _firestore
        .collection('post_reports')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Resolve a report (approve or dismiss)
  Future<void> resolveReport({
    required String reportId,
    required String action, // 'approved', 'dismissed'
    String? adminNotes,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    await _firestore.collection('post_reports').doc(reportId).update({
      'status': action,
      'reviewedBy': currentUser.uid,
      'reviewedAt': FieldValue.serverTimestamp(),
      'adminNotes': adminNotes ?? '',
    });
  }

  // Delete a post (when report is approved)
  Future<void> deleteReportedPost(String postId) async {
    // Delete the post
    await _firestore.collection('community_posts').doc(postId).delete();

    // Delete associated likes
    final likesSnapshot = await _firestore
        .collection('community_posts')
        .doc(postId)
        .collection('likes')
        .get();

    for (var doc in likesSnapshot.docs) {
      await doc.reference.delete();
    }

    // Delete associated comments
    final commentsSnapshot = await _firestore
        .collection('community_posts')
        .doc(postId)
        .collection('comments')
        .get();

    for (var doc in commentsSnapshot.docs) {
      await doc.reference.delete();
    }
  }

  // Get reports for a specific post
  Stream<List<Map<String, dynamic>>> getReportsForPost(String postId) {
    return _firestore
        .collection('post_reports')
        .where('postId', isEqualTo: postId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'reporterId': data['reporterId'],
          'reporterName': data['reporterName'],
          'reason': data['reason'],
          'timestamp': data['timestamp'],
          'status': data['status'] ?? 'pending',
          'reviewedBy': data['reviewedBy'],
          'reviewedAt': data['reviewedAt'],
          'adminNotes': data['adminNotes'] ?? '',
        };
      }).toList();
    });
  }
}
