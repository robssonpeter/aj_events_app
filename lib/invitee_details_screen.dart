import 'package:aj_events/common.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'theme.dart'; // for primaryColor, accentColor, backgroundColor, textColor etc.

class InviteeDetailsScreen extends StatefulWidget {
  final int eventId;
  final String slug;

  const InviteeDetailsScreen({
    super.key,
    required this.eventId,
    required this.slug,
  });

  @override
  State<InviteeDetailsScreen> createState() => _InviteeDetailsScreenState();
}

class _InviteeDetailsScreenState extends State<InviteeDetailsScreen> {
  bool _isRedeeming = false;
  late Future<Map<String, dynamic>> _inviteeFuture;
  int _numberOfGuests = 1;

  @override
  void initState() {
    super.initState();
    _inviteeFuture = fetchInvitee();
  }

  Future<Map<String, dynamic>> fetchInvitee() async {
    final response = await http.get(
      Uri.parse('https://events.ajiriwa.net/api/invitees/${widget.eventId}/${widget.slug}'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      // initialize number of guests safely here instead of in build
      final isRedeemed = data['is_redeemed'] == 1;
      final totalInvitees = data['number_of_invitees'] ?? 1;
      final remainingInvitees = data['remaining_invitees'] ?? totalInvitees;
      _numberOfGuests = isRedeemed ? 0 : remainingInvitees;
      return data;
    } else {
      throw Exception('Failed to load invitee details');
    }
  }

  Future<void> redeemCard() async {
    setState(() => _isRedeeming = true);

    final response = await http.post(
      Uri.parse('https://events.ajiriwa.net/api/invitees/${widget.eventId}/${widget.slug}/redeem'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'number_of_guests': _numberOfGuests}),
    );

    setState(() => _isRedeeming = false);

    if (response.statusCode == 200) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Icon(Icons.check_circle, color: Colors.green, size: 48),
          content: const Text(
            'Card redeemed successfully!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );

      setState(() {
        _inviteeFuture = fetchInvitee(); // refresh the data
      });
    } else {
      // Try to parse error message from response
      String errorMessage = 'Failed to redeem card.';
      try {
        final responseData = json.decode(response.body);
        if (responseData['message'] != null) {
          errorMessage = responseData['message'];
        }
      } catch (_) {}

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: Text(errorMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  String formatTimestamp(String? raw) {
    if (raw == null || raw.isEmpty) return "N/A";
    try {
      final dt = DateTime.parse(raw).toLocal();
      return DateFormat('MMM d, yyyy – hh:mm a').format(dt);
    } catch (_) {
      return "Invalid date";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invitee Details', style: TextStyle(color: Colors.white)),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: backgroundColor,
      body: FutureBuilder<Map<String, dynamic>>(
        future: _inviteeFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !_isRedeeming) {
            return const Center(child: CircularProgressIndicator(color: primaryColor));
          }

          if (snapshot.hasError || snapshot.data == null) {
            return const Center(
              child: Text(
                'Failed to load invitee details',
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
            );
          }

          final invitee = snapshot.data!;
          final isRedeemed = invitee['is_redeemed'] == 1;
          final name = invitee['name'] ?? 'Unnamed';
          final code = invitee['slug'] ?? 'N/A';
          final photoUrl = invitee['photo_url'];
          final totalInvitees = invitee['number_of_invitees'] ?? 1;
          final remainingInvitees = invitee['remaining_invitees'] ?? totalInvitees;
          final inviteeCount = totalInvitees.toString();

          final initials = name.isNotEmpty
              ? name.trim().split(' ').where((String e) => e.isNotEmpty).map((String e) => e[0]).take(2).join().toUpperCase()
              : 'NA';

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Avatar + Name
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: accentColor,
                      backgroundImage: (photoUrl != null && photoUrl.toString().isNotEmpty)
                          ? NetworkImage(photoUrl)
                          : null,
                      child: (photoUrl == null || photoUrl.toString().isEmpty)
                          ? Text(
                        initials,
                        style: const TextStyle(fontSize: 24, color: Colors.white),
                      )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Info Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 6,
                        offset: Offset(2, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _infoRow('Invited Guests', inviteeCount),
                      const SizedBox(height: 12),
                      _infoRow('Code', code),
                      const SizedBox(height: 12),
                      _infoRow('Status', isRedeemed ? 'Redeemed' : 'Not Redeemed'),
                      const SizedBox(height: 12),
                      _infoRow('Remaining Invitees', remainingInvitees.toString()),
                      const SizedBox(height: 12),
                      _infoRow('Checked In', formatTimestamp(invitee['check_in_time'])),
                    ],
                  ),
                ),

                const Spacer(),

                // Number of guests selector
                if (!isRedeemed)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Number of guests to redeem:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: _numberOfGuests > 1
                                ? () => setState(() => _numberOfGuests--)
                                : null,
                            icon: const Icon(Icons.remove_circle_outline),
                            color: primaryColor,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _numberOfGuests.toString(),
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                          IconButton(
                            onPressed: _numberOfGuests < remainingInvitees
                                ? () => setState(() => _numberOfGuests++)
                                : null,
                            icon: const Icon(Icons.add_circle_outline),
                            color: primaryColor,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),

                // Redeem Button
                ElevatedButton(
                  onPressed: (isRedeemed || _isRedeeming) ? null : redeemCard,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isRedeeming
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Text(
                    'Redeem Card',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),

                const SizedBox(height: 12),

                // Back Button
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[400],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'Back',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 16, color: Colors.black87),
          ),
        ),
      ],
    );
  }
}
