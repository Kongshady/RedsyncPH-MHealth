import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hemophilia_manager/services/local_medication_reminder_service.dart';

class ScheduleMedicationScreen extends StatefulWidget {
  const ScheduleMedicationScreen({super.key});

  @override
  State<ScheduleMedicationScreen> createState() =>
      _ScheduleMedicationScreenState();
}

class _ScheduleMedicationScreenState extends State<ScheduleMedicationScreen> {
  final LocalMedicationReminderService _medicationReminderService =
      LocalMedicationReminderService();
  String _medType = 'IV Injection';
  final List<String> _medTypes = ['IV Injection', 'Subcutaneous', 'Oral'];
  final TextEditingController _doseController = TextEditingController();
  final TextEditingController _medicationNameController =
      TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));
  bool _notification = true;
  String _frequency = 'Daily';
  final List<String> _frequencies = [
    'Once',
    'Daily',
    'Every 3 Days',
  ];
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Schedule Medication',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        elevation: 0,
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
                    child: const Icon(Icons.schedule,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Schedule your medication',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Set reminders for your medication intake',
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
                      icon: Icons.medical_services_outlined,
                      hintText: 'e.g., Factor VIII, Desmopressin',
                    ),
                    const SizedBox(height: 16),

                    _buildDropdownField(
                      value: _medType,
                      items: _medTypes,
                      label: 'Administration Type',
                      icon: Icons.local_hospital,
                      onChanged: (val) {
                        if (val != null) setState(() => _medType = val);
                      },
                    ),
                    const SizedBox(height: 16),

                    _buildCustomInput(
                      controller: _doseController,
                      label: 'Dosage',
                      icon: Icons.colorize,
                      hintText: 'e.g., 1000 IU, 250 mg',
                    ),
                    const SizedBox(height: 16),

                    _buildTimeSelector(),
                    const SizedBox(height: 16),

                    _buildDropdownField(
                      value: _frequency,
                      items: _frequencies,
                      label: 'Frequency',
                      icon: Icons.repeat,
                      onChanged: (val) {
                        if (val != null) setState(() => _frequency = val);
                      },
                    ),
                    const SizedBox(height: 16),

                    _buildDateSelector(),
                    const SizedBox(height: 16),

                    _buildNotificationToggle(),
                    const SizedBox(height: 16),

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

                    const SizedBox(height: 32),

                    // Set Schedule Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _saveSchedule,
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
                            : const Icon(Icons.schedule, size: 20),
                        label: Text(
                          _isLoading ? 'Setting Schedule...' : 'Set Schedule',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Test Notification Button (Release mode only)
                    if (const bool.fromEnvironment('dart.vm.product') == true)
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: _testNotification,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange,
                            side: const BorderSide(color: Colors.orange),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon:
                              const Icon(Icons.notifications_active, size: 18),
                          label: const Text(
                            'Test Local Notification',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
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
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          labelStyle: TextStyle(color: Colors.grey.shade600),
          hintStyle: TextStyle(color: Colors.grey.shade400),
          prefixIcon: Icon(icon, color: Colors.blueAccent),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String value,
    required List<String> items,
    required String label,
    required IconData icon,
    required Function(String?) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
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
          labelStyle: TextStyle(color: Colors.grey.shade600),
          prefixIcon: Icon(icon, color: Colors.blueAccent),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildTimeSelector() {
    return GestureDetector(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: _selectedTime,
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(
                  primary: Colors.blueAccent,
                  onPrimary: Colors.white,
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          setState(() => _selectedTime = picked);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time, color: Colors.blueAccent, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reminder Time',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _selectedTime.format(context),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
    return _buildExpandableCalendar();
  }

  Widget _buildExpandableCalendar() {
    return GestureDetector(
      onTap: () => _showCalendarPopup(),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header Section
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.calendar_month,
                    color: Colors.blueAccent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Medication Schedule',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap to set dates',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: Colors.grey.shade400,
                  size: 20,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Date Display Section
            Row(
              children: [
                // Start Date
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.play_arrow,
                              color: Colors.green,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Start Date',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${_startDate.day}/${_startDate.month}/${_startDate.year}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Arrow indicator
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward,
                    color: Colors.blueAccent,
                    size: 16,
                  ),
                ),

                const SizedBox(width: 12),

                // End Date
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.stop_circle,
                              color: Colors.red,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'End Date',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${_endDate.day}/${_endDate.month}/${_endDate.year}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Duration Display
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
                  const Icon(Icons.timeline,
                      color: Colors.blueAccent, size: 16),
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
      ),
    );
  }

  Future<void> _showCalendarPopup() async {
    bool _isSelectingEndDate = false;
    DateTime tempStartDate = _startDate;
    DateTime tempEndDate = _endDate;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.9,
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_month,
                            color: Colors.blueAccent,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Select Medication Dates',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  _isSelectingEndDate
                                      ? 'Tap to select end date'
                                      : 'Tap to select start date',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _isSelectingEndDate
                                        ? Colors.red.shade600
                                        : Colors.green.shade600,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: Icon(
                              Icons.close,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Date Selection Tabs (like flight booking)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setDialogState(
                                  () => _isSelectingEndDate = false,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: !_isSelectingEndDate
                                        ? Colors.green
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        'Start Date',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: !_isSelectingEndDate
                                              ? Colors.white
                                              : Colors.grey.shade600,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${tempStartDate.day}/${tempStartDate.month}/${tempStartDate.year}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: !_isSelectingEndDate
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setDialogState(
                                  () => _isSelectingEndDate = true,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _isSelectingEndDate
                                        ? Colors.red
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        'End Date',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: _isSelectingEndDate
                                              ? Colors.white
                                              : Colors.grey.shade600,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${tempEndDate.day}/${tempEndDate.month}/${tempEndDate.year}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: _isSelectingEndDate
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Custom Range Calendar
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _isSelectingEndDate
                                ? Colors.red.shade300
                                : Colors.green.shade300,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _buildRangeCalendar(
                          tempStartDate,
                          tempEndDate,
                          _isSelectingEndDate,
                          (DateTime date) {
                            setDialogState(() {
                              if (_isSelectingEndDate) {
                                tempEndDate = date;
                                // Auto-switch to start date if user hasn't set it properly
                                if (tempEndDate.isBefore(tempStartDate)) {
                                  tempStartDate = tempEndDate.subtract(
                                    const Duration(days: 1),
                                  );
                                }
                              } else {
                                tempStartDate = date;
                                // Auto-adjust end date if it's before start date
                                if (tempEndDate.isBefore(tempStartDate)) {
                                  tempEndDate = tempStartDate.add(
                                    const Duration(days: 7),
                                  );
                                }
                                // Auto-switch to end date selection after selecting start date
                                _isSelectingEndDate = true;
                              }
                            });
                          },
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Duration Display
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.timeline,
                              color: Colors.blueAccent,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${tempEndDate.difference(tempStartDate).inDays + 1} day${tempEndDate.difference(tempStartDate).inDays != 0 ? 's' : ''} of treatment',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: TextButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: () {
                                // Update the main widget state
                                setState(() {
                                  _startDate = tempStartDate;
                                  _endDate = tempEndDate;
                                });
                                Navigator.of(context).pop();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueAccent,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Confirm Dates',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
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

  Future<void> _testNotification() async {
    try {
      await _medicationReminderService.sendTestNotification();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Test notification sent! Check your notifications.'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text('Error sending test notification: $e')),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _saveSchedule() async {
    // Validate form
    if (_medicationNameController.text.trim().isEmpty) {
      _showErrorDialog('Please enter the medication name');
      return;
    }

    if (_doseController.text.trim().isEmpty) {
      _showErrorDialog('Please enter the dosage');
      return;
    }

    if (_endDate.isBefore(_startDate)) {
      _showErrorDialog('End date must be after the start date');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showErrorDialog('User not logged in');
        return;
      }

      // Save to local storage instead of Firebase
      final scheduleId =
          await _medicationReminderService.saveMedicationReminder(
        uid: user.uid,
        medicationName: _medicationNameController.text.trim(),
        dosage: _doseController.text.trim(),
        administrationType: _medType,
        frequency: _frequency,
        reminderTime: _selectedTime,
        notificationEnabled: _notification,
        startDate: _startDate,
        endDate: _endDate,
        notes: _notesController.text.trim(),
      );

      print('✅ Medication reminder saved locally with ID: $scheduleId');

      // Show success dialog
      _showSuccessDialog();
    } catch (e) {
      _showErrorDialog('Failed to schedule medication: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error, color: Colors.red, size: 24),
              ),
              const SizedBox(width: 12),
              const Text('Error'),
            ],
          ),
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
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.green, size: 24),
              ),
              const SizedBox(width: 12),
              const Text('Schedule Set!'),
            ],
          ),
          content: Text(
            'Your medication reminder has been saved locally and scheduled successfully from ${_startDate.day}/${_startDate.month}/${_startDate.year} to ${_endDate.day}/${_endDate.month}/${_endDate.year}. ${_notification ? "You\'ll receive local notifications at ${_selectedTime.format(context)}." : "No notifications will be sent as notifications are disabled."}',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRangeCalendar(
    DateTime startDate,
    DateTime endDate,
    bool isSelectingEndDate,
    Function(DateTime) onDateSelected,
  ) {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    final daysInMonth = DateTime(
      currentMonth.year,
      currentMonth.month + 1,
      0,
    ).day;
    final firstDayOfMonth = DateTime(currentMonth.year, currentMonth.month, 1);
    final startingWeekday = firstDayOfMonth.weekday;

    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Month header
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Text(
                '${_monthNames[currentMonth.month - 1]} ${currentMonth.year}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),

            // Weekday headers
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                    .map(
                      (day) => Expanded(
                        child: Container(
                          height: 25,
                          child: Center(
                            child: Text(
                              day,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),

            // Calendar grid
            ...List.generate(
              6, // Max 6 weeks in a month view
              (weekIndex) {
                List<Widget> dayWidgets = [];

                for (int dayIndex = 0; dayIndex < 7; dayIndex++) {
                  final dayNumber =
                      weekIndex * 7 + dayIndex - startingWeekday + 2;

                  if (dayNumber < 1 || dayNumber > daysInMonth) {
                    // Empty day
                    dayWidgets.add(
                      Expanded(
                        child: Container(
                            height: 32, margin: const EdgeInsets.all(1)),
                      ),
                    );
                  } else {
                    final date = DateTime(
                      currentMonth.year,
                      currentMonth.month,
                      dayNumber,
                    );
                    final isToday = date.day == now.day &&
                        date.month == now.month &&
                        date.year == now.year;
                    final isStartDate = date.day == startDate.day &&
                        date.month == startDate.month &&
                        date.year == startDate.year;
                    final isEndDate = date.day == endDate.day &&
                        date.month == endDate.month &&
                        date.year == endDate.year;
                    final isInRange = date.isAfter(
                            startDate.subtract(const Duration(days: 1))) &&
                        date.isBefore(endDate.add(const Duration(days: 1)));
                    final isPastDate = date.isBefore(
                      DateTime(now.year, now.month, now.day),
                    );

                    dayWidgets.add(
                      Expanded(
                        child: GestureDetector(
                          onTap: isPastDate ? null : () => onDateSelected(date),
                          child: Container(
                            height: 32,
                            margin: const EdgeInsets.all(1),
                            decoration: BoxDecoration(
                              color: _getDayBackgroundColor(
                                isStartDate,
                                isEndDate,
                                isInRange,
                                isToday,
                                isPastDate,
                              ),
                              borderRadius: BorderRadius.circular(6),
                              border: isToday
                                  ? Border.all(
                                      color: Colors.blueAccent,
                                      width: 1.5,
                                    )
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                dayNumber.toString(),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: (isStartDate || isEndDate)
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: _getDayTextColor(
                                    isStartDate,
                                    isEndDate,
                                    isInRange,
                                    isPastDate,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                }

                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 1),
                  child: Row(children: dayWidgets),
                );
              },
            ).where((row) {
              // Only show rows that have at least one valid day
              return row.child is Row &&
                  ((row.child as Row).children.any(
                        (child) =>
                            child is Expanded && child.child is GestureDetector,
                      ));
            }).toList(),
          ],
        ),
      ),
    );
  }

  Color _getDayBackgroundColor(
    bool isStartDate,
    bool isEndDate,
    bool isInRange,
    bool isToday,
    bool isPastDate,
  ) {
    if (isPastDate) return Colors.grey.shade100;
    if (isStartDate) return Colors.green;
    if (isEndDate) return Colors.red;
    if (isInRange) return Colors.blue.shade100;
    if (isToday) return Colors.transparent;
    return Colors.transparent;
  }

  Color _getDayTextColor(
    bool isStartDate,
    bool isEndDate,
    bool isInRange,
    bool isPastDate,
  ) {
    if (isPastDate) return Colors.grey.shade400;
    if (isStartDate || isEndDate) return Colors.white;
    if (isInRange) return Colors.blue.shade700;
    return Colors.black87;
  }

  static const List<String> _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  void dispose() {
    _doseController.dispose();
    _medicationNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}

// TODO: Add calendar integration for medication reminders
