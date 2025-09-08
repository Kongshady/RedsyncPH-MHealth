import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hemophilia_manager/auth/auth.dart';
import 'package:hemophilia_manager/services/firestore.dart';
import 'package:hemophilia_manager/routes/routes.dart';
import 'package:hemophilia_manager/screens/main_screen/patient_screens/main_screen_hud.dart';
import 'package:hemophilia_manager/screens/main_screen/healthcare_provider_screen/healthcare_main_screen.dart';
import 'package:hemophilia_manager/screens/admin/admin_dashboard.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  bool _isLoading = false;
  bool _rememberMe = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString('saved_email');
      final rememberMe = prefs.getBool('remember_me') ?? false;

      if (savedEmail != null && rememberMe) {
        setState(() {
          _emailController.text = savedEmail;
          _rememberMe = true;
        });
      }
    } catch (e) {
      print('Error loading saved credentials: $e');
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      final user = await AuthService().signIn(email, password);

      if (user != null) {
        // Check if this is an admin account first
        if (await _isAdminAccount(email)) {
          // Store admin login data
          await _secureStorage.write(key: 'isLoggedIn', value: 'true');
          await _secureStorage.write(key: 'userRole', value: 'admin');
          await _secureStorage.write(key: 'userUid', value: user.uid);

          if (!mounted) return;

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const AdminDashboard()),
            (route) => false,
          );
          return;
        }

        final userRole = await _firestoreService.getUserRole(user.uid);

        if (userRole != null) {
          // Store login data in secure storage
          await _secureStorage.write(key: 'isLoggedIn', value: 'true');
          await _secureStorage.write(key: 'userRole', value: userRole);
          await _secureStorage.write(key: 'userUid', value: user.uid);

          // Handle remember me using SharedPreferences (only email)
          final prefs = await SharedPreferences.getInstance();
          if (_rememberMe) {
            await prefs.setString('saved_email', email);
            await prefs.setBool('remember_me', true);
          } else {
            await prefs.remove('saved_email');
            await prefs.setBool('remember_me', false);
          }

          if (!mounted) return;

          // Navigate based on user role
          Widget targetScreen;
          switch (userRole) {
            case 'patient':
            case 'caregiver':
              targetScreen = const MainScreenDisplay();
              break;
            case 'medical':
              targetScreen = const HealthcareMainScreen();
              break;
            default:
              _showError('Invalid user role. Please contact support.');
              setState(() => _isLoading = false);
              return;
          }

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => targetScreen),
            (route) => false,
          );
        } else {
          _showError('User role not found. Please contact support.');
        }
      } else {
        _showError('Invalid email or password');
      }
    } catch (e) {
      String errorMessage = _parseAuthError(e.toString());
      _showError(errorMessage);
    }

    if (mounted) setState(() => _isLoading = false);
  }

  // Check if the email belongs to an admin account
  Future<bool> _isAdminAccount(String email) async {
    // Define admin emails here - you can modify this list as needed
    const List<String> adminEmails = [
      'admin@redsyncph.com',
      'superadmin@redsyncph.com',
      'hemophilia.admin@redsyncph.com',
    ];

    return adminEmails.contains(email.toLowerCase());
  }

  String _parseAuthError(String error) {
    if (error.contains('invalid-credential') ||
        error.contains('wrong-password') ||
        error.contains('user-not-found')) {
      return 'Invalid email or password. Please check your credentials and try again.';
    } else if (error.contains('user-disabled')) {
      return 'This account has been disabled. Please contact support.';
    } else if (error.contains('too-many-requests')) {
      return 'Too many failed attempts. Please try again later.';
    } else if (error.contains('network-request-failed')) {
      return 'Network error. Please check your internet connection.';
    } else if (error.contains('invalid-email')) {
      return 'Please enter a valid email address.';
    } else {
      return 'Login failed. Please try again.';
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.redAccent, size: 24),
            SizedBox(width: 8),
            Text(
              'Login Error',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text(
              'OK',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 28.0, vertical: 16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 12),
                  Image.asset('assets/images/app_logo.png',
                      width: 80, height: 80),
                  const SizedBox(height: 18),
                  const Text(
                    'Welcome Back',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to RedSyncPH to continue.',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),

                  // Email Field
                  _buildInputField(
                    controller: _emailController,
                    label: 'Email',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Enter email';
                      if (!value.contains('@')) return 'Enter valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),

                  // Password Field
                  _buildInputField(
                    controller: _passwordController,
                    label: 'Password',
                    icon: Icons.lock_outline,
                    obscureText: _obscurePassword,
                    showPasswordToggle: true,
                    validator: (value) {
                      if (value == null || value.isEmpty)
                        return 'Enter password';
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),

                  // Remember Me & Forgot Password
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: _rememberMe,
                            onChanged: (value) =>
                                setState(() => _rememberMe = value ?? false),
                            activeColor: Colors.redAccent,
                          ),
                          const Text('Remember me',
                              style: TextStyle(color: Colors.black87)),
                        ],
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.blue,
                          padding: EdgeInsets.zero,
                        ),
                        child: const Text('Forgot Password?',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () => Navigator.pushNamed(
                            context, AppRoutes.forgotPassword),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Login Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'Login',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Register Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Don\'t have an account?',
                          style:
                              TextStyle(color: Colors.black87, fontSize: 14)),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          padding: EdgeInsets.zero,
                        ),
                        child: const Text('Register now',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        onPressed: () => Navigator.pushReplacementNamed(
                            context, '/register'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    bool showPasswordToggle = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.redAccent),
        suffixIcon: showPasswordToggle
            ? IconButton(
                icon: Icon(
                  obscureText ? Icons.visibility : Icons.visibility_off,
                  color: Colors.grey.shade600,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              )
            : null,
        border: const UnderlineInputBorder(),
        labelStyle: TextStyle(color: Colors.grey.shade700),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.redAccent, width: 2),
        ),
      ),
    );
  }
}
