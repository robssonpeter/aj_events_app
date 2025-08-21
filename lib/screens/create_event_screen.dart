import 'package:flutter/material.dart';
import '../theme.dart';
import '../api_service.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();

  String title = '';
  String description = '';
  String date = '';
  String time = '';
  String location = '';
  String capacity = '';

  bool isSubmitting = false;

  Future<void> submitEvent() async {
    if (!_formKey.currentState!.validate()) return;

    _formKey.currentState!.save();
    setState(() => isSubmitting = true);

    try {
      await ApiService.createEvent(
        title: title,
        description: description,
        date: date,
        time: time,
        location: location,
        capacity: int.tryParse(capacity) ?? 0,
      );
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event created successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Create Event'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('Event Details'),
              _buildTextField(label: 'Title', onSaved: (val) => title = val!),
              _buildTextField(
                label: 'Description',
                maxLines: 3,
                onSaved: (val) => description = val!,
              ),

              const SizedBox(height: 20),
              _sectionTitle('Date & Time'),
              _buildTextField(label: 'Date (YYYY-MM-DD)', onSaved: (val) => date = val!),
              _buildTextField(label: 'Time (HH:MM)', onSaved: (val) => time = val!),

              const SizedBox(height: 20),
              _sectionTitle('Location & Capacity'),
              _buildTextField(label: 'Location', onSaved: (val) => location = val!),
              _buildTextField(
                label: 'Capacity',
                keyboardType: TextInputType.number,
                onSaved: (val) => capacity = val!,
              ),

              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isSubmitting ? null : submitEvent,
                  child: isSubmitting
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                      : const Text('Submit Event'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required FormFieldSetter<String> onSaved,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
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
        ),
        maxLines: maxLines,
        keyboardType: keyboardType,
        onSaved: onSaved,
        validator: (value) => (value == null || value.trim().isEmpty) ? 'Required field' : null,
      ),
    );
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
}
