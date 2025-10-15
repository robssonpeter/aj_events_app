import 'dart:convert';

import 'package:aj_events/screens/customize_invitation.dart';
import 'package:aj_events/screens/manage_receptionists_screen.dart';
import 'package:aj_events/screens/manage_schedule_screen.dart';
import 'package:aj_events/search_invitees_screen.dart';
import 'package:aj_events/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:aj_events/api_service.dart';

import 'scan_screen.dart';
import 'manage_invitees_screen.dart';
import 'manage_collaborators_screen.dart';

class EventScreen extends StatefulWidget {
  final int eventId;

  const EventScreen({super.key, required this.eventId});

  @override
  State<EventScreen> createState() => _EventScreenState();
}

class _EventScreenState extends State<EventScreen> {
  bool _hasAuthToken = false;
  String _eventName = '';
  bool _isLoading = true;
  bool _isEventOwner = false;
  String _eventCode = '';

  @override
  void initState() {
    super.initState();
    _checkAuthToken();
    _fetchEventDetails();
    _checkEventOwnerStatus();
  }

  Future<void> _checkAuthToken() async {
    const storage = FlutterSecureStorage();
    String? token = await storage.read(key: 'auth_token');

    if (token != null && token.isNotEmpty) {
      setState(() {
        _hasAuthToken = true;
      });
    }
  }

  Future<void> _checkEventOwnerStatus() async {
    if (!_hasAuthToken) return;

    try {
      final status = await ApiService.checkCollaboratorStatus(widget.eventId);
      setState(() {
        print("the owner of the event is ${status['is_owner']}");
        _isEventOwner = status['is_owner'] ?? false;
      });
    } catch (e) {
      // Silently handle error, default to false
      setState(() {
        _isEventOwner = false;
      });
    }
  }

  Future<void> _fetchEventDetails() async {
    try {
      final events = await ApiService.fetchEvents();
      final event = events.firstWhere(
        (event) => event['id'] == widget.eventId,
        orElse: () => {'title': 'Unknown Event'},
      );

      setState(() {
        _eventName = event['title'] ?? 'Unknown Event';
        _isLoading = false;
        _isEventOwner = event['is_owner'];
        _eventCode = event['code'];
      });
    } catch (e) {
      setState(() {
        _eventName = 'Unknown Event';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: _isLoading
            ? const Text('Event Options')
            : Text(_eventName),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose an Option',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            if (!_isLoading && _eventName.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Event: $_eventName',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                  fontStyle: FontStyle.italic,
                ),
              ),
              if (_eventCode.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'Event Code: $_eventCode',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: _eventCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Code copied to clipboard'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      child: const Icon(
                        Icons.copy,
                        size: 18,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              ],
            ],
            const SizedBox(height: 24),

            // Event Option Tiles
            _buildOptionTile(
              icon: Icons.qr_code_scanner,
              title: 'Scan Cards',
              onTap: () => _navigateTo(ScanScreen(eventId: widget.eventId)),
            ),
            _buildOptionTile(
              icon: Icons.search,
              title: 'Search Invitees by Name',
              onTap: () => _navigateTo(SearchInviteesScreen(eventId: widget.eventId)),
            ),

            if (_hasAuthToken) ...[
              _buildOptionTile(
                icon: Icons.edit,
                title: 'Customize Invitation',
                onTap: () => _navigateTo(CustomizeInvitationScreen(eventId: widget.eventId)),
              ),
              _buildOptionTile(
                icon: Icons.group,
                title: 'Manage Invitees',
                onTap: () => _navigateTo(ManageInviteesScreen(eventId: widget.eventId)),
              ),
              _buildOptionTile(
                icon: Icons.badge,
                title: 'Manage Receptionists',
                onTap: () => _navigateTo(ManageReceptionistsScreen(eventId: widget.eventId)),
              ),
              _buildOptionTile(
                icon: Icons.schedule,
                title: 'Manage Schedule',
                onTap: () => _navigateTo(ManageScheduleScreen(eventId: widget.eventId)),
              ),
              if (_isEventOwner)
                _buildOptionTile(
                  icon: Icons.people,
                  title: 'Manage Collaborators',
                  onTap: () => _navigateTo(ManageCollaboratorsScreen(eventId: widget.eventId)),
                ),
            ],
          ],
        ),
      ),
    );
  }

  void _navigateTo(Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: primaryColor,
                  radius: 24,
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ),
                Icon(Icons.arrow_forward_ios, color: Colors.grey.shade400, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
