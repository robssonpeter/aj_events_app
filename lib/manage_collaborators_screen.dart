import 'package:flutter/material.dart';
import 'package:aj_events/api_service.dart';
import 'package:aj_events/theme.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ManageCollaboratorsScreen extends StatefulWidget {
  final int eventId;

  const ManageCollaboratorsScreen({super.key, required this.eventId});

  @override
  State<ManageCollaboratorsScreen> createState() => _ManageCollaboratorsScreenState();
}

class _ManageCollaboratorsScreenState extends State<ManageCollaboratorsScreen> {
  bool _isLoading = true;
  bool _isOwner = false;
  List<Map<String, dynamic>> _collaborators = [];
  final TextEditingController _emailController = TextEditingController();
  bool _canDeleteInvitees = false;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadCollaborators();
    _checkOwnerStatus();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _checkOwnerStatus() async {
    try {
      final status = await ApiService.checkCollaboratorStatus(widget.eventId);
      setState(() {
        _isOwner = status['is_owner'] ?? false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error checking owner status: $e')),
      );
    }
  }

  Future<void> _loadCollaborators() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final collaborators = await ApiService.getEventCollaborators(widget.eventId);
      setState(() {
        _collaborators = collaborators;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading collaborators: $e')),
      );
    }
  }

  Future<void> _addCollaborator() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await ApiService.addCollaborator(
        eventId: widget.eventId,
        email: _emailController.text.trim(),
        canDeleteInvitees: _canDeleteInvitees,
      );

      _emailController.clear();
      setState(() {
        _canDeleteInvitees = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Collaborator added successfully')),
      );

      _loadCollaborators();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding collaborator: $e')),
      );
    }
  }

  Future<void> _updateCollaboratorPermissions(int userId, bool canDeleteInvitees) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await ApiService.updateCollaboratorPermissions(
        eventId: widget.eventId,
        userId: userId,
        canDeleteInvitees: canDeleteInvitees,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permissions updated successfully')),
      );

      _loadCollaborators();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating permissions: $e')),
      );
    }
  }

  Future<void> _removeCollaborator(int userId) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await ApiService.removeCollaborator(
        eventId: widget.eventId,
        userId: userId,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Collaborator removed successfully')),
      );

      _loadCollaborators();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error removing collaborator: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Manage Collaborators'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : !_isOwner
              ? const Center(
                  child: Text(
                    'Only the event owner can manage collaborators',
                    style: TextStyle(fontSize: 16),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Add New Collaborator',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _emailController,
                              decoration: InputDecoration(
                                labelText: 'Email',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter an email';
                                }
                                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                  return 'Please enter a valid email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Checkbox(
                                  value: _canDeleteInvitees,
                                  onChanged: (value) {
                                    setState(() {
                                      _canDeleteInvitees = value ?? false;
                                    });
                                  },
                                ),
                                const Text('Can delete invitees'),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _addCollaborator,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('Add Collaborator'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'Current Collaborators',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _collaborators.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text(
                                  'No collaborators yet',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _collaborators.length,
                              itemBuilder: (context, index) {
                                final collaborator = _collaborators[index];
                                final userId = collaborator['id'];
                                final name = collaborator['name'] ?? 'Unknown';
                                final email = collaborator['email'] ?? 'No email';
                                final canDeleteInvitees = (collaborator['pivot']?['can_delete_invitees'] == 1) ? true : false;

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          email,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Row(
                                          children: [
                                            const Text('Can delete invitees:'),
                                            Switch(
                                              value: canDeleteInvitees,
                                              onChanged: (value) {
                                                _updateCollaboratorPermissions(userId, value);
                                              },
                                              activeColor: primaryColor,
                                            ),
                                            const Spacer(),
                                            IconButton(
                                              icon: const Icon(Icons.delete, color: Colors.red),
                                              onPressed: () {
                                                showDialog(
                                                  context: context,
                                                  builder: (context) => AlertDialog(
                                                    title: const Text('Remove Collaborator'),
                                                    content: Text('Are you sure you want to remove $name as a collaborator?'),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () => Navigator.pop(context),
                                                        child: const Text('Cancel'),
                                                      ),
                                                      TextButton(
                                                        onPressed: () {
                                                          Navigator.pop(context);
                                                          _removeCollaborator(userId);
                                                        },
                                                        child: const Text('Remove', style: TextStyle(color: Colors.red)),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                            ),
                                          ],
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
    );
  }
}
