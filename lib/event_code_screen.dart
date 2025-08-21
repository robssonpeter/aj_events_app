import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'event_screen.dart';
import 'theme.dart'; // Make sure you have `primaryColor` defined here

class EventCodeScreen extends StatefulWidget {
  const EventCodeScreen({super.key});

  @override
  _EventCodeScreenState createState() => _EventCodeScreenState();
}

class _EventCodeScreenState extends State<EventCodeScreen> {
  final _codeController = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _validateCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Please enter an event code');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await http.get(
        Uri.parse('https://events.ajiriwa.net/api/events/lookup?code=$code'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final int eventId = data['id'];

        // Navigate to event screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) =>  ReceptionistEmailScreen(eventId: eventId)),//EventScreen(eventId: eventId)),
        );
      } else {
        setState(() => _error = 'Invalid event code');
      }
    } catch (e) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Enter Event Code')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon or illustration
                  const Icon(
                    Icons.lock_open_rounded,
                    size: 80,
                    color: primaryColor,
                  ),
                  const SizedBox(height: 24),

                  // Title
                  const Text(
                    'Enter Event Code',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Subtitle
                  const Text(
                    'Paste or type the code shared with you to access the event.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54),
                  ),

                  const SizedBox(height: 32),

                  // Text field
                  TextField(
                    controller: _codeController,
                    decoration: InputDecoration(
                      labelText: 'Event Code',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      errorText: _error,
                    ),
                    onSubmitted: (_) => _validateCode(),
                  ),

                  const SizedBox(height: 24),

                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                      onPressed: _validateCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(fontSize: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Continue'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


class ReceptionistEmailScreen extends StatefulWidget {
  final int eventId;

  const ReceptionistEmailScreen({super.key, required this.eventId});

  @override
  State<ReceptionistEmailScreen> createState() => _ReceptionistEmailScreenState();
}

class _ReceptionistEmailScreenState extends State<ReceptionistEmailScreen> {
  final _emailController = TextEditingController();
  String? _error;
  bool _loading = false;

  Future<void> _validateEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Please enter a valid email');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await http.get(
        Uri.parse('https://events.ajiriwa.net/api/events/${widget.eventId}/receptionists'),
      );

      if (response.statusCode == 200) {
        final List receptionists = json.decode(response.body);
        final isAuthorized = receptionists.any((r) =>
        r['email']?.toString().toLowerCase().trim() == email.toLowerCase());

        if (isAuthorized) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => EventScreen(eventId: widget.eventId),
            ),
          );
        } else {
          setState(() => _error = 'Email not authorized for this event.');
        }
      } else {
        setState(() => _error = 'Failed to fetch receptionist list.');
      }
    } catch (e) {
      setState(() => _error = 'An error occurred. Please try again.');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Enter Email'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.email, size: 80, color: primaryColor),
                const SizedBox(height: 24),
                const Text(
                  'Enter your email',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryColor),
                ),
                const SizedBox(height: 12),
                const Text(
                  'This must match the email registered for you as a receptionist.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    errorText: _error,
                  ),
                  onSubmitted: (_) => _validateEmail(),
                ),
                const SizedBox(height: 24),
                _loading
                    ? const Center(
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                )
                    : SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _validateEmail,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                    child: const Text('Continue'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

