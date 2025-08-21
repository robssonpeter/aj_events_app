import 'package:aj_events/screens/customize_invitation.dart';
import 'package:aj_events/screens/manage_receptionists_screen.dart';
import 'package:aj_events/screens/manage_schedule_screen.dart';
import 'package:aj_events/search_invitees_screen.dart';
import 'package:aj_events/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'scan_screen.dart';
import 'manage_invitees_screen.dart';

class EventScreen extends StatefulWidget {
  final int eventId;

  const EventScreen({super.key, required this.eventId});

  @override
  State<EventScreen> createState() => _EventScreenState();
}

class _EventScreenState extends State<EventScreen> {
  bool _hasAuthToken = false;

  @override
  void initState() {
    super.initState();
    _checkAuthToken();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Event Options'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
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
            _buildOptionTile(
              icon: Icons.edit,
              title: 'Customize Invitation',
              onTap: () => _navigateTo(CustomizeInvitationScreen(eventId: widget.eventId)),
            ),

            if (_hasAuthToken) ...[
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
