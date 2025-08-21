import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../common.dart'; // Contains `color` (probably primary), `backgroundColor`, etc.
import '../theme.dart';  // Includes `primaryColor`, `textColor`, etc.

class ManageReceptionistsScreen extends StatefulWidget {
  final int eventId;

  const ManageReceptionistsScreen({super.key, required this.eventId});

  @override
  State<ManageReceptionistsScreen> createState() => _ManageReceptionistsScreenState();
}

class _ManageReceptionistsScreenState extends State<ManageReceptionistsScreen> {
  List receptionists = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchReceptionists();
  }

  Future<void> _fetchReceptionists() async {
    final response = await http.get(
      Uri.parse('https://events.ajiriwa.net/api/events/${widget.eventId}/receptionists'),
    );

    if (response.statusCode == 200) {
      setState(() {
        receptionists = json.decode(response.body);
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
      _showSnack('Failed to load receptionists.');
    }
  }

  final _secureStorage = FlutterSecureStorage();

  Future<void> _addReceptionist(String email) async {
    final token = await _secureStorage.read(key: 'auth_token');

    if (token == null) {
      _showSnack('Authentication required.');
      return;
    }

    final response = await http.post(
      Uri.parse('https://events.ajiriwa.net/api/events/${widget.eventId}/receptionists'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({'email': email}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final created = json.decode(response.body);
      setState(() => receptionists.insert(0, created));
      Navigator.pop(context);
      _showSnack('Receptionist added.');
    } else {
      _showSnack('Failed to add receptionist.');
    }
  }

  Future<void> _deleteReceptionist(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Remove this receptionist?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final response = await http.delete(
      Uri.parse('https://events.ajiriwa.net/api/receptionists/$id'),
    );

    if (response.statusCode == 200) {
      setState(() => receptionists.removeWhere((r) => r['id'] == id));
      _showSnack('Receptionist removed.');
    } else {
      _showSnack('Failed to delete receptionist.');
    }
  }

  void _showAddDialog() {
    final emailController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            backgroundColor: backgroundColor,
            title: Text('Add Receptionist', style: TextStyle(color: textColor)),
            content: TextField(
              controller: emailController,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: 'Enter email',
                hintStyle: TextStyle(color: textColor.withOpacity(0.6)),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: primaryColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: primaryColor, width: 2),
                ),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: TextStyle(color: secondaryColor)),
              ),
              isSubmitting
                  ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor),
                ),
              )
                  : ElevatedButton(
                onPressed: () async {
                  final email = emailController.text.trim();
                  if (email.isEmpty || !email.contains('@')) {
                    _showSnack('Enter a valid email');
                    return;
                  }

                  setState(() => isSubmitting = true);
                  await _addReceptionist(email);
                  setState(() => isSubmitting = false);
                },
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                child: const Text('Add'),
              ),
            ],
          ),
        );
      },
    );
  }



  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: primaryColor,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Manage Receptionists'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : receptionists.isEmpty
          ? Center(
        child: Text(
          'No receptionists yet.',
          style: TextStyle(fontSize: 16, color: textColor.withOpacity(0.6)),
        ),
      )
          : ListView.separated(
        itemCount: receptionists.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final r = receptionists[index];
            final email = r['email'] ?? '';

            return Dismissible(
              key: ValueKey(r['id']),
              direction: DismissDirection.endToStart,
              onDismissed: (_) => _deleteReceptionist(r['id']),
              background: Container(
                color: Colors.red,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              confirmDismiss: (_) async => await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Confirm Delete'),
                  content: Text('Are you sure you want to remove $email?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              ),
              child: Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                color: Colors.white,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  leading: CircleAvatar(
                    backgroundColor: primaryColor.withOpacity(0.1),
                    child: Icon(Icons.person, color: primaryColor),
                  ),
                  title: Text(
                    email,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                ),
              ),
            );
          }

      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: primaryColor,
        child: const Icon(Icons.add),
      ),
    );
  }
}
