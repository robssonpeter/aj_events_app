import 'dart:io';
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:aj_events/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cross_file/cross_file.dart';
import 'package:excel/excel.dart';

import 'common.dart';
import 'api_service.dart';
import 'widgets/invitee_card.dart';
import 'widgets/invitee_actions_toolbar.dart';
import 'widgets/invitee_filter_bar.dart';

class ManageInviteesScreen extends StatefulWidget {
  final int eventId;
  const ManageInviteesScreen({super.key, required this.eventId});

  @override
  _ManageInviteesScreenState createState() => _ManageInviteesScreenState();
}

class _ManageInviteesScreenState extends State<ManageInviteesScreen> {
  List invitees = [];
  List filteredInvitees = [];
  int currentPage = 1, lastPage = 1;
  int totalFilteredInvitees = 0; // Store the total count from the API
  bool isLoading = false;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _numberController = TextEditingController();
  // null = auto-detect (add flow only; edit always resolves to a real value
  // before the dialog opens).
  bool? _isOnWhatsapp;
  bool _isSubmitting = false;
  bool isBulkMode = false;
  Set<int> selectedInviteeIds = {};

  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _searchDebounceTimer;

  // Filter states
  bool _isFilterActive = false;
  bool? _filterWhatsappStatus;
  bool? _filterInvitationSent;
  String? _filterAttendanceStatus;
  bool? _filterCardRedeemed;
  bool? _filterSeenStatus;

