import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api_service.dart';
import '../theme.dart';

class ManageScheduleScreen extends StatefulWidget {
  final int eventId;

  const ManageScheduleScreen({super.key, required this.eventId});

  @override
  State<ManageScheduleScreen> createState() => _ManageScheduleScreenState();
}

class _ManageScheduleScreenState extends State<ManageScheduleScreen> {
  List<Map<String, dynamic>> _schedules = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  Future<void> _loadSchedules() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.fetchSchedules(widget.eventId);
      setState(() => _schedules = data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load schedules: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteSchedule(int id, String activityName) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Schedule'),
        content: Text('Are you sure you want to delete "$activityName"?'),
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
      ),
    );

    if (shouldDelete != true) return;

    try {
      await ApiService.deleteSchedule(widget.eventId, id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Schedule deleted successfully'), backgroundColor: Colors.green),
        );
      }
      await _loadSchedules();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete schedule: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showScheduleForm({Map<String, dynamic>? entry}) {
    showDialog(
      context: context,
      builder: (context) => ScheduleFormDialog(
        eventId: widget.eventId,
        scheduleEntry: entry,
        onSave: _loadSchedules,
      ),
    );
  }

  String _formatDuration(DateTime start, DateTime end) {
    final duration = end.difference(start);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    return hours == 0 ? '${minutes}m' : minutes == 0 ? '${hours}h' : '${hours}h ${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Schedule'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadSchedules,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showScheduleForm(),
        backgroundColor: primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: _loadSchedules,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    'Scheduled Activities',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  if (_schedules.isNotEmpty)
                    Text(
                      '${_schedules.length} ${_schedules.length == 1 ? 'entry' : 'entries'}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (_isLoading)
                const Center(child: CircularProgressIndicator(color: primaryColor))
              else if (_schedules.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.schedule, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No schedule entries yet',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add your first schedule entry using the + button',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _schedules.length,
                  itemBuilder: (context, index) {
                    final entry = _schedules[index];
                    DateTime? startTime;
                    DateTime? endTime;
                    try {
                      startTime = DateTime.parse(entry['start_time']);
                      endTime = DateTime.parse(entry['end_time']);
                    } catch (e) {
                      // Handle invalid date format
                    }

                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        title: Text(
                          entry['activity_name'] ?? 'Unnamed Activity',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            if (startTime != null && endTime != null) ...[
                              Row(
                                children: [
                                  const Icon(Icons.access_time, size: 16, color: textColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${DateFormat('MMM dd, yyyy HH:mm').format(startTime)} - '
                                        '${DateFormat('HH:mm').format(endTime)}',
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  const Icon(Icons.timer, size: 16, color: textColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Duration: ${_formatDuration(startTime, endTime)}',
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ] else
                              const Text('Invalid date format', style: TextStyle(color: Colors.red)),
                            if (entry['participants'] != null) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.people, size: 16, color: textColor),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      entry['participants'],
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (entry['description'] != null) ...[
                              const SizedBox(height: 4),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.description, size: 16, color: textColor),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      entry['description'],
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: accentColor),
                              onPressed: () => _showScheduleForm(entry: entry),
                              tooltip: 'Edit schedule',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () =>
                                  _deleteSchedule(entry['id'], entry['activity_name'] ?? 'Unnamed Activity'),
                              tooltip: 'Delete schedule',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class ScheduleFormDialog extends StatefulWidget {
  final int eventId;
  final Map<String, dynamic>? scheduleEntry;
  final VoidCallback onSave;

  const ScheduleFormDialog({
    super.key,
    required this.eventId,
    this.scheduleEntry,
    required this.onSave,
  });

  @override
  State<ScheduleFormDialog> createState() => _ScheduleFormDialogState();
}

class _ScheduleFormDialogState extends State<ScheduleFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _activityController = TextEditingController();
  final TextEditingController _participantsController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  DateTime? _startTime;
  DateTime? _endTime;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.scheduleEntry != null) {
      _activityController.text = widget.scheduleEntry!['activity_name'] ?? '';
      _participantsController.text = widget.scheduleEntry!['participants'] ?? '';
      _descriptionController.text = widget.scheduleEntry!['description'] ?? '';
      try {
        _startTime = DateTime.parse(widget.scheduleEntry!['start_time']);
        _endTime = DateTime.parse(widget.scheduleEntry!['end_time']);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid date format'), backgroundColor: Colors.orange),
          );
        }
      }
    }
  }

  Future<void> _pickDateTime(bool isStart) async {
    final now = DateTime.now();
    final initialDate = isStart ? (_startTime ?? now) : (_endTime ?? _startTime ?? now);

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null) return;

    final initialTime = TimeOfDay.fromDateTime(initialDate);
    final time = await showTimePicker(context: context, initialTime: initialTime);
    if (time == null) return;

    final dateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);

    setState(() {
      if (isStart) {
        _startTime = dateTime;
        if (_endTime != null && _endTime!.isBefore(dateTime.add(const Duration(minutes: 1)))) {
          _endTime = null;
        }
      } else {
        _endTime = dateTime;
      }
    });
  }

  Widget _buildDateTimePicker(String label, DateTime? value, bool isStart) {
    return InkWell(
      onTap: () => _pickDateTime(isStart),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: primaryColor, width: 2),
          ),
          suffixIcon: const Icon(Icons.calendar_today, color: textColor),
          errorText: _getDateTimeError(isStart),
        ),
        child: Text(
          value != null ? DateFormat('yyyy-MM-dd HH:mm').format(value) : 'Select $label',
          style: TextStyle(
            fontSize: 16,
            color: value != null ? textColor : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  String? _getDateTimeError(bool isStart) {
    if (isStart && _startTime == null) return null;
    if (!isStart && _endTime == null) return null;
    if (_startTime != null && _endTime != null && _endTime!.isBefore(_startTime!)) {
      return 'End time must be after start time';
    }
    return null;
  }

  Future<void> _submitSchedule() async {
    if (!_formKey.currentState!.validate()) return;

    if (_startTime == null || _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both start and end times'), backgroundColor: Colors.orange),
      );
      return;
    }

    if (_endTime!.isBefore(_startTime!) || _endTime!.isAtSameMomentAs(_startTime!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final data = {
      'activity_name': _activityController.text.trim(),
      'start_time': _startTime!.toIso8601String(),
      'end_time': _endTime!.toIso8601String(),
      'participants': _participantsController.text.trim().isEmpty ? null : _participantsController.text.trim(),
      'description': _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
    };

    try {
      if (widget.scheduleEntry != null) {
        await ApiService.updateSchedule(widget.eventId, widget.scheduleEntry!['id'], data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Schedule updated successfully'), backgroundColor: Colors.green),
          );
        }
      } else {
        await ApiService.createSchedule(widget.eventId, data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Schedule created successfully'), backgroundColor: Colors.green),
          );
        }
      }
      widget.onSave();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save schedule: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _formatDuration(DateTime start, DateTime end) {
    final duration = end.difference(start);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    return hours == 0 ? '${minutes}m' : minutes == 0 ? '${hours}h' : '${hours}h ${minutes}m';
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 12),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: primaryColor,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    int maxLines = 1,
    bool enabled = true,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: primaryColor, width: 2),
          ),
          prefixIcon: label.contains('Activity')
              ? const Icon(Icons.event, color: textColor)
              : label.contains('Participants')
              ? const Icon(Icons.people, color: textColor)
              : label.contains('Description')
              ? const Icon(Icons.description, color: textColor)
              : null,
        ),
        maxLines: maxLines,
        enabled: enabled,
        validator: validator ?? (value) => value == null || value.trim().isEmpty ? 'Required field' : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.scheduleEntry == null ? 'Create Schedule Entry' : 'Edit Schedule Entry',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: textColor),
                ),
                const SizedBox(height: 16),
                _sectionTitle('Schedule Details'),
                _buildTextField(
                  label: 'Activity Name *',
                  controller: _activityController,
                  enabled: !_isSubmitting,
                ),
                const SizedBox(height: 12),
                _sectionTitle('Date & Time'),
                Row(
                  children: [
                    Expanded(child: _buildDateTimePicker('Start Time *', _startTime, true)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildDateTimePicker('End Time *', _endTime, false)),
                  ],
                ),
                if (_startTime != null && _endTime != null && _endTime!.isAfter(_startTime!))
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Duration: ${_formatDuration(_startTime!, _endTime!)}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: accentColor),
                    ),
                  ),
                const SizedBox(height: 12),
                _sectionTitle('Additional Info'),
                _buildTextField(
                  label: 'Participants (Optional)',
                  controller: _participantsController,
                  enabled: !_isSubmitting,
                  validator: (_) => null, // Optional field
                ),
                _buildTextField(
                  label: 'Description (Optional)',
                  controller: _descriptionController,
                  maxLines: 3,
                  enabled: !_isSubmitting,
                  validator: (_) => null, // Optional field
                ),
                const SizedBox(height: 30),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitSchedule,
                        child: _isSubmitting
                            ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                            : Text(widget.scheduleEntry == null ? 'Create Entry' : 'Update Entry'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          'Cancel',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: textColor),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _activityController.dispose();
    _participantsController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}