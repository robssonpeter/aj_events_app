import 'dart:io';

import 'package:dio/dio.dart';
import 'package:aj_events/theme.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'common.dart';
import 'api_service.dart';

class ManageInviteesScreen extends StatefulWidget {
  final int eventId;
  const ManageInviteesScreen({super.key, required this.eventId});

  @override
  _ManageInviteesScreenState createState() => _ManageInviteesScreenState();
}

class _ManageInviteesScreenState extends State<ManageInviteesScreen> {
  List invitees = [];
  int currentPage = 1, lastPage = 1;
  bool isLoading = false;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _numberController = TextEditingController();
  bool _isOnWhatsapp = false;
  bool _isSubmitting = false;
  bool isBulkMode = false;
  Set<int> selectedInviteeIds = {};

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    fetchInvitees();
    _scrollController.addListener(_onScroll);
  }

  Future<void> fetchInvitees() async {
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
      fetchInvitees();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
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
                        ),
                      ),
                      if (!isBulkMode)
                        PopupMenuButton<String>(
                          onSelected: (value) => _handleAction(value, invitee),
                          icon: Icon(Icons.more_vert, color: accentColor),
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'send', child: Text('Send Invitation')),
                            const PopupMenuItem(value: 'preview', child: Text('Preview Card')),
                            const PopupMenuItem(value: 'edit', child: Text('Edit')),
                            const PopupMenuItem(value: 'delete', child: Text('Delete')),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Phone: ${invitee['phone_number']}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Guests: ${invitee['number_of_invitees']}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.black54,
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



  void _handleAction(String action, Map invitee) {
    switch (action) {
      case 'send':
        _sendInvitation(invitee);
        break;
        // TODO: Implement send invitation logic
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sending invitation to ${invitee['name']}')),
        );
        break;
      case 'preview':
      // TODO: Implement preview logic
        _showPreviewDialog(invitee['slug']);
        break;
        /*ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Previewing invitation for ${invitee['name']}')),
        );
        break;*/
      case 'edit':
        _showEditInviteeDialog(invitee);
        break;
      case 'delete':
        _confirmDelete(invitee);
        break;
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



  Widget _actionButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: accentColor, size: 20),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: accentColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _showAddInviteeDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Invitee'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _importFromExcel,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Import Excel'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: secondaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: invitees.isEmpty && !isLoading
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
                          'No invitees found',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Colors.grey[700],
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Click the button below to add a new invitee',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[600],
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
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
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: invitees.length + (isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index < invitees.length) {
                        return _buildInviteeCard(invitees[index]);
                      }
                      return const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _handleBulkAction(String action) {
    final List<Map<String, dynamic>> selectedInvitees = invitees
        .where((invitee) => selectedInviteeIds.contains(invitee['id']))
        .cast<Map<String, dynamic>>()
        .toList();

    switch (action) {
      case 'send':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sending invitations to ${selectedInvitees.length} invitees')),
        );
        break;
      case 'preview':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Previewing ${selectedInvitees.length} cards')),
        );
        break;
      case 'delete':
        _confirmBulkDelete(selectedInvitees);
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
                                Switch(
                                  value: _isOnWhatsapp,
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
    _isOnWhatsapp = false;
  }

  void _importFromExcel() {
    // Dummy action for now
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Excel import functionality coming soon')),
    );
  }

  void _showPreviewDialog(String slug) {
    final url = 'https://events.ajiriwa.net/invitation-card/$slug';

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
                        onPressed: isLoading ? null : () => _shareImage(url),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  Flexible(
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) {
                          if (isLoading) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              setState(() {
                                isLoading = false;
                              });
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
                            setState(() {
                              isLoading = false;
                            });
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
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _downloadImage(String url) async {
    try {
      // Request storage/photos permission based on platform
      final permissionStatus = await _requestStoragePermission();
      if (!permissionStatus.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Storage permission is required to save the image')),
        );
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

  Future<void> _shareImage(String url) async {
    try {
      // Request storage permission for temporary file access
      final permissionStatus = await _requestStoragePermission();
      if (!permissionStatus.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Storage permission is required to share the image')),
        );
        return;
      }

      // Configure Dio with timeout
      final dio = Dio();
      dio.options.connectTimeout = const Duration(seconds: 10);
      dio.options.receiveTimeout = const Duration(seconds: 10);

      // Download image to temporary directory
      final dir = await getTemporaryDirectory();
      final filename = 'invite_share_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = '${dir.path}/$filename';

      final response = await dio.download(
        url,
        filePath,
        options: Options(responseType: ResponseType.bytes),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to download image: Status ${response.statusCode}');
      }

      // Share the file
      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Check out this invitation!',
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

  Future<PermissionStatus> _requestStoragePermission() async {
    // Handle permissions based on platform and Android version
    if (Platform.isAndroid) {
      // For Android 13+, request photos permission
      if (await Permission.photos.isDenied) {
        return await Permission.photos.request();
      }
      // For older Android versions, request storage permission
      if (await Permission.storage.isDenied) {
        return await Permission.storage.request();
      }
    } else if (Platform.isIOS) {
      // iOS typically requires photos permission for gallery access
      if (await Permission.photos.isDenied) {
        return await Permission.photos.request();
      }
    }
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
                                Switch(
                                  value: _isOnWhatsapp,
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
        isOnWhatsapp: _isOnWhatsapp,
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
