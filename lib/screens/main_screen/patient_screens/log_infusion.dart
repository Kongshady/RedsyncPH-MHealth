import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/offline_service.dart';
import '../../../models/offline/infusion_log.dart';
import '../../../widgets/offline_indicator.dart';

class LogInfusionScreen extends StatefulWidget {
  const LogInfusionScreen({super.key});

  @override
  State<LogInfusionScreen> createState() => _LogInfusionScreenState();
}

class _LogInfusionScreenState extends State<LogInfusionScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _medicationController = TextEditingController();
  final TextEditingController _doseController = TextEditingController();
  final TextEditingController _lotNumberController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isSaving = false;
  String _selectedMedicationType = '';

  // Firebase services and offline service
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final OfflineService _offlineService = OfflineService();

  final List<String> _medicationTypes = [
    'Advate',
    'Adynovate',
    'Adynovi',
    'Afstyla',
    'Alhemo',
    'Alphanate',
    'Alpahanine SD',
    'Alprolix',
    'Altuviio',
    'Altuvoct',
    'Amicar',
    'Atenativ',
    'Benefix',
    'Beriate',
    'Betafact',
    'Biostate',
    'Clottafact',
    'Coagadex',
    'Confidex',
    'Confact',
    'Elocta',
    'Eloctate',
    'Esperoct',
    'Factane',
    'Fanhdi',
    'Feiba',
    'Feiba NF',
    'Fibrogammin P',
    'Fibryga',
    'Fitusiran',
    'Haemate P',
    'Haemosolvate',
    'Helixate FS',
    'Helixate Nexgen',
    'Hemlibra',
    'Hemofil M',
    'Hemoleven',
    'Humate P',
    'Hympavzi',
    'Idelvon',
    'Immunine',
    'Immuseven',
    'Ixnity',
    'Jivi',
    'Kanokad',
    'Koate DVI',
    'Kogenate Bayer',
    'Kogenate FS',
    'Kovaltry',
    'Minirin',
    'Monoclate P',
    'Mononine',
    'Novoeight',
    'Novoseven',
    'Novoseven RT',
    'Novothirteen',
    'Nuwiq',
    'Obizur',
    'Octafix',
    'Octanate',
    'Octanine',
    'Octaplex',
    'Octosim',
    'Optivate',
    'Qtifilia',
    'Rebinyn',
    'Recombinate',
    'Refacto AF',
    'Refixia',
    'Riastap',
    'Rixubis',
    'Sevenfact',
    'Stimate',
    'Tretten',
    'Veyvondi',
    'Vonvendi',
    'Wilate',
    'Wilfactin',
    'Xyntha',
    'Xyntha Solofuse',
    'Zonovate',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _selectedTime = TimeOfDay.now();
    _initOfflineService();
  }

  Future<void> _initOfflineService() async {
    try {
      await _offlineService.initialize();
      print('Offline service initialized successfully');
    } catch (e) {
      print('Error initializing offline service: $e');
    }
  }

  Future<void> _saveInfusion() async {
    if (!_formKey.currentState!.validate() ||
        _selectedDate == null ||
        _selectedTime == null) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      final timeStr = _selectedTime!.format(context);
      final user = _auth.currentUser;

      // Create infusion log data using our new model
      final log = InfusionLog(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        uid: user?.uid ?? 'guest',
        medication: _medicationController.text.trim(),
        doseIU: int.tryParse(_doseController.text.trim()) ?? 0,
        date: dateStr,
        time: timeStr,
        notes: _notesController.text.trim(),
        lotNumber: _lotNumberController.text.trim(),
        createdAt: DateTime.now(),
      );

      // Save using our new offline service (handles both local and cloud storage)
      await _offlineService.saveInfusionLogOffline(
        medication: log.medication,
        doseIU: log.doseIU,
        date: log.date,
        time: log.time,
        notes: log.notes,
        lotNumber: log.lotNumber,
      );

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Infusion logged successfully!'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      print('Error saving infusion log: $e');

      if (!mounted) return;

      // Determine error type and provide helpful message
      String errorMessage;

      if (e.toString().contains('HiveError') ||
          e.toString().contains('type') ||
          e.toString().contains('incompatible') ||
          e.toString().contains('schema')) {
        errorMessage =
            'Database compatibility issue detected. The app will attempt to fix this automatically on the next save attempt.';
      } else {
        errorMessage = 'Error saving infusion log: ${e.toString()}';
      }

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(errorMessage),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Log Infusion',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const OfflineIndicator(),

            // Header Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.deepPurple,
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
                    child: const Icon(Icons.medical_services,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Record your infusion',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Track your medication intake accurately',
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

            // Form Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildCustomDropdown(
                        value: _selectedMedicationType.isEmpty
                            ? null
                            : _selectedMedicationType,
                        items: _medicationTypes,
                        label: 'Medication Type',
                        icon: Icons.medication_liquid,
                        hintText: 'Select medication type',
                        onChanged: (value) {
                          setState(() => _selectedMedicationType = value ?? '');
                          if (value == 'Other') {
                            _medicationController.clear();
                          } else if (value != null) {
                            _medicationController.text = value;
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      _buildCustomInput(
                        controller: _medicationController,
                        label: 'Medication Name',
                        icon: Icons.medical_services_outlined,
                        hintText: 'Enter specific medication name',
                        validator: (v) => v == null || v.isEmpty
                            ? 'Enter medication name'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      _buildCustomInput(
                        controller: _doseController,
                        label: 'Dose (IU)',
                        icon: Icons.colorize,
                        hintText: 'Enter dose amount',
                        keyboardType: TextInputType.number,
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Enter dose amount' : null,
                      ),
                      const SizedBox(height: 16),

                      _buildCustomInput(
                        controller: _lotNumberController,
                        label: 'Lot Number',
                        icon: Icons.qr_code,
                        hintText: 'Enter lot number (optional)',
                        keyboardType: TextInputType.text,
                      ),
                      const SizedBox(height: 16),

                      _buildDateTimeSelector(),
                      const SizedBox(height: 16),

                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: TextFormField(
                          controller: _notesController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: 'Additional Notes (Optional)',
                            hintText:
                                'Any special notes about this infusion...',
                            hintStyle: TextStyle(color: Colors.grey.shade500),
                            prefixIcon: const Icon(
                              Icons.note_outlined,
                              color: Colors.deepPurple,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(16),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _saveInfusion,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save, size: 20),
                          label: Text(
                            _isSaving ? 'Saving Infusion...' : 'Save Infusion',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hintText,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          labelStyle: TextStyle(color: Colors.grey.shade600),
          hintStyle: TextStyle(color: Colors.grey.shade400),
          prefixIcon: Icon(icon, color: Colors.deepPurple),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildCustomDropdown({
    required String? value,
    required List<String> items,
    required String label,
    required IconData icon,
    required String hintText,
    required Function(String?) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        items: items
            .map((item) => DropdownMenuItem(value: item, child: Text(item)))
            .toList(),
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          labelStyle: TextStyle(color: Colors.grey.shade600),
          hintStyle: TextStyle(color: Colors.grey.shade400),
          prefixIcon: Icon(icon, color: Colors.deepPurple),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildDateTimeSelector() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _pickDate,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, color: Colors.deepPurple),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Date',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _selectedDate != null
                                ? DateFormat('MMM dd, yyyy')
                                    .format(_selectedDate!)
                                : 'Select date',
                            style: TextStyle(
                              color: _selectedDate != null
                                  ? Colors.black87
                                  : Colors.grey.shade400,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: _pickTime,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.access_time, color: Colors.deepPurple),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Time',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _selectedTime != null
                                ? _selectedTime!.format(context)
                                : 'Select time',
                            style: TextStyle(
                              color: _selectedTime != null
                                  ? Colors.black87
                                  : Colors.grey.shade400,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.deepPurple,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.deepPurple,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }
}