  // Template states
  Map<String, dynamic> _templates = {
    'whatsapp': null,
    'sms': null,
    'download_card': null,
  };
  bool _isLoadingTemplates = false;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    fetchInvitees();
    _fetchTemplates();
    _scrollController.addListener(_onScroll);
    // Initialize filtered list
    filteredInvitees = List.from(invitees);
  }

  // Fetch templates from the API
  Future<void> _fetchTemplates() async {
    setState(() => _isLoadingTemplates = true);

    try {
      final response = await ApiService.fetchTemplates(widget.eventId);

      setState(() {
        if (response['data'] != null) {
          final template = response['data'];

          // Create template objects for WhatsApp, SMS, and Download Card
          // All are stored in the same template object with different fields
          if (template['whatsapp_message'] != null) {
            _templates['whatsapp'] = {
              'id': template['id'],
              'type': 'whatsapp',
              'whatsapp_message': template['whatsapp_message'],
              'event_id': template['event_id']
            };
          }

          if (template['message'] != null) {
            _templates['sms'] = {
              'id': template['id'],
              'type': 'sms',
              'message': template['message'],
              'event_id': template['event_id']
            };
          }

          if (template['download_card_message'] != null) {
            _templates['download_card'] = {
              'id': template['id'],
              'type': 'download_card',
              'download_card_message': template['download_card_message'],
              'event_id': template['event_id']
            };
          }
        }
        _isLoadingTemplates = false;
      });
    } catch (e) {
      setState(() => _isLoadingTemplates = false);
      // Silently handle error - templates will be created if they don't exist
      debugPrint('Error fetching templates: $e');
    }
  }

  // Apply filters by fetching filtered data from API
  Future<void> _applyFilters() async {
    // Reset pagination for new filter/search
    setState(() {
      currentPage = 1;
      lastPage = 1;
      filteredInvitees = [];
      isLoading = true;
    });

    await _fetchFilteredInvitees();
  }

  // Method for pull-to-refresh functionality
  Future<void> _refreshInvitees() async {
    // Reset pagination
    setState(() {
      currentPage = 1;
      lastPage = 1;

      // Clear the appropriate list based on filter status
      if (_isFilterActive || _searchQuery.isNotEmpty) {
        filteredInvitees = [];
      } else {
        invitees = [];
      }
    });

    // Use the appropriate fetch method based on filter status
    if (_isFilterActive || _searchQuery.isNotEmpty) {
      await _fetchFilteredInvitees();
    } else {
      await fetchInvitees();
    }
  }

  Future<void> _fetchFilteredInvitees() async {
    if (isLoading && currentPage > 1) return; // Prevent multiple concurrent requests while paginating
    if (currentPage > lastPage && currentPage > 1) return; // Don't fetch if we're past the last page

    setState(() => isLoading = true);

    try {
      final response = await ApiService.fetchFilteredInviteesPaginated(
        eventId: widget.eventId,
        page: currentPage,
        searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
        whatsappStatus: _filterWhatsappStatus,
        invitationSent: _filterInvitationSent,
        attendanceStatus: _filterAttendanceStatus,
        cardRedeemed: _filterCardRedeemed,
        seenStatus: _filterSeenStatus,
      );

      setState(() {
        // If this is the first page, replace the list
        // Otherwise, append to the existing list
        if (currentPage == 1) {
          filteredInvitees = List.from(response['data']);
        } else {
          filteredInvitees.addAll(response['data']);
        }

        // Store the total count from the API response
        totalFilteredInvitees = response['total'] ?? 0;

        lastPage = response['last_page'];
        currentPage++;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch invitees: $e')),
      );
    }
  }

  Future<void> fetchInvitees() async {
    // If we have active filters or search, use the filtered fetch method
    if (_isFilterActive || _searchQuery.isNotEmpty) {
      await _fetchFilteredInvitees();
      return;
    }

    // Otherwise, fetch all invitees without filtering
    if (isLoading || currentPage > lastPage) return;

    setState(() => isLoading = true);

    try {
      final response = await ApiService.fetchInviteesPaginated(
        eventId: widget.eventId,
        page: currentPage,
      );

      setState(() {
        invitees.addAll(response['data']);
        lastPage = response['last_page'];
        currentPage++;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch invitees: $e')),
      );
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      // Use the appropriate fetch method based on whether filters or search are active
      if (_isFilterActive || _searchQuery.isNotEmpty) {
        _fetchFilteredInvitees();
      } else {
        fetchInvitees();
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchDebounceTimer?.cancel();
    super.dispose();
  }

  Widget _buildInviteeCard(Map invitee) {
    final inviteeId = invitee['id'];
    final isSelected = selectedInviteeIds.contains(inviteeId);
    final isRemoving = invitee['_isRemoving'] == true;

    return AnimatedOpacity(
      opacity: isRemoving ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 500),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        child: isRemoving 
          ? Container(height: 0) 
          : GestureDetector(
          onLongPress: () {
            setState(() {
              isBulkMode = true;
              selectedInviteeIds.add(inviteeId);
            });
          },
          onTap: () {
            if (isBulkMode) {
              setState(() {
                if (selectedInviteeIds.contains(inviteeId)) {
                  selectedInviteeIds.remove(inviteeId);
                  if (selectedInviteeIds.isEmpty) isBulkMode = false;
                } else {
                  selectedInviteeIds.add(inviteeId);
                }
              });
            }
          },
          child: Card(
            color: isSelected ? accentColor.withOpacity(0.2) : null,
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            elevation: Theme.of(context).cardTheme.elevation,
            shape: Theme.of(context).cardTheme.shape,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (isBulkMode)
                        Icon(
                          isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                          color: isSelected ? accentColor : Colors.grey,
                        ),
                      if (isBulkMode) const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          invitee['name'],
                          style: Theme.of(context).textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      if (!isBulkMode)
                        PopupMenuButton<String>(
                          onSelected: (value) => _handleAction(value, invitee),
                          icon: Icon(Icons.more_vert, color: accentColor),
                          itemBuilder: (context) {
                            final isOnWhatsapp = invitee['is_on_whatsapp'] == 1 || invitee['is_on_whatsapp'] == true;
                            final isSeen = invitee['is_seen'] == 1 || invitee['is_seen'] == true;
                            return [
                              const PopupMenuItem(value: 'send', child: Text('Send Invitation')),
                              const PopupMenuItem(value: 'render_sms', child: Text('Render SMS')),
                              const PopupMenuItem(value: 'call', child: Text('Call')),
                              if (isOnWhatsapp)
                                const PopupMenuItem(value: 'mark_whatsapp_sent', child: Text('Mark WhatsApp Sent')),
                              if (!isSeen)
                                const PopupMenuItem(value: 'mark_seen', child: Text('Mark as Seen')),
                              const PopupMenuItem(value: 'send_download_card', child: Text('Send Download Card Msg')),
                              const PopupMenuItem(value: 'preview', child: Text('Preview Card')),
                              const PopupMenuItem(value: 'edit', child: Text('Edit')),
                              const PopupMenuItem(value: 'delete', child: Text('Delete')),
                            ];
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _makePhoneCall(invitee),
                          child: Text(
                            'Phone: ${invitee['phone_number']}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.blue,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      if (invitee['is_on_whatsapp'] == 1 || invitee['is_on_whatsapp'] == true)
                        const FaIcon(
                          FontAwesomeIcons.whatsapp,
                          color: Colors.green,
                          size: 16,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Guests: ${invitee['number_of_invitees']}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.black54,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      _buildDeliveryIndicator(invitee),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Show attendance status if it's attending or not attending
                  if (invitee['attendance_status'] == 'attending' || invitee['attendance_status'] == 'not_attending')
                    Row(
                      children: [
                        Icon(
                          invitee['attendance_status'] == 'attending' 
                              ? Icons.check_circle 
                              : Icons.cancel,
                          size: 16,
                          color: invitee['attendance_status'] == 'attending' 
                              ? Colors.green 
                              : Colors.red,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          invitee['attendance_status'] == 'attending' 
                              ? 'Attending' 
                              : 'Not Attending',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: invitee['attendance_status'] == 'attending' 
                                ? Colors.green 
                                : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }



  void _handleAction(String action, Map invitee) {
    switch (action) {
      case 'send':
        _sendInvitation(invitee);
        break;
      case 'render_sms':
        _renderSmsMessage(invitee);
        break;
      case 'call':
        _makePhoneCall(invitee);
        break;
      case 'mark_whatsapp_sent':
        _markWhatsappInvitationSent(invitee);
        break;
      case 'mark_seen':
        _markInviteeSeen(invitee);
        break;
      case 'send_download_card':
        _sendDownloadCardMessage(invitee);
        break;
      case 'preview':
        _showPreviewDialog(invitee);
        break;
      case 'edit':
        _showEditInviteeDialog(invitee);
        break;
      case 'delete':
        _confirmDelete(invitee);
        break;
    }
  }

  Future<void> _markWhatsappInvitationSent(Map invitee) async {
    final name = invitee['name'];
    final inviteeId = invitee['id'];

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Marking WhatsApp invitation as sent for $name...')),
    );

    try {
      final result = await ApiService.markWhatsappInvitationSent(
        eventId: widget.eventId,
        inviteeId: inviteeId,
      );

      // Refresh the invitee data
      setState(() {
        // Find the invitee in the lists and update it
        // Update the invitee in both lists
        for (int i = 0; i < invitees.length; i++) {
          if (invitees[i]['id'] == inviteeId) {
            // Create a new map with the updated value
            Map<String, dynamic> updatedInvitee = Map<String, dynamic>.from(invitees[i]);
            updatedInvitee['invitation_sent'] = true;
            invitees[i] = updatedInvitee;
            break;
          }
        }

        for (int i = 0; i < filteredInvitees.length; i++) {
          if (filteredInvitees[i]['id'] == inviteeId) {
            // Create a new map with the updated value
            Map<String, dynamic> updatedInvitee = Map<String, dynamic>.from(filteredInvitees[i]);
            updatedInvitee['invitation_sent'] = true;
            filteredInvitees[i] = updatedInvitee;
            break;
          }
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('WhatsApp invitation marked as sent for $name')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to mark WhatsApp invitation as sent for $name: $e')),
      );
    }
  }

  Future<void> _makePhoneCall(Map invitee) async {
    final phoneNumber = invitee['phone_number'];
    final name = invitee['name'];

    if (phoneNumber == null || phoneNumber.toString().trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number is not available')),
      );
      return;
    }

    final Uri phoneUri = Uri(
      scheme: 'tel',
      path: phoneNumber.toString(),
    );

    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);

        // Show dialog after call
        if (context.mounted) {
          _showCallFollowUpDialog(invitee);
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not launch phone app')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error making phone call: $e')),
        );
      }
    }
  }

  void _showCallFollowUpDialog(Map invitee) {
    final name = invitee['name'];
    bool isMarkingAsSeen = false;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Call Follow-up'),
              content: Text('Has $name seen the invitation?'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: Text('No'),
                ),
                ElevatedButton(
                  onPressed: isMarkingAsSeen 
                    ? null 
                    : () async {
                        setState(() {
                          isMarkingAsSeen = true;
                        });

                        await _markInviteeSeen(invitee);

                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }
                      },
                  child: isMarkingAsSeen
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text('Yes'),
                        ],
                      )
                    : Text('Yes'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  Future<void> _markInviteeSeen(Map invitee) async {
    final name = invitee['name'];
    final inviteeId = invitee['id'];

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Marking invitation as seen for $name...')),
    );

    try {
      final result = await ApiService.markInviteeSeen(
        eventId: widget.eventId,
        inviteeId: inviteeId,
      );

      // Refresh the invitee data
      setState(() {
        // Find the invitee in the lists and update it
        // Update the invitee in both lists
        for (int i = 0; i < invitees.length; i++) {
          if (invitees[i]['id'] == inviteeId) {
            // Create a new map with the updated value
            Map<String, dynamic> updatedInvitee = Map<String, dynamic>.from(invitees[i]);
            updatedInvitee['is_seen'] = true;
            invitees[i] = updatedInvitee;
            break;
          }
        }

        for (int i = 0; i < filteredInvitees.length; i++) {
          if (filteredInvitees[i]['id'] == inviteeId) {
            // Create a new map with the updated value
            Map<String, dynamic> updatedInvitee = Map<String, dynamic>.from(filteredInvitees[i]);
            updatedInvitee['is_seen'] = true;
            filteredInvitees[i] = updatedInvitee;
            break;
          }
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invitation marked as seen for $name')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to mark invitation as seen for $name: $e')),
      );
    }
  }

  Future<void> _sendDownloadCardMessage(Map invitee) async {
    final name = invitee['name'];
    final inviteeId = invitee['id'];

    // Check if download card template exists
    if (_templates['download_card'] == null || _templates['download_card']['download_card_message'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No download card message template found. Please create one first.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sending download card message to $name...')),
    );

    try {
      final result = await ApiService.sendDownloadCardMessage(
        eventId: widget.eventId,
        inviteeId: inviteeId,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download card message sent to $name successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send download card message to $name: $e')),
      );
    }
  }

  Future<void> _sendInvitation(Map invitee) async {
    final name = invitee['name'];
    final inviteeId = invitee['id'];

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sending invitation to $name...')),
    );

    try {
      await ApiService.sendInvitation(inviteeId: inviteeId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invitation sent to $name successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send invitation to $name: $e')),
      );
    }
  }

  void _renderSmsMessage(Map invitee) {
    // Check if SMS template exists
    if (_templates['sms'] == null || _templates['sms']['message'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No SMS template found. Please create one first.')),
      );
      return;
    }

    final String template = _templates['sms']['message'];
    final String name = invitee['name'] ?? '';
    final String code = invitee['invitation_code'] ?? '';
    final String phoneNumber = invitee['phone_number'] ?? '';
    final int numberOfInvitees = invitee['number_of_invitees'] ?? 1;

    // Determine type based on number of invitees
    String type = 'Single';
    if (numberOfInvitees == 2) {
      type = 'Double';
    } else if (numberOfInvitees > 2) {
      type = 'Triple';
    }

    // Replace placeholders with actual values
    String renderedMessage = template
      .replaceAll('{name}', name)
      .replaceAll('{code}', code)
      .replaceAll('{invitation_code}', code) // Alternative placeholder
      .replaceAll('{type}', type)
      .replaceAll('{link}', 'https://events.ajiriwa.net/invitation/$code');

    // Show modal with rendered message
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rendered SMS Message'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Preview of the SMS message with placeholders replaced:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  renderedMessage,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 16),
              if (phoneNumber.isNotEmpty)
                Text(
                  'This message will be sent to: $phoneNumber',
                  style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          if (phoneNumber.isNotEmpty)
            ElevatedButton.icon(
              icon: const Icon(Icons.sms),
              label: const Text('Send Message'),
              onPressed: () async {
                final Uri smsUri = Uri(
                  scheme: 'sms',
                  path: phoneNumber,
                  queryParameters: {'body': renderedMessage},
                );

                if (await canLaunchUrl(smsUri)) {
                  await launchUrl(smsUri);
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not launch messaging app')),
                    );
                  }
                }

                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
            ),
        ],
      ),
    );
  }



  Widget _actionButton(IconData icon, String label, VoidCallback onTap, {bool isActive = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Stack(
            alignment: Alignment.topRight,
            children: [
              Icon(icon, color: isActive ? Colors.green : accentColor, size: 20),
              if (isActive)
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isActive ? Colors.green : accentColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Show template options dropdown
  void _showTemplateOptions() {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select Template Type'),
        children: [
          ListTile(
            leading: Icon(Icons.message, color: Colors.green),
            title: const Text('WhatsApp Template'),
            onTap: () {
              Navigator.pop(context);
              _showTemplateEditor('whatsapp');
            },
          ),
          ListTile(
            leading: Icon(Icons.sms, color: Colors.blue),
            title: const Text('SMS Template'),
            onTap: () {
              Navigator.pop(context);
              _showTemplateEditor('sms');
            },
          ),
          ListTile(
            leading: Icon(Icons.credit_card, color: Colors.orange),
            title: const Text('Card Download Message'),
            onTap: () {
              Navigator.pop(context);
              _showTemplateEditor('download_card');
            },
          ),
        ],
      ),
    );
  }

  // Show template editor dialog
  void _showTemplateEditor(String templateType) {
    final templateController = TextEditingController();
    final existingTemplate = _templates[templateType];

    // Pre-populate with existing template if available
    if (existingTemplate != null) {
      if (templateType == 'whatsapp' && existingTemplate['whatsapp_message'] != null) {
        templateController.text = existingTemplate['whatsapp_message'];
      } else if (templateType == 'sms' && existingTemplate['message'] != null) {
        templateController.text = existingTemplate['message'];
      } else if (templateType == 'download_card' && existingTemplate['download_card_message'] != null) {
        templateController.text = existingTemplate['download_card_message'];
      }
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          bool isSaving = false;

          return AlertDialog(
            title: Text(
              templateType == 'whatsapp' 
                ? 'WhatsApp Template' 
                : templateType == 'sms' 
                  ? 'SMS Template' 
                  : 'Card Download Message'
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter your message template. You can use the following placeholders:',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _placeholderChip('{name}', templateController),
                      _placeholderChip('{code}', templateController),
                      _placeholderChip('{link}', templateController),
                      _placeholderChip('{type}', templateController),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: templateController,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Enter your message template here...',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSaving 
                  ? null 
                  : () async {
                    setDialogState(() => isSaving = true);

                    try {
                      final content = templateController.text.trim();

                      if (content.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Template cannot be empty')),
                        );
                        setDialogState(() => isSaving = false);
                        return;
                      }

                      Map<String, dynamic> result;

                      if (existingTemplate != null) {
                        // Update existing template
                        result = await ApiService.updateTemplate(
                          templateId: existingTemplate['id'],
                          content: content,
                          type: templateType,
                        );
                      } else {
                        // Create new template
                        result = await ApiService.saveTemplate(
                          eventId: widget.eventId,
                          type: templateType,
                          content: content,
                        );
                      }

                      setState(() {
                        // Create template object with the correct structure
                        _templates[templateType] = {
                          'id': result['data']['id'],
                          'type': templateType,
                          'event_id': result['data']['event_id'],
                        };

                        // Add the appropriate message field based on template type
                        if (templateType == 'whatsapp') {
                          _templates[templateType]['whatsapp_message'] = content;
                        } else if (templateType == 'sms') {
                          _templates[templateType]['message'] = content;
                        } else if (templateType == 'download_card') {
                          _templates[templateType]['download_card_message'] = content;
                        }
                      });

                      Navigator.pop(context);

                      String templateName = templateType == 'whatsapp' 
                          ? 'WhatsApp' 
                          : templateType == 'sms' 
                              ? 'SMS' 
                              : 'Card Download Message';

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$templateName template saved successfully')),
                      );
                    } catch (e) {
                      setDialogState(() => isSaving = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error saving template: $e')),
                      );
                    }
                  },
                child: isSaving 
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('Saving...'),
                      ],
                    )
                  : const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  // Helper method to create placeholder chips
  Widget _placeholderChip(String placeholder, TextEditingController controller) {
    return ActionChip(
      label: Text(placeholder),
      onPressed: () {
        // Insert placeholder at current cursor position
        final text = controller.text;
        final selection = controller.selection;
        final newText = text.replaceRange(selection.start, selection.end, placeholder);
        controller.text = newText;
        controller.selection = TextSelection.collapsed(
          offset: selection.start + placeholder.length,
        );
      },
    );
  }

  // Show filter dialog
  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Filter Invitees'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('WhatsApp Status', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('All'),
                        selected: _filterWhatsappStatus == null,
                        onSelected: (selected) {
                          if (selected) {
                            setDialogState(() => _filterWhatsappStatus = null);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Has WhatsApp'),
                        selected: _filterWhatsappStatus == true,
                        onSelected: (selected) {
                          if (selected) {
                            setDialogState(() => _filterWhatsappStatus = true);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('No WhatsApp'),
                        selected: _filterWhatsappStatus == false,
                        onSelected: (selected) {
                          if (selected) {
                            setDialogState(() => _filterWhatsappStatus = false);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Invitation Status', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('All'),
                        selected: _filterInvitationSent == null,
                        onSelected: (selected) {
                          if (selected) {
                            setDialogState(() => _filterInvitationSent = null);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Sent'),
                        selected: _filterInvitationSent == true,
                        onSelected: (selected) {
                          if (selected) {
                            setDialogState(() => _filterInvitationSent = true);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Not Sent'),
                        selected: _filterInvitationSent == false,
                        onSelected: (selected) {
                          if (selected) {
                            setDialogState(() => _filterInvitationSent = false);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Attendance Status', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('All'),
                        selected: _filterAttendanceStatus == null,
                        onSelected: (selected) {
                          if (selected) {
                            setDialogState(() => _filterAttendanceStatus = null);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Attending'),
                        selected: _filterAttendanceStatus == 'attending',
                        onSelected: (selected) {
                          if (selected) {
                            setDialogState(() => _filterAttendanceStatus = 'attending');
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Not Attending'),
                        selected: _filterAttendanceStatus == 'not_attending',
                        onSelected: (selected) {
                          if (selected) {
                            setDialogState(() => _filterAttendanceStatus = 'not_attending');
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Pending'),
                        selected: _filterAttendanceStatus == 'pending',
                        onSelected: (selected) {
                          if (selected) {
                            setDialogState(() => _filterAttendanceStatus = 'pending');
                          }
                        },
                      ),
                    ),
                    const Expanded(child: SizedBox()),
                    const Expanded(child: SizedBox()),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Card Redemption Status', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('All'),
                        selected: _filterCardRedeemed == null,
                        onSelected: (selected) {
                          if (selected) {
                            setDialogState(() => _filterCardRedeemed = null);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Redeemed'),
                        selected: _filterCardRedeemed == true,
                        onSelected: (selected) {
                          if (selected) {
                            setDialogState(() => _filterCardRedeemed = true);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Not Redeemed'),
                        selected: _filterCardRedeemed == false,
                        onSelected: (selected) {
                          if (selected) {
                            setDialogState(() => _filterCardRedeemed = false);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Seen Status', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('All'),
                        selected: _filterSeenStatus == null,
                        onSelected: (selected) {
                          if (selected) {
                            setDialogState(() => _filterSeenStatus = null);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Seen'),
                        selected: _filterSeenStatus == true,
                        onSelected: (selected) {
                          if (selected) {
                            setDialogState(() => _filterSeenStatus = true);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Not Seen'),
                        selected: _filterSeenStatus == false,
                        onSelected: (selected) {
                          if (selected) {
                            setDialogState(() => _filterSeenStatus = false);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  // Cancel any pending search timer
                  _searchDebounceTimer?.cancel();

                  setState(() {
                    _isFilterActive = _filterWhatsappStatus != null || _filterInvitationSent != null || _filterAttendanceStatus != null || _filterCardRedeemed != null || _filterSeenStatus != null;
                  });
                  _applyFilters();
                  Navigator.pop(context);
                },
                child: const Text('Apply'),
              ),
              if (_isFilterActive)
                TextButton(
                  onPressed: () {
                    setDialogState(() {
                      _filterWhatsappStatus = null;
                      _filterInvitationSent = null;
                      _filterAttendanceStatus = null;
                      _filterCardRedeemed = null;
                      _filterSeenStatus = null;
                    });
                    // Cancel any pending search timer
                    _searchDebounceTimer?.cancel();

                    setState(() {
                      _isFilterActive = false;
                    });
                    _applyFilters();
                    Navigator.pop(context);
                  },
                  child: const Text('Clear All'),
                ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: isBulkMode
            ? Text('${selectedInviteeIds.length} selected')
            : const Text('Manage Invitees'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        actions: isBulkMode
            ? [
                PopupMenuButton<String>(
                  onSelected: _handleBulkAction,
                  icon: const Icon(Icons.more_vert),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'send', child: Text('Send Invitations')),
                    const PopupMenuItem(value: 'send_download_card', child: Text('Send Download Card Msg')),
                    const PopupMenuItem(value: 'mark_seen', child: Text('Mark as Seen')),
                    const PopupMenuItem(value: 'preview', child: Text('Preview Cards')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      isBulkMode = false;
                      selectedInviteeIds.clear();
                    });
                  },
                ),
              ]
            : null,
      ),

      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                InviteeActionsToolbar(
                  isFilterActive: _isFilterActive,
                  onAddInvitee: _showAddInviteeDialog,
                  onImportExcel: _importFromExcel,
                  onFilter: _showFilterDialog,
                  onManageTemplates: _showTemplateOptions,
                ),

                // Show active filters if any
                if (_isFilterActive)
                  InviteeFilterBar(
                    totalCount: totalFilteredInvitees,
                    filterWhatsappStatus: _filterWhatsappStatus,
                    filterInvitationSent: _filterInvitationSent,
                    filterAttendanceStatus: _filterAttendanceStatus,
                    filterCardRedeemed: _filterCardRedeemed,
                    filterSeenStatus: _filterSeenStatus,
                    onClearWhatsapp: () {
                      _searchDebounceTimer?.cancel();
                      setState(() {
                        _filterWhatsappStatus = null;
                        _isFilterActive = _filterInvitationSent != null || _filterAttendanceStatus != null || _filterCardRedeemed != null || _filterSeenStatus != null;
                      });
                      _applyFilters();
                    },
                    onClearInvitationSent: () {
                      _searchDebounceTimer?.cancel();
                      setState(() {
                        _filterInvitationSent = null;
                        _isFilterActive = _filterWhatsappStatus != null || _filterAttendanceStatus != null || _filterCardRedeemed != null || _filterSeenStatus != null;
                      });
                      _applyFilters();
                    },
                    onClearAttendance: () {
                      _searchDebounceTimer?.cancel();
                      setState(() {
                        _filterAttendanceStatus = null;
                        _isFilterActive = _filterWhatsappStatus != null || _filterInvitationSent != null || _filterCardRedeemed != null || _filterSeenStatus != null;
                      });
                      _applyFilters();
                    },
                    onClearRedeemed: () {
                      _searchDebounceTimer?.cancel();
                      setState(() {
                        _filterCardRedeemed = null;
                        _isFilterActive = _filterWhatsappStatus != null || _filterInvitationSent != null || _filterAttendanceStatus != null || _filterSeenStatus != null;
                      });
                      _applyFilters();
                    },
                    onClearSeen: () {
                      _searchDebounceTimer?.cancel();
                      setState(() {
                        _filterSeenStatus = null;
                        _isFilterActive = _filterWhatsappStatus != null || _filterInvitationSent != null || _filterAttendanceStatus != null || _filterCardRedeemed != null;
                      });
                      _applyFilters();
                    },
                    onClearAll: () {
                      _searchDebounceTimer?.cancel();
                      setState(() {
                        _filterWhatsappStatus = null;
                        _filterInvitationSent = null;
                        _filterAttendanceStatus = null;
                        _filterCardRedeemed = null;
                        _filterSeenStatus = null;
                        _isFilterActive = false;
                      });
                      _applyFilters();
                    },
                  ),
              ],
            ),
          ),

          // Search input field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        // Cancel any pending search timer
                        _searchDebounceTimer?.cancel();

                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });

                        // Apply filters immediately when clearing search
                        _applyFilters(); // Reset search and apply filters
                      },
                    )
                  : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide(color: Theme.of(context).primaryColor),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 12.0),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });

                // Cancel any previous timer
                _searchDebounceTimer?.cancel();

                // Set a new timer to delay the API call
                _searchDebounceTimer = Timer(const Duration(milliseconds: 500), () {
                  _applyFilters(); // This will apply both filters and search
                });
              },
            ),
          ),
          Expanded(
            child: (_isFilterActive || _searchQuery.isNotEmpty ? filteredInvitees : invitees).isEmpty && !isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isFilterActive 
                              ? 'No invitees match the current filters'
                              : 'No invitees found',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Colors.grey[700],
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isFilterActive
                              ? 'Try changing or clearing your filters'
                              : 'Click the button below to add a new invitee',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[600],
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        if (_isFilterActive)
                          ElevatedButton.icon(
                            onPressed: () {
                              // Cancel any pending search timer
                              _searchDebounceTimer?.cancel();

                              setState(() {
                                _filterWhatsappStatus = null;
                                _filterInvitationSent = null;
                                _filterAttendanceStatus = null;
                                _filterCardRedeemed = null;
                                _filterSeenStatus = null;
                                _isFilterActive = false;
                              });
                              _applyFilters();
                            },
                            icon: const Icon(Icons.filter_list_off),
                            label: const Text('Clear Filters'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          )
                        else
                          ElevatedButton.icon(
                            onPressed: _showAddInviteeDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Invitee'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _refreshInvitees,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      controller: _scrollController,
                      itemCount: (_isFilterActive || _searchQuery.isNotEmpty ? filteredInvitees : invitees).length + (isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        final displayList = _isFilterActive || _searchQuery.isNotEmpty ? filteredInvitees : invitees;
                        if (index < displayList.length) {
                          final inv = displayList[index];
                          final invId = inv['id'];
                          return InviteeCard(
                            invitee: inv,
                            isBulkMode: isBulkMode,
                            isSelected: selectedInviteeIds.contains(invId),
                            onLongPress: () => setState(() {
                              isBulkMode = true;
                              selectedInviteeIds.add(invId);
                            }),
                            onTap: () {
                              if (isBulkMode) {
                                setState(() {
                                  if (selectedInviteeIds.contains(invId)) {
                                    selectedInviteeIds.remove(invId);
                                    if (selectedInviteeIds.isEmpty) isBulkMode = false;
                                  } else {
                                    selectedInviteeIds.add(invId);
                                  }
                                });
                              }
                            },
                            onAction: _handleAction,
                            onPhoneCall: _makePhoneCall,
                          );
                        }
                        return const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _handleBulkAction(String action) async {
    final List<Map<String, dynamic>> selectedInvitees = invitees
        .where((invitee) => selectedInviteeIds.contains(invitee['id']))
        .cast<Map<String, dynamic>>()
        .toList();

    switch (action) {
      case 'send':
        // Show loading indicator
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sending invitations to ${selectedInvitees.length} invitees...')),
        );

        try {
          // Extract invitee IDs
          final List<int> inviteeIds = selectedInvitees
              .map<int>((invitee) => invitee['id'] as int)
              .toList();

          // Call the API to send bulk invitations
          await ApiService.bulkSendInvitations(
            eventId: widget.eventId,
            inviteeIds: inviteeIds,
          );

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Successfully sent invitations to ${selectedInvitees.length} invitees')),
          );
        } catch (e) {
          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to send invitations: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        break;
      case 'preview':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Previewing ${selectedInvitees.length} cards')),
        );
        break;
      case 'delete':
        _confirmBulkDelete(selectedInvitees);
        break;
      case 'send_download_card':
        // Check if download card template exists
        if (_templates['download_card'] == null || _templates['download_card']['download_card_message'] == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No download card message template found. Please create one first.')),
          );
          return;
        }

        // Show loading indicator
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sending download card messages to ${selectedInvitees.length} invitees...')),
        );

        try {
          // Extract invitee IDs
          final List<int> inviteeIds = selectedInvitees
              .map<int>((invitee) => invitee['id'] as int)
              .toList();

          // Call the API to send bulk download card messages
          final result = await ApiService.sendBulkDownloadCardMessages(
            eventId: widget.eventId,
            inviteeIds: inviteeIds,
          );

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Successfully sent download card messages to ${result['success_count']} invitees')),
          );
        } catch (e) {
          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to send download card messages: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        break;
      case 'mark_seen':
        // Show loading indicator
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Marking ${selectedInvitees.length} invitees as seen...')),
        );

        try {
          // Extract invitee IDs
          final List<int> inviteeIds = selectedInvitees
              .map<int>((invitee) => invitee['id'] as int)
              .toList();

          // Call the API to mark invitees as seen in bulk
          final result = await ApiService.markBulkInviteesSeen(
            eventId: widget.eventId,
            inviteeIds: inviteeIds,
          );

          // Update the invitees in the lists
          setState(() {
            // Update the invitees in both lists
            for (final invitee in invitees) {
              if (inviteeIds.contains(invitee['id'])) {
                invitee['is_seen'] = true;
              }
            }

            for (final invitee in filteredInvitees) {
              if (inviteeIds.contains(invitee['id'])) {
                invitee['is_seen'] = true;
              }
            }
          });

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Successfully marked ${result['updated_count']} invitees as seen')),
          );
        } catch (e) {
          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to mark invitees as seen: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        break;
    }

    // Clear after action
    setState(() {
      isBulkMode = false;
      selectedInviteeIds.clear();
    });
  }

  void _confirmBulkDelete(List<Map> selectedInvitees) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Invitees'),
        content: Text('Are you sure you want to delete ${selectedInvitees.length} invitees?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                invitees.removeWhere((invitee) =>
                    selectedInvitees.any((selected) => selected['id'] == invitee['id']));
                isBulkMode = false;
                selectedInviteeIds.clear();
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Invitees deleted successfully')),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }


  void _showAddInviteeDialog() {
    showDialog(
      context: context,
      barrierDismissible: !_isSubmitting,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Add Invitee'),
              content: Stack(
                children: [
                  Opacity(
                    opacity: _isSubmitting ? 0.5 : 1,
                    child: AbsorbPointer(
                      absorbing: _isSubmitting,
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              controller: _nameController,
                              decoration: const InputDecoration(labelText: 'Name'),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _phoneController,
                              decoration: const InputDecoration(labelText: 'Phone Number'),
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _numberController,
                              decoration: const InputDecoration(labelText: 'Number of Invitees'),
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Text('On WhatsApp?'),
                                const Spacer(),
                                DropdownButton<bool?>(
                                  value: _isOnWhatsapp,
                                  items: const [
                                    DropdownMenuItem(value: null, child: Text('Auto-detect')),
                                    DropdownMenuItem(value: true, child: Text('Yes')),
                                    DropdownMenuItem(value: false, child: Text('No')),
                                  ],
                                  onChanged: (value) {
                                    setModalState(() {
                                      _isOnWhatsapp = value;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_isSubmitting)
                    const Positioned.fill(
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: _isSubmitting
                      ? null
                      : () {
                    _clearInviteeForm();
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => _submitInvitee(setModalState),
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }


  Future<void> _submitInvitee(Function setModalState) async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final numberText = _numberController.text.trim();

    if (name.isEmpty || phone.isEmpty || numberText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    final numberOfInvitees = int.tryParse(numberText);
    if (numberOfInvitees == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Number of invitees must be an integer')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final newInvitee = await ApiService.addInvitee(
        eventId: widget.eventId,
        name: name,
        phoneNumber: phone,
        numberOfInvitees: numberOfInvitees,
        isOnWhatsapp: _isOnWhatsapp,
      );

      setState(() {
        invitees.insert(0, newInvitee);
      });

      Navigator.pop(context);
      _clearInviteeForm();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invitee "${newInvitee['name']}" added successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add invitee: ${e.toString()}')),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }


  void _clearInviteeForm() {
    _nameController.clear();
    _phoneController.clear();
    _numberController.clear();
    _isOnWhatsapp = null;
  }

  /// Parses a "Yes/No/1/0/true/false" cell into a definite bool, or null
  /// (auto-detect) for blank or unrecognized text — never silently "No".
  bool? _parseOnWhatsapp(String? raw) {
    final value = raw?.trim().toLowerCase();
    if (value == null || value.isEmpty) return null;
    if (value == 'yes' || value == '1' || value == 'true') return true;
    if (value == 'no' || value == '0' || value == 'false') return false;
    return null;
  }

  String _waLabel(dynamic value) {
    if (value == null) return 'Auto-detect';
    return value == true ? 'Yes' : 'No';
  }

  /// WhatsApp-style delivery status for an invitee's card: 'read' (blue
  /// double tick), 'delivered' (grey double tick), 'sent' (grey single
  /// tick), or null (no WhatsApp send on record).
  String? _waTickStatus(Map invitee) {
    final invitations = (invitee['invitations'] as List?) ?? [];
    final waInvitations = invitations
        .cast<Map>()
        .where((i) => i['comm_type'] == 'whatsapp')
        .toList()
      ..sort((a, b) =>
          (b['created_at']?.toString() ?? '').compareTo(a['created_at']?.toString() ?? ''));

    if (waInvitations.isEmpty) return null;
    final latest = waInvitations.first;

    if (latest['read_at'] != null) return 'read';
    if (latest['delivered_at'] != null) return 'delivered';
    if (latest['whatsapp_message_id'] != null) return 'sent';
    return null;
  }

  Widget _buildDeliveryIndicator(Map invitee) {
    final status = _waTickStatus(invitee);
    if (status == null) return const SizedBox.shrink();

    final label = {'sent': 'Sent', 'delivered': 'Delivered', 'read': 'Read'}[status]!;
    final color = status == 'read' ? Colors.blue : Colors.grey;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(status == 'sent' ? Icons.done : Icons.done_all, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }

  // Generate and save a sample file (CSV or Excel)
  Future<void> _downloadSampleFile({bool asExcel = false}) async {
    try {
      // Saved into the app's own documents directory, which is app-private
      // sandboxed storage — no runtime permission is needed to write there.

      // Get download directory
      final directory = await getApplicationDocumentsDirectory();
      final fileType = asExcel ? 'Excel' : 'CSV';
      final extension = asExcel ? 'xlsx' : 'csv';

      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Generating sample $fileType file...')),
      );

      final fileName = 'invitees_sample_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final filePath = '${directory.path}/$fileName';

      if (asExcel) {
        // Create Excel file
        final excel = Excel.createExcel();
        final sheet = excel.sheets.values.first;

        // Add header row
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value = 'Name';
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0)).value = 'Phone Number';
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 0)).value = 'Number of Invitees';
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 0)).value = 'Is on WhatsApp';

        // Add sample data
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).value = 'John Doe';
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 1)).value = '+1234567890';
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 1)).value = 2;
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 1)).value = 'Yes';

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2)).value = 'Jane Smith';
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 2)).value = '+0987654321';
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 2)).value = 1;
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 2)).value = 'No';

        // Save Excel file
        final excelBytes = excel.encode();
        if (excelBytes != null) {
          final file = File(filePath);
          await file.writeAsBytes(excelBytes);
        } else {
          throw Exception('Failed to encode Excel file');
        }
      } else {
        // Create CSV content with header and sample rows
        final csvContent = 'Name,Phone Number,Number of Invitees,Is on WhatsApp\n'
            'John Doe,+1234567890,2,Yes\n'
            'Jane Smith,+0987654321,1,No';

        // Write to file
        final file = File(filePath);
        await file.writeAsString(csvContent);
      }

      // Save to gallery or share based on platform
      if (Platform.isAndroid || Platform.isIOS) {
        // For mobile, share the file
        await Share.shareXFiles(
          [XFile(filePath)],
          text: 'Sample $fileType file for invitees',
        );
      } else {
        // For desktop, just show success message with file path
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sample $fileType saved to: $filePath')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating sample file: $e')),
      );
    }
  }

  Future<void> _importFromExcel() async {
    try {
      // Show loading indicator
      setState(() {
        isLoading = true;
      });

      // Show file selection dialog
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select File'),
          content: const Text(
            'Please select a CSV or Excel file containing invitee data.\n\n'
            'The file should have columns for:\n'
            '- Name\n'
            '- Phone Number\n'
            '- Number of Invitees\n'
            '- Is on WhatsApp (Yes/No)\n\n'
            'Both CSV (.csv) and Excel (.xlsx) files are supported.'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
                _downloadSampleFile(asExcel: false);
              },
              child: const Text('Download CSV Sample'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
                _downloadSampleFile(asExcel: true);
              },
              child: const Text('Download Excel Sample'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Select File'),
            ),
          ],
        ),
      );

      if (result != true) {
        setState(() {
          isLoading = false;
        });
        return;
      }

      // Use FilePicker instead of ImagePicker for document files
      final result2 = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx'],
      );

      if (result2 == null || result2.files.isEmpty) {
        setState(() {
          isLoading = false;
        });
        return;
      }

      // Get file path
      final file = File(result2.files.first.path!);
      final fileName = file.path.split('/').last;

      // Check file extension
      final extension = fileName.split('.').last.toLowerCase();
      if (extension != 'csv' && extension != 'xlsx') {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a CSV or Excel file'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Show parsing message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Parsing $fileName...')),
      );

      // Parse file locally
      List<Map<String, dynamic>> parsedInvitees = [];

      if (extension == 'csv') {
        // Parse CSV file
        final contents = await file.readAsString();
        final lines = contents.split('\n');

        // Skip header row if present
        bool hasHeader = true;
        int startIndex = hasHeader ? 1 : 0;

        for (int i = startIndex; i < lines.length; i++) {
          final line = lines[i].trim();
          if (line.isEmpty) continue;

          final values = line.split(',');
          if (values.length < 3) continue; // Skip invalid rows

          final name = values[0].trim();
          final phoneNumber = values[1].trim();
          final numberOfInvitees = int.tryParse(values[2].trim()) ?? 1;
          final isOnWhatsapp = values.length > 3 ? _parseOnWhatsapp(values[3]) : null;

          parsedInvitees.add({
            'name': name,
            'phone_number': phoneNumber,
            'number_of_invitees': numberOfInvitees,
            'is_on_whatsapp': isOnWhatsapp,
          });
        }
      } else if (extension == 'xlsx') {
        // Parse Excel file
        final bytes = await file.readAsBytes();
        final excel = Excel.decodeBytes(bytes);

        // Get the first sheet
        final sheet = excel.tables.keys.first;
        final rows = excel.tables[sheet]?.rows;

        if (rows != null && rows.isNotEmpty) {
          // Skip header row
          for (int i = 1; i < rows.length; i++) {
            final row = rows[i];
            if (row.isEmpty) continue;

            // No need to check row length here as we're checking individually for each cell

            // Extract values from cells
            String name = '';
            if (row.length > 0 && row[0] != null && row[0]!.value != null) {
              name = row[0]!.value.toString().trim();
            }

            String phoneNumber = '';
            if (row.length > 1 && row[1] != null && row[1]!.value != null) {
              phoneNumber = row[1]!.value.toString().trim();
            }

            int numberOfInvitees = 1;
            if (row.length > 2 && row[2] != null && row[2]!.value != null) {
              final value = row[2]!.value.toString().trim();
              numberOfInvitees = int.tryParse(value) ?? 1;
            }

            // Check for WhatsApp status in 4th column if it exists. Missing
            // or blank means auto-detect (null), not "not on WhatsApp".
            bool? isOnWhatsapp;
            if (row.length > 3 && row[3] != null && row[3]!.value != null) {
              isOnWhatsapp = _parseOnWhatsapp(row[3]!.value.toString());
            }

            // Skip empty rows
            if (name.isEmpty && phoneNumber.isEmpty) continue;

            parsedInvitees.add({
              'name': name,
              'phone_number': phoneNumber,
              'number_of_invitees': numberOfInvitees,
              'is_on_whatsapp': isOnWhatsapp,
            });
          }
        }
      }

      // Hide loading indicator
      setState(() {
        isLoading = false;
      });

      if (parsedInvitees.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No valid invitee data found in the file'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Show preview dialog with parsed data
      final confirmed = await _showInviteesPreviewDialog(parsedInvitees);

      if (confirmed != true) {
        return;
      }

      // Show loading indicator for API call
      setState(() {
        isLoading = true;
      });

      // Send parsed data to API
      int successCount = 0;
      List<String> errors = [];

      // Process invitees in batches to avoid overwhelming the API
      for (final invitee in parsedInvitees) {
        try {
          await ApiService.addInvitee(
            eventId: widget.eventId,
            name: invitee['name'],
            phoneNumber: invitee['phone_number'],
            numberOfInvitees: invitee['number_of_invitees'],
            isOnWhatsapp: invitee['is_on_whatsapp'],
          );
          successCount++;
        } catch (e) {
          errors.add('${invitee['name']} (${invitee['phone_number']}): ${e.toString()}');
        }
      }

      // Reset invitees list and fetch first page
      setState(() {
        invitees = [];
        currentPage = 1;
        isLoading = false;
      });

      await fetchInvitees();

      // Show success/error message
      if (errors.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully imported $successCount invitees')),
        );
      } else {
        // Show error dialog with details
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Import Completed with Errors'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Successfully imported: $successCount'),
                  Text('Failed: ${errors.length}'),
                  const SizedBox(height: 16),
                  if (errors.isNotEmpty) ...[
                    const Text('Errors:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...errors.take(5).map((e) => Text('• $e')),
                    if (errors.length > 5)
                      Text('... and ${errors.length - 5} more errors'),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error importing invitees: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Show preview dialog with parsed invitee data
  Future<bool?> _showInviteesPreviewDialog(List<Map<String, dynamic>> invitees) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Preview Invitees'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Found ${invitees.length} invitees in the file.'),
              const SizedBox(height: 16),
              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.5,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: invitees.length > 10 ? 10 : invitees.length,
                    itemBuilder: (context, index) {
                      final invitee = invitees[index];
                      return ListTile(
                        title: Text(invitee['name']),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Phone: ${invitee['phone_number']}'),
                            Text(
                              'Invitees: ${invitee['number_of_invitees']} | WhatsApp: ${_waLabel(invitee['is_on_whatsapp'])}',
                            ),
                          ],
                        ),
                        dense: true,
                      );
                    },
                  ),
                ),
              ),
              if (invitees.length > 10)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text('... and ${invitees.length - 10} more'),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }

  /// Renders the SMS template with the given invitee's data.
  /// Returns null if no template has been set up yet.
  String? _buildRenderedMessage(Map invitee) {
    final templateMessage = _templates['whatsapp']?['whatsapp_message'] as String?;
    if (templateMessage == null) return null;

    final String name = invitee['name'] ?? '';
    final String code = invitee['invitation_code'] ?? '';
    final int numberOfInvitees = invitee['number_of_invitees'] ?? 1;
    final String type = numberOfInvitees == 1
        ? 'Single'
        : numberOfInvitees == 2
            ? 'Double'
            : 'Triple';

    return templateMessage
        .replaceAll('{name}', name)
        .replaceAll('{code}', code)
        .replaceAll('{invitation_code}', code)
        .replaceAll('{type}', type)
        .replaceAll('{link}', 'https://events.ajiriwa.net/invitation/$code');
  }

  void _showPreviewDialog(Map invitee) {
    final String slug = invitee['slug'] ?? '';
    debugPrint(slug);
    final url = 'https://events.ajiriwa.net/invitation-card/image/$slug';
    final String shareCaption =
        _buildRenderedMessage(invitee) ?? 'Check out this invitation!';
    final String phone = invitee['phone_number'] ?? '';
    final bool isOnWhatsapp =
        invitee['is_on_whatsapp'] == 1 || invitee['is_on_whatsapp'] == true;

    showDialog(
      context: context,
      builder: (context) {
        bool isLoading = true;

        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              insetPadding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Top app-bar ────────────────────────────────────────────
                  AppBar(
                    title: const Text('Invitation Preview'),
                    automaticallyImplyLeading: false,
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.download),
                        tooltip: 'Download',
                        onPressed: isLoading ? null : () => _downloadImage(url),
                      ),
                      IconButton(
                        icon: const Icon(Icons.share),
                        tooltip: 'Share',
                        onPressed: isLoading
                            ? null
                            : () => _shareImage(url, caption: shareCaption),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),

                  // ── Card image ─────────────────────────────────────────────
                  Flexible(
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) {
                          if (isLoading) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              setState(() => isLoading = false);
                            });
                          }
                          return InteractiveViewer(child: child);
                        }
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        if (isLoading) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            setState(() => isLoading = false);
                          });
                        }
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text('Failed to load image.'),
                          ),
                        );
                      },
                    ),
                  ),

                  // ── WhatsApp direct-send button (only if on WhatsApp) ──────
                  if (isOnWhatsapp)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: isLoading
                              ? null
                              : () {
                                  Navigator.pop(context);
                                  _shareImageToWhatsApp(url, phone, shareCaption);
                                },
                          icon: const FaIcon(
                            FontAwesomeIcons.whatsapp,
                            size: 20,
                          ),
                          label: const Text('Send via WhatsApp'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Helper method to show a dialog guiding users to app settings
  Future<bool> _showPermissionSettingsDialog(String title, String message) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 16),
            const Text(
              'You can enable permissions in:\nSettings > Apps > AJ Events > Permissions',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _downloadImage(String url) async {
    try {
      // Request storage/photos permission based on platform
      final permissionStatus = await _requestStoragePermission();
      if (!permissionStatus.isGranted) {
        if (permissionStatus.isPermanentlyDenied) {
          // Show dialog to guide user to app settings
          final goToSettings = await _showPermissionSettingsDialog(
            'Storage Permission Required',
            'To save images, this app needs storage permission. Please enable it in app settings.'
          );

          if (goToSettings) {
            await openAppSettings();
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Storage permission is required to save the image')),
          );
        }
        return;
      }

      // Configure Dio with timeout
      final dio = Dio();
      dio.options.connectTimeout = const Duration(seconds: 10);
      dio.options.receiveTimeout = const Duration(seconds: 10);

      // Fetch image data
      final response = await dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch image: Status ${response.statusCode}');
      }

      // Save image to gallery
      final result = await ImageGallerySaver.saveImage(
        Uint8List.fromList(response.data!),
        name: 'invite_${DateTime.now().millisecondsSinceEpoch}',
        quality: 100,
      );

      if (result['isSuccess'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image saved to gallery')),
        );
      } else {
        throw Exception('Failed to save image: ${result['errorMessage'] ?? 'Unknown error'}');
      }
    } catch (e, stackTrace) {
      // Log detailed error for debugging
      debugPrint('Download error: $e\nStackTrace: $stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving image: $e')),
      );
    }
  }

  Future<void> _shareImage(String url, {String caption = 'Check out this invitation!'}) async {
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preparing to share image...')),
      );

      // Downloaded into the temp cache dir, which is app-private — no
      // permission is needed to write or share it from there.

      // Configure Dio with timeout
      final dio = Dio();
      dio.options.connectTimeout = const Duration(seconds: 15);
      dio.options.receiveTimeout = const Duration(seconds: 15);

      // Download image to temporary directory
      final dir = await getTemporaryDirectory();
      final filename = 'invitation_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = '${dir.path}/$filename';

      debugPrint('Downloading image to: $filePath');

      final response = await dio.download(
        url,
        filePath,
        options: Options(responseType: ResponseType.bytes),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to download image: Status ${response.statusCode}');
      }

      // Verify file exists
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Downloaded file does not exist at path: $filePath');
      }

      debugPrint('File downloaded successfully. Size: ${await file.length()} bytes');

      // Share the file with the rendered invitation message as caption
      await Share.shareXFiles(
        [XFile(filePath)],
        text: caption,
        subject: 'Event Invitation',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image shared successfully')),
      );
    } catch (e, stackTrace) {
      // Log detailed error for debugging
      debugPrint('Share error: $e\nStackTrace: $stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Share failed: $e')),
      );
    }
  }

  /// Shares the invitation card image directly to the invitee's WhatsApp chat,
  /// pre-filling the caption with the rendered WhatsApp message template.
  Future<void> _shareImageToWhatsApp(String url, String phone, String caption) async {
    const _whatsappChannel = MethodChannel('net.ajiriwa.events/whatsapp');

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Opening WhatsApp...')),
      );

      // Download image to temp dir
      final dio = Dio();
      dio.options.connectTimeout = const Duration(seconds: 15);
      dio.options.receiveTimeout = const Duration(seconds: 15);

      final dir = await getTemporaryDirectory();
      final filename = 'invitation_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = '${dir.path}/$filename';

      final response = await dio.download(url, filePath);
      if (response.statusCode != 200) {
        throw Exception('Failed to download image');
      }

      // Normalise phone: strip non-digits (keep the digits only; JID format = digits@s.whatsapp.net)
      final digits = phone.replaceAll(RegExp(r'[^\d]'), '');

      if (Platform.isAndroid) {
        try {
          await _whatsappChannel.invokeMethod('shareToWhatsApp', {
            'phone': digits,
            'text': caption,
            'filePath': filePath,
          });
          return;
        } on PlatformException catch (e) {
          if (e.code == 'WHATSAPP_NOT_INSTALLED') {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('WhatsApp is not installed on this device')),
              );
            }
            return;
          }
          // Any other native error — fall through to generic share
          debugPrint('WhatsApp channel error: $e');
        }
      }

      // iOS fallback or if native channel failed: open the chat via URL then share image
      final whatsappUri = Uri.parse('https://wa.me/$digits?text=${Uri.encodeComponent(caption)}');
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      }
      // Share image through system sheet (user can tap WhatsApp)
      await Share.shareXFiles([XFile(filePath)], text: caption, subject: 'Event Invitation');
    } catch (e, stackTrace) {
      debugPrint('WhatsApp share error: $e\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share via WhatsApp: $e')),
        );
      }
    }
  }

  Future<PermissionStatus> _requestStoragePermission() async {
    // Handle permissions based on platform and Android version
    if (Platform.isAndroid) {
      // Saving to the gallery goes through MediaStore (via image_gallery_saver),
      // which needs no runtime permission on Android 10+ (API 29+). The only
      // case that still needs a permission is Android 9 (API 28) and below,
      // which requires WRITE_EXTERNAL_STORAGE — declared in the manifest with
      // android:maxSdkVersion="28", so permission_handler treats this request
      // as a no-op (auto-granted) on newer OS versions.
      if (await Permission.storage.status != PermissionStatus.granted) {
        final storageStatus = await Permission.storage.request();
        debugPrint('Storage permission status: $storageStatus');
        return storageStatus;
      }
      return PermissionStatus.granted;
    } else if (Platform.isIOS) {
      // iOS typically requires photos permission for gallery access
      if (await Permission.photos.status != PermissionStatus.granted) {
        final photosStatus = await Permission.photos.request();
        debugPrint('iOS Photos permission status: $photosStatus');
        return photosStatus;
      }
      return PermissionStatus.granted;
    }

    // Default fallback
    return PermissionStatus.granted;
  }

  void _confirmDelete(Map invitee) {
    final name = invitee['name'];
    final inviteeId = invitee['id'];

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Invitee'),
        content: Text('Are you sure you want to delete "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text('Cancel')
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              try {
                // Show loading indicator
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Deleting $name...')),
                );

                // Find the index of the invitee in the list
                final index = invitees.indexWhere((item) => item['id'] == inviteeId);

                if (index != -1) {
                  // Create a temporary map with the invitee data
                  final tempInvitee = Map<String, dynamic>.from(invitees[index]);

                  // Add a temporary key to track animation state
                  tempInvitee['_isRemoving'] = true;

                  // Update the invitee in the list to trigger animation
                  setState(() {
                    invitees[index] = tempInvitee;
                  });

                  // Wait for animation to complete
                  await Future.delayed(const Duration(milliseconds: 300));

                  // Call API to delete invitee
                  await ApiService.deleteInvitee(inviteeId: inviteeId);

                  // Remove invitee from list
                  setState(() {
                    invitees.removeAt(index);
                  });
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$name deleted successfully')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to delete $name: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showEditInviteeDialog(Map invitee) {
    // Pre-populate form with invitee data
    _nameController.text = invitee['name'];
    _phoneController.text = invitee['phone_number'];
    _numberController.text = invitee['number_of_invitees'].toString();
    _isOnWhatsapp = invitee['is_on_whatsapp'] == 1 || invitee['is_on_whatsapp'] == true;

    final inviteeId = invitee['id'];

    showDialog(
      context: context,
      barrierDismissible: !_isSubmitting,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Edit Invitee'),
              content: Stack(
                children: [
                  Opacity(
                    opacity: _isSubmitting ? 0.5 : 1,
                    child: AbsorbPointer(
                      absorbing: _isSubmitting,
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              controller: _nameController,
                              decoration: const InputDecoration(labelText: 'Name'),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _phoneController,
                              decoration: const InputDecoration(labelText: 'Phone Number'),
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _numberController,
                              decoration: const InputDecoration(labelText: 'Number of Invitees'),
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Text('On WhatsApp?'),
                                const Spacer(),
                                DropdownButton<bool>(
                                  value: _isOnWhatsapp ?? true,
                                  items: const [
                                    DropdownMenuItem(value: true, child: Text('Yes')),
                                    DropdownMenuItem(value: false, child: Text('No')),
                                  ],
                                  onChanged: (value) {
                                    setModalState(() {
                                      _isOnWhatsapp = value;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_isSubmitting)
                    const Positioned.fill(
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: _isSubmitting
                      ? null
                      : () {
                    _clearInviteeForm();
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => _updateInvitee(setModalState, inviteeId, invitee),
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _updateInvitee(Function setModalState, int inviteeId, Map originalInvitee) async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final numberText = _numberController.text.trim();

    if (name.isEmpty || phone.isEmpty || numberText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    final numberOfInvitees = int.tryParse(numberText);
    if (numberOfInvitees == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Number of invitees must be an integer')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    setModalState(() {});

    try {
      final updatedInvitee = await ApiService.updateInvitee(
        inviteeId: inviteeId,
        name: name,
        phoneNumber: phone,
        numberOfInvitees: numberOfInvitees,
        isOnWhatsapp: _isOnWhatsapp ?? true,
      );

      setState(() {
        // Find and update the invitee in the list
        final index = invitees.indexWhere((item) => item['id'] == inviteeId);
        if (index != -1) {
          invitees[index] = updatedInvitee;
        }
      });

      Navigator.pop(context);
      _clearInviteeForm();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invitee "${updatedInvitee['name']}" updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update invitee: ${e.toString()}')),
      );
    } finally {
      setState(() => _isSubmitting = false);
      setModalState(() {});
    }
  }
}
