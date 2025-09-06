import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/community_service.dart';
import '../../services/admin_notification_service.dart';
import 'admin_notifications_screen.dart';
import 'admin_home_screen.dart';
import 'admin_approvals_screen.dart';
import 'admin_events_screen.dart';
import 'admin_post_reports_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  final CommunityService _communityService = CommunityService();
  late AnimationController _pageAnimationController;
  late TabController _bottomTabController;

  @override
  void initState() {
    super.initState();
    _pageAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _bottomTabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: 0,
    );
    _bottomTabController.addListener(() {
      if (_bottomTabController.indexIsChanging) {
        setState(() {
          _currentIndex = _bottomTabController.index;
        });
        _pageAnimationController.reset();
        _pageAnimationController.forward();
      }
    });
    _pageAnimationController.forward();
    _setupAdminUser();
    _loadAdminInfo();
  }

  Future<void> _loadAdminInfo() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        // Admin info loaded successfully
      }
    } catch (e) {
      print('Error loading admin info: $e');
    }
  }

  // Setup admin user when dashboard loads
  Future<void> _setupAdminUser() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && currentUser.email != null) {
        await _communityService.setupAdminUser(
          email: currentUser.email!,
          name: 'Administrator',
        );
        print('Admin user setup completed successfully');
      }
    } catch (e) {
      print('Admin setup error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Admin setup error: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _pageAnimationController.dispose();
    _bottomTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        toolbarHeight: 70,
        title: const Text(
          'RedSync PH',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.redAccent,
        elevation: 0,
        actions: [
          // Notification icon
          StreamBuilder<int>(
            stream: AdminNotificationService.getUnreadNotificationsCount(),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              return Stack(
                children: [
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const AdminNotificationsScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.notifications_outlined),
                    tooltip: 'Notifications',
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: InkWell(
              onTap: () {
                print('Admin avatar clicked - navigating to admin settings');
                try {
                  Navigator.pushNamed(context, '/admin_settings');
                } catch (e) {
                  print('Navigation error: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Settings not available: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              borderRadius: BorderRadius.circular(25),
              child: Padding(
                padding: const EdgeInsets.all(5.0),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey.shade200,
                  child: Icon(Icons.person, color: Colors.grey.shade600),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _getSelectedPage(),
      bottomNavigationBar: _buildCustomBottomNavigationBar(),
    );
  }

  Widget _buildCustomBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 60,
          child: TabBar(
            controller: _bottomTabController,
            labelColor: Colors.redAccent,
            unselectedLabelColor: Colors.grey.shade600,
            indicatorColor: Colors.redAccent,
            indicatorWeight: 3.0,
            indicatorSize: TabBarIndicatorSize.label,
            indicator: BoxDecoration(
              border: Border(
                top: BorderSide(width: 3.0, color: Colors.redAccent),
              ),
            ),
            tabs: [
              Tab(
                icon: Icon(Icons.home, size: 24),
                text: 'Home',
              ),
              Tab(
                icon: Icon(Icons.pending_actions, size: 24),
                text: 'Approvals',
              ),
              Tab(
                icon: Icon(Icons.flag, size: 24),
                text: 'Reports',
              ),
              Tab(
                icon: Icon(Icons.event, size: 24),
                text: 'Events',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _getSelectedPage() {
    return AnimatedBuilder(
      animation: _pageAnimationController,
      builder: (context, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: _pageAnimationController,
            curve: Curves.easeInOut,
          )),
          child: FadeTransition(
            opacity: Tween<double>(
              begin: 0.7,
              end: 1.0,
            ).animate(CurvedAnimation(
              parent: _pageAnimationController,
              curve: Curves.easeInOut,
            )),
            child: _getCurrentPage(),
          ),
        );
      },
    );
  }

  Widget _getCurrentPage() {
    switch (_currentIndex) {
      case 0:
        return AdminHomeScreen(
          onTabChanged: (index) {
            setState(() {
              _currentIndex = index;
              _bottomTabController.animateTo(index);
            });
          },
        );
      case 1:
        return const AdminApprovalsScreen();
      case 2:
        return const AdminPostReportsScreen();
      case 3:
        return const AdminEventsScreen();
      default:
        return AdminHomeScreen(
          onTabChanged: (index) {
            setState(() {
              _currentIndex = index;
              _bottomTabController.animateTo(index);
            });
          },
        );
    }
  }
}
