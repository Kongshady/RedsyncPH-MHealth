import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hemophilia_manager/services/local_medication_reminder_service.dart';

class EditMedicationReminderScreen extends StatefulWidget {
  const EditMedicationReminderScreen({super.key});

  @override
  State<EditMedicationReminderScreen> createState() =>
      _EditMedicationReminderScreenState();
}

class _EditMedicationReminderScreenState
    extends State<EditMedicationReminderScreen> {
  final LocalMedicationReminderService _localReminderService =
      LocalMedicationReminderService();

  late Map<String, dynamic> _originalReminder;
  late TextEditingController _medicationNameController;
  late TextEditingController _doseController;
  late TextEditingController _notesController;

  String _medType = 'IV Injection';
  final List<String> _medTypes = ['IV Injection', 'Subcutaneous', 'Oral'];
  String _frequency = 'Daily';
  final List<String> _frequencies = ['Once', 'Daily', 'Every 3 Days'];
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));
  bool _notification = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _medicationNameController = TextEditingController();
    _doseController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get the reminder data passed from the previous screen
    final Map<String, dynamic>? reminderData =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    if (reminderData != null) {
      _originalReminder = reminderData;
      _populateFields();
    }
  }

  void _populateFields() {
    _medicationNameController.text = _originalReminder['medicationName'] ?? '';
    _doseController.text = _originalReminder['dosage'] ?? '';
    _notesController.text = _originalReminder['notes'] ?? '';
    _medType = _originalReminder['administrationType'] ?? 'IV Injection';
    _frequency = _originalReminder['frequency'] ?? 'Daily';
    _notification = _originalReminder['notificationEnabled'] ?? true;

    // Parse reminder time - check multiple possible formats
    if (_originalReminder.containsKey('reminderTimeHour') &&
        _originalReminder.containsKey('reminderTimeMinute')) {
      // Format 1: Separate hour and minute fields
      final hour = _originalReminder['reminderTimeHour'] as int? ?? 9;
      final minute = _originalReminder['reminderTimeMinute'] as int? ?? 0;
      _selectedTime = TimeOfDay(hour: hour, minute: minute);
    } else if (_originalReminder.containsKey('reminderDateTime')) {
      // Format 2: DateTime object
      final reminderTime = _originalReminder['reminderDateTime'] as DateTime?;
      if (reminderTime != null) {
        _selectedTime = TimeOfDay(
          hour: reminderTime.hour,
          minute: reminderTime.minute,
        );
      }
    } else if (_originalReminder.containsKey('reminderTime')) {
      // Format 3: TimeOfDay or string format
      final reminderTime = _originalReminder['reminderTime'];
      if (reminderTime is TimeOfDay) {
        _selectedTime = reminderTime;
      } else if (reminderTime is String) {
        // Parse string format like "09:00"
        try {
          final parts = reminderTime.split(':');
          if (parts.length == 2) {
            _selectedTime = TimeOfDay(
              hour: int.parse(parts[0]),
              minute: int.parse(parts[1]),
            );
          }
        } catch (e) {
          print('Error parsing reminder time: $e');
        }
      }
    }

    // Set dates (using current logic for now)
    _startDate = DateTime.now();
    _endDate = DateTime.now().add(const Duration(days: 7));
  }

  @override
  void dispose() {
    _medicationNameController.dispose();
    _doseController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Edit Medication Reminder',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _deleteReminder,
            icon: const Icon(Icons.delete),
            tooltip: 'Delete Reminder',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.blueAccent,
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
                    child:
                        const Icon(Icons.edit, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Edit your medication reminder',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Update your medication schedule and settings',
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
                child: Column(
                  children: [
                    _buildCustomInput(
                      controller: _medicationNameController,
                      label: 'Medication Name',
                      icon: Icons.medication,
                      hintText: 'Enter medication name',
                    ),
                    const SizedBox(height: 10),

                    _buildCustomInput(
                      controller: _doseController,
                      label: 'Dosage',
                      icon: Icons.medical_services,
                      hintText: 'e.g., 500mg, 2 tablets',
                    ),
                    const SizedBox(height: 10),

                    _buildDropdown(
                      label: 'Administration Type',
                      value: _medType,
                      items: _medTypes,
                      onChanged: (val) {
                        if (val != null) setState(() => _medType = val);
                      },
                    ),
                    const SizedBox(height: 10),

                    _buildTimeSelector(),
                    const SizedBox(height: 10),

                    _buildDropdown(
                      label: 'Frequency',
                      value: _frequency,
                      items: _frequencies,
                      onChanged: (val) {
                        if (val != null) setState(() => _frequency = val);
                      },
                    ),
                    const SizedBox(height: 10),

                    _buildDateSelector(),
                    const SizedBox(height: 10),

                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: TextField(
                        controller: _notesController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Additional Notes (Optional)',
                          hintText: 'Any special instructions or notes...',
                          hintStyle: TextStyle(color: Colors.grey.shade500),
                          prefixIcon: const Icon(
                            Icons.note_outlined,
                            color: Colors.blueAccent,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    _buildNotificationToggle(),
                    const SizedBox(height: 15),

                    // Update Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _updateReminder,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: _isLoading
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
                          _isLoading ? 'Updating...' : 'Update Reminder',
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
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.grey.shade500),
          prefixIcon: Icon(icon, color: Colors.blueAccent),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.list, color: Colors.blueAccent),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
        items: items
            .map((item) => DropdownMenuItem(
                  value: item,
                  child: Text(item),
                ))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildTimeSelector() {
    return InkWell(
      onTap: _selectTime,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time, color: Colors.blueAccent),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Reminder Time',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _selectedTime.format(context),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.edit, color: Colors.grey.shade400, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.calendar_today, color: Colors.blueAccent),
              SizedBox(width: 12),
              Text(
                'Treatment Duration',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Start Date',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_startDate.day}/${_startDate.month}/${_startDate.year}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.grey.shade300,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'End Date',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_endDate.day}/${_endDate.month}/${_endDate.year}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.timeline, color: Colors.blueAccent, size: 16),
                const SizedBox(width: 8),
                Text(
                  '${_endDate.difference(_startDate).inDays + 1} day${_endDate.difference(_startDate).inDays != 0 ? 's' : ''} of treatment',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _notification ? Colors.blue.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _notification ? Colors.blue.shade200 : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _notification ? Colors.blueAccent : Colors.grey.shade400,
              shape: BoxShape.circle,
            ),
            child:
                const Icon(Icons.notifications, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Push Notifications',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Get reminded when it\'s time to take your medication',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Switch(
            value: _notification,
            onChanged: (val) => setState(() => _notification = val),
            activeColor: Colors.blueAccent,
          ),
        ],
      ),
    );
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blueAccent,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _updateReminder() async {
    // Validate form
    if (_medicationNameController.text.trim().isEmpty) {
      _showErrorDialog('Please enter the medication name');
      return;
    }

    if (_doseController.text.trim().isEmpty) {
      _showErrorDialog('Please enter the dosage');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showErrorDialog('User not logged in');
        return;
      }

      // Update the existing reminder
      final updates = {
        'medicationName': _medicationNameController.text.trim(),
        'dosage': _doseController.text.trim(),
        'administrationType': _medType,
        'frequency': _frequency,
        'reminderTimeHour': _selectedTime.hour,
        'reminderTimeMinute': _selectedTime.minute,
        'notificationEnabled': _notification,
        'startDate': _startDate,
        'endDate': _endDate,
        'notes': _notesController.text.trim(),
      };

      await _localReminderService.updateMedicationReminder(
        _originalReminder['id'],
        updates,
      );

      // Show success and return
      _showSuccessDialog();
    } catch (e) {
      _showErrorDialog('Failed to update medication reminder: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteReminder() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            'Delete Reminder',
            style:
                TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent),
          ),
          content: const Text(
            'Are you sure you want to delete this medication reminder? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        setState(() => _isLoading = true);

        await _localReminderService.deleteMedicationReminder(
          _originalReminder['id'],
        );

        if (mounted) {
          Navigator.of(context).pop(true); // Return true to indicate deletion
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.delete, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Medication reminder deleted successfully'),
                ],
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          _showErrorDialog('Failed to delete reminder: $e');
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Success!',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.green)),
            ],
          ),
          content: const Text(
            'Your medication reminder has been updated successfully!',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context)
                    .pop(true); // Return true to indicate success
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
}
