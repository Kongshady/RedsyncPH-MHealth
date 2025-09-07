import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:hemophilia_manager/auth/auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../widgets/offline_indicator.dart';

class AdminSettings extends StatefulWidget {
  const AdminSettings({super.key});

  @override
  State<AdminSettings> createState() => _AdminSettingsState();
}

class _AdminSettingsState extends State<AdminSettings> {
  String? _name;
  String? _email;
  String? _photoUrl;

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _loadAdminInfo();
  }

  Future<void> _loadAdminInfo() async {
    final user = AuthService().currentUser;
    if (user != null) {
      setState(() {
        _email = user.email;
        _photoUrl = user.photoURL;
        _name = user.displayName ?? 'Administrator';
      });
    }
  }

  void _logout() async {
    // Show confirmation dialog
    final bool? confirmLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.logout, color: Colors.red),
              SizedBox(width: 8),
              Text(
                'Confirm Logout',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.redAccent),
              ),
            ],
          ),
          content: const Text(
            'Are you sure you want to sign out of your admin account?',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            FilledButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child:
                  const Text('Logout', style: TextStyle(color: Colors.white)),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmLogout == true) {
      await AuthService().signOut();
      // Clear all secure storage keys related to login
      await _secureStorage.delete(key: 'isLoggedIn');
      await _secureStorage.delete(key: 'userRole');
      await _secureStorage.delete(key: 'userUid');
      await _secureStorage.delete(key: 'saved_email');
      await _secureStorage.delete(key: 'saved_password');
      await _secureStorage.delete(key: 'remember_me');
      await _secureStorage.delete(key: 'admin_session');
      await _secureStorage.deleteAll(); // As backup, clear everything

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Admin session ended successfully.'),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pushNamedAndRemoveUntil(
          context, '/authentication', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Admin Settings',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.redAccent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(FontAwesomeIcons.arrowLeft, size: 18),
        ),
      ),
      body: Column(
        children: [
          const OfflineIndicator(),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Profile Header Section - Following patient design
                  Container(
                    width: double.infinity,
                    color: Colors.white,
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(
                              color: Colors.redAccent.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: _photoUrl != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(48),
                                  child: Image.network(
                                    _photoUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Icon(
                                        Icons.admin_panel_settings,
                                        size: 50,
                                        color: Colors.redAccent,
                                      );
                                    },
                                  ),
                                )
                              : const Icon(
                                  Icons.admin_panel_settings,
                                  size: 50,
                                  color: Colors.redAccent,
                                ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _name ?? 'Administrator',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _email ?? 'admin@redsync.com',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.redAccent.withOpacity(0.3),
                            ),
                          ),
                          child: const Text(
                            'System Administrator',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Account Management Section
                  _buildSection(
                    title: 'Account Management',
                    children: [
                      _buildSettingsItem(
                        icon: FontAwesomeIcons.lock,
                        title: 'Change Password',
                        subtitle: 'Update your admin password',
                        onTap: () {
                          // Navigate to change password if route exists
                          try {
                            Navigator.pushNamed(context, '/change_password');
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Password change feature coming soon'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                        },
                      ),
                      _buildSettingsItem(
                        icon: FontAwesomeIcons.shield,
                        title: 'Security Settings',
                        subtitle: 'Manage admin security preferences',
                        onTap: () {
                          _showSecurityDialog();
                        },
                      ),
                    ],
                  ),

                  // Logout Section
                  _buildSection(
                    title: 'Session',
                    children: [
                      _buildSettingsItem(
                        icon: FontAwesomeIcons.signOut,
                        title: 'Logout',
                        subtitle: 'Sign out of admin account',
                        onTap: _logout,
                        isDestructive: true,
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isDestructive
                    ? Colors.red.withOpacity(0.1)
                    : Colors.redAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDestructive
                      ? Colors.red.withOpacity(0.3)
                      : Colors.redAccent.withOpacity(0.3),
                ),
              ),
              child: Icon(
                icon,
                color: isDestructive ? Colors.red : Colors.redAccent,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDestructive ? Colors.red : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              FontAwesomeIcons.chevronRight,
              size: 14,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  void _showSecurityDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.security, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Security Settings'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current Security Features:'),
            SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 16),
                SizedBox(width: 8),
                Text('Secure Authentication'),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 16),
                SizedBox(width: 8),
                Text('Admin Role Protection'),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 16),
                SizedBox(width: 8),
                Text('Secure Session Management'),
              ],
            ),
            SizedBox(height: 16),
            Text(
              'Additional security features will be available in future updates.',
              style: TextStyle(color: Colors.grey),
            ),
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
  }



}
