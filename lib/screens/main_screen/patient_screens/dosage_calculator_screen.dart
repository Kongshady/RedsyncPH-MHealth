import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/firestore.dart';

class DosageCalculatorScreen extends StatefulWidget {
  const DosageCalculatorScreen({super.key});

  @override
  State<DosageCalculatorScreen> createState() => _DosageCalculatorScreenState();
}

class _DosageCalculatorScreenState extends State<DosageCalculatorScreen> {
  final TextEditingController weightController = TextEditingController();
  final TextEditingController factorLevelController = TextEditingController();
  final TextEditingController notesController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();

  String selectedType = 'Hemophilia A';
  String userRole = '';
  String userHemophiliaType = '';
  bool isLoading = true;
  bool canEditHemophiliaType = false;
  bool autoSaveCalculations = true;
  bool isSaving = false;
  double? result;
  List<Map<String, dynamic>> calculationHistory = [];
  Map<String, dynamic>? userSettings;

  final List<String> hemophiliaTypes = [
    'Hemophilia A',
    'Hemophilia B',
    'Hemophilia C',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadUserSettings();
    _loadCalculationHistory();
  }

  // Load user profile data
  Future<void> _loadUserProfile() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final userProfile = await _firestoreService.getUserProfile(uid);
        setState(() {
          if (userProfile != null) {
            userRole = userProfile['role'] ?? '';
            userHemophiliaType =
                userProfile['hemophiliaType'] ?? 'Hemophilia A';
            selectedType = userHemophiliaType;
            canEditHemophiliaType = userRole == 'caregiver';
          } else {
            // Handle case when profile doesn't exist
            userRole = '';
            userHemophiliaType = 'Hemophilia A';
            selectedType = 'Hemophilia A';
            canEditHemophiliaType = false;
          }
          isLoading = false;
        });
      } else {
        // Handle case when user is not logged in
        setState(() {
          userRole = '';
          userHemophiliaType = 'Hemophilia A';
          selectedType = 'Hemophilia A';
          canEditHemophiliaType = false;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user profile: $e');
      setState(() {
        // Set defaults on error
        userRole = '';
        userHemophiliaType = 'Hemophilia A';
        selectedType = 'Hemophilia A';
        canEditHemophiliaType = false;
        isLoading = false;
      });

      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load profile. Using default settings.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  // Load user calculation settings
  Future<void> _loadUserSettings() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final settings = await _firestoreService.getUserCalculationSettings(
          uid,
        );
        setState(() {
          userSettings = settings;
          if (settings != null) {
            // Pre-fill fields with saved defaults
            if (settings['defaultWeight'] != null &&
                weightController.text.isEmpty) {
              weightController.text = settings['defaultWeight'].toString();
            }
            if (settings['defaultTargetLevel'] != null &&
                factorLevelController.text.isEmpty) {
              factorLevelController.text =
                  settings['defaultTargetLevel'].toString();
            }
            autoSaveCalculations = settings['autoSaveCalculations'] ?? true;
          }
        });
      }
    } catch (e) {
      print('Error loading user settings: $e');
    }
  }

  // Load calculation history
  Future<void> _loadCalculationHistory() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final history = await _firestoreService.getDosageCalculationHistory(
          uid,
          limit: 10,
        );
        setState(() {
          calculationHistory = history;
        });
      }
    } catch (e) {
      print('Error loading calculation history: $e');
    }
  }

  // Calculate dosage with database integration
  void calculateDosage() async {
    final weight = double.tryParse(weightController.text);
    final factorLevel = double.tryParse(factorLevelController.text);

    if (weight == null || factorLevel == null) {
      setState(() {
        result = null;
      });
      return;
    }

    // Example calculation (replace with actual formula as needed)
    double dosage;
    if (selectedType == 'Hemophilia A') {
      dosage = weight * factorLevel * 0.5;
    } else if (selectedType == 'Hemophilia B') {
      dosage = weight * factorLevel * 1.0;
    } else if (selectedType == 'Hemophilia C') {
      dosage = weight * factorLevel * 0.7;
    } else {
      dosage = 0.0;
    }

    setState(() {
      result = dosage;
    });

    // Save calculation to database if auto-save is enabled
    if (autoSaveCalculations && dosage > 0) {
      _saveCalculationToDatabase(weight, factorLevel, dosage);
    }
  }

  // Save calculation to database
  Future<void> _saveCalculationToDatabase(
    double weight,
    double factorLevel,
    double dosage,
  ) async {
    try {
      setState(() {
        isSaving = true;
      });

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await _firestoreService.saveDosageCalculation(
          uid: uid,
          hemophiliaType: selectedType,
          weight: weight,
          targetFactorLevel: factorLevel,
          calculatedDosage: dosage,
        );

        // Refresh calculation history
        _loadCalculationHistory();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Calculation saved to history'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('Error saving calculation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save calculation: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Dosage Calculator',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        foregroundColor: Colors.white,
        backgroundColor: Colors.green,
        elevation: 0,
        actions: [
          if (calculationHistory.isNotEmpty)
            IconButton(
              onPressed: _showCalculationHistory,
              icon: const Icon(Icons.history),
              tooltip: 'View History',
            ),
        ],
      ),
      body: Column(
        children: [
          // Header Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
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
                    FontAwesomeIcons.calculator,
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
                        'Factor Dosage Calculator',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Calculate your recommended factor dosage',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Content Section
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Result Display Section
                        _buildResultContainer(),
                        const SizedBox(height: 24),

                        // Simple Parameters Section
                        Row(
                          children: [
                            Expanded(
                              child: _buildInputField(
                                controller: weightController,
                                label: 'Weight (kg)',
                                icon: Icons.monitor_weight_outlined,
                                hint: 'Enter weight',
                                helperText: 'Body weight in kilograms',
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildInputField(
                                controller: factorLevelController,
                                label: 'Target Factor Level (%)',
                                icon: Icons.percent,
                                hint: 'Enter level',
                                helperText: 'Desired factor level (1-100%)',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildHemophiliaTypeSelector(),

                        const SizedBox(height: 16),
                        // Auto-save toggle
                        _buildAutoSaveToggle(),

                        const SizedBox(height: 24),

                        // Calculate Button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton.icon(
                            onPressed: isSaving ? null : calculateDosage,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            icon: isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(FontAwesomeIcons.calculator,
                                    size: 20),
                            label: Text(
                              isSaving ? 'Saving...' : 'Calculate Dosage',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Information Section
                        if (!canEditHemophiliaType) _buildInfoBanner(),

                        const SizedBox(height: 24),

                        // Disclaimer Section
                        _buildDisclaimerSection(),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultContainer() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                    const Icon(Icons.calculate, color: Colors.green, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Recommended Dosage',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: result == null
                ? Column(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 34,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Enter parameters and press calculate',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  )
                : Column(
                    children: [
                      Text(
                        '${result!.toStringAsFixed(2)} IU',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 32,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'For $selectedType',
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
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

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    required String helperText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.shade500),
              prefixIcon: Icon(icon, color: Colors.green),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          helperText,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildAutoSaveToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: Colors.green),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Auto-save Calculations',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                Text(
                  'Automatically save calculations to history',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: autoSaveCalculations,
            onChanged: (value) {
              setState(() {
                autoSaveCalculations = value;
              });
            },
            activeColor: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildHemophiliaTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hemophilia Type',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: canEditHemophiliaType
                ? Colors.grey.shade50
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: canEditHemophiliaType
              ? DropdownButtonFormField<String>(
                  value: selectedType,
                  items: hemophiliaTypes
                      .map(
                        (type) =>
                            DropdownMenuItem(value: type, child: Text(type)),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => selectedType = val);
                  },
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.bloodtype, color: Colors.green),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                )
              : Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.bloodtype, color: Colors.grey.shade500),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          selectedType,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                      Icon(Icons.lock, color: Colors.grey.shade500, size: 20),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.blue, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hemophilia Type Locked',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your hemophilia type is set based on your profile and cannot be changed. Only caregivers can modify this setting.',
                  style: TextStyle(color: Colors.blue.shade600, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimerSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber,
                color: Colors.orange.shade700,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Important Disclaimer',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'This calculator provides estimates only. Always consult with your healthcare provider before making any changes to your treatment plan. Dosage requirements may vary based on individual factors.',
            style: TextStyle(
              color: Colors.orange.shade700,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  void _showCalculationHistory() {
    showModalBottomSheet(
      backgroundColor: Colors.white,
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.3,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: const [
                  Icon(Icons.history, color: Colors.green, size: 28),
                  SizedBox(width: 12),
                  Text(
                    'Calculation History',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Expanded(
                child: calculationHistory.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.hourglass_empty,
                                color: Colors.grey.shade400, size: 48),
                            const SizedBox(height: 12),
                            Text(
                              'No calculations yet.',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        itemCount: calculationHistory.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 5),
                        itemBuilder: (context, index) {
                          final calc = calculationHistory[index];
                          final timestamp = calc['createdAt']?.toDate();
                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.grey.shade200),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.07),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              leading: CircleAvatar(
                                backgroundColor: Colors.green.withOpacity(0.12),
                                child: const Icon(Icons.calculate,
                                    color: Colors.green),
                              ),
                              title: Text(
                                '${calc['calculatedDosage'].toStringAsFixed(2)} IU',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.green,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${calc['hemophiliaType']} • ${calc['weight']}kg • ${calc['targetFactorLevel']}%',
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (calc['notes'] != null &&
                                      calc['notes'].isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        'Notes: ${calc['notes']}',
                                        style: TextStyle(
                                          fontStyle: FontStyle.italic,
                                          color: Colors.grey.shade600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  if (timestamp != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.access_time,
                                              size: 14, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${timestamp.day}/${timestamp.month}/${timestamp.year} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}',
                                            style: TextStyle(
                                              color: Colors.grey.shade500,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
