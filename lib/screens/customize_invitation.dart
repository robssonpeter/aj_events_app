import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme.dart';

class CustomizeInvitationScreen extends StatefulWidget {
  final int eventId;
  final Map<String, dynamic>? event;

  const CustomizeInvitationScreen({
    super.key,
    required this.eventId,
    this.event,
  });

  @override
  _CustomizeInvitationScreenState createState() =>
      _CustomizeInvitationScreenState();
}

class _CustomizeInvitationScreenState extends State<CustomizeInvitationScreen> {
  File? _imageFile;
  Size? _originalDimensions;
  Size? _displayResolution;
  Map<String, Rect?> selections = {'name': null, 'qrcode': null};
  String? _selectingType;
  Offset? _startPoint;
  bool _isDrawing = false;
  bool _isLoading = false;
  String? _templateId;

  // Variables for dragging functionality
  String? _draggingType;
  Offset? _dragStartOffset;
  Rect? _originalRect;

  @override
  void initState() {
    super.initState();
    _loadTemplate();
  }

  @override
  void didUpdateWidget(CustomizeInvitationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the event ID has changed, clear the current template and load the new one
    if (oldWidget.eventId != widget.eventId) {
      print('Event ID changed from ${oldWidget.eventId} to ${widget.eventId}. Reloading template...');

      // Clear template data
      print('Clearing template data');
      setState(() {
        _imageFile = null;
        _originalDimensions = null;
        _displayResolution = null;
        selections = {'name': null, 'qrcode': null};
        _selectingType = null;
        _startPoint = null;
        _isDrawing = false;
        _templateId = null;
      });

      _loadTemplate();
    }
  }

  Future<void> _loadTemplate() async {
    print('Loading template for event ID: ${widget.eventId}');

    if (widget.eventId > 0) {
      setState(() => _isLoading = true);

      try {
        final url = 'https://events.ajiriwa.net/api/templates/${widget.eventId}';
        print('Fetching template from: $url');

        final response = await http.get(Uri.parse(url));

        if (response.statusCode == 200) {
          print('Template fetched successfully');
          final template = json.decode(response.body);

          final imagePath = 'https://events.ajiriwa.net/storage/${template['image_path']}';
          print('Template image path: $imagePath');

          final tempDir = await getTemporaryDirectory();
          final tempFile = File('${tempDir.path}/template${widget.eventId}.jpg');

          // Check if file exists and delete it before writing new image
          if (await tempFile.exists()) {
            print('Deleting existing cached template image...');
            await tempFile.delete();
          }

          print('Downloading template image...');
          final imageResponse = await http.get(Uri.parse(imagePath));
          await tempFile.writeAsBytes(imageResponse.bodyBytes);
          print('Template image downloaded to: ${tempFile.path}');

          setState(() {
            _imageFile = tempFile;
            _templateId = template['id'].toString();
            // Initialize selections map with null values
            selections = {'name': null, 'qrcode': null};
          });

          print('Decoding image to get dimensions...');
          final decodedImage = img.decodeImage(imageResponse.bodyBytes);

          if (decodedImage != null) {
            print('Image decoded successfully: ${decodedImage.width}x${decodedImage.height}');

            setState(() {
              _originalDimensions = Size(
                decodedImage.width.toDouble(),
                decodedImage.height.toDouble(),
              );
            });

            // Update display resolution after setting original dimensions
            print('Updating display resolution...');
            _updateDisplayResolution();

            // Apply template selections after display resolution is updated
            if (_displayResolution != null) {
              print('Applying template selections...');
              setState(() {
                if (template['name_selection'] != null) {
                  print('Applying name selection: ${template['name_selection']}');
                  selections['name'] = _scaleRect(template['name_selection']);
                  print('Scaled name selection: ${selections['name']}');
                }

                if (template['qrcode_selection'] != null) {
                  print('Applying QR code selection: ${template['qrcode_selection']}');
                  selections['qrcode'] = _scaleRect(template['qrcode_selection']);
                  print('Scaled QR code selection: ${selections['qrcode']}');
                }
              });

              print('Template loaded successfully with selections');
            } else {
              print('Warning: Display resolution is null, cannot scale selections');
            }
          } else {
            print('Error: Failed to decode image');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Failed to decode template image')),
              );
            }
          }
        } else if (response.statusCode == 404) {
          print('No template found for event ID: ${widget.eventId}');
          // This is not an error, just no template exists yet for this event
        } else {
          print('Error: Failed to fetch template. Status code: ${response.statusCode}');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to load template. Status code: ${response.statusCode}')),
            );
          }
        }
      } catch (e) {
        print('Error loading template: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading template: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        print('Template loading completed');
      }
    } else {
      print('No template found for event ID: ${widget.eventId}');
    }
  }

  Rect _scaleRect(Map<String, dynamic> position) {
    final scale = _calculateScale();
    return Rect.fromLTWH(
      position['x'] * scale,
      position['y'] * scale,
      position['width'] * scale,
      position['height'] * scale,
    );
  }

  double _calculateScale() {
    if (_originalDimensions == null || _displayResolution == null) return 1.0;
    return (_displayResolution!.width / _originalDimensions!.width)
        .clamp(0.1, 1.0);
  }

  void _updateDisplayResolution() {
    if (_originalDimensions == null) {
      print('Warning: Cannot update display resolution, original dimensions are null');
      return;
    }

    if (!mounted) {
      print('Warning: Cannot update display resolution, widget is not mounted');
      return;
    }

    try {
      final size = MediaQuery.of(context).size;
      final maxWidth = size.width - 32; // Account for padding
      final maxHeight = size.height * 0.6; // 60% of screen height
      final scale = (_originalDimensions!.width / _originalDimensions!.height >
          maxWidth / maxHeight)
          ? maxWidth / _originalDimensions!.width
          : maxHeight / _originalDimensions!.height;

      print('Updating display resolution: original=${_originalDimensions!.width}x${_originalDimensions!.height}, scale=$scale');

      setState(() {
        _displayResolution = Size(
          _originalDimensions!.width * scale,
          _originalDimensions!.height * scale,
        );
      });

      print('Display resolution updated: ${_displayResolution!.width}x${_displayResolution!.height}');
    } catch (e) {
      print('Error updating display resolution: $e');
    }
  }

  Future<int> _getAndroidSdkVersion() async {
    if (Platform.isAndroid) {
      final version = Platform.version.split('.').first;
      return int.tryParse(version) ?? 0;
    }
    return 0;
  }

  Future<void> _requestPermissions(ImageSource source) async {
    try {
      if (source == ImageSource.camera) {
        // Check if camera permission is already granted
        final cameraStatus = await Permission.camera.status;
        if (cameraStatus.isGranted) {
          return; // Permission already granted, no need to request
        }

        final requestStatus = await Permission.camera.request();
        if (requestStatus != PermissionStatus.granted) {
          _showPermissionDeniedDialog('Camera');
          return;
        }
      } else {
        // For gallery access
        if (Platform.isAndroid) {
          final sdkVersion = await _getAndroidSdkVersion();
          Permission permission = sdkVersion >= 33 ? Permission.photos : Permission.storage;

          // Check if permission is already granted
          final permissionStatus = await permission.status;
          if (permissionStatus.isGranted) {
            return; // Permission already granted, no need to request
          }

          final requestStatus = await permission.request();
          if (requestStatus != PermissionStatus.granted) {
            _showPermissionDeniedDialog('Gallery');
            return;
          }
        } else if (Platform.isIOS) {
          // Check if photos permission is already granted
          final photoStatus = await Permission.photos.status;
          if (photoStatus.isGranted) {
            return; // Permission already granted, no need to request
          }

          final requestStatus = await Permission.photos.request();
          if (requestStatus != PermissionStatus.granted) {
            _showPermissionDeniedDialog('Gallery');
            return;
          }
        }
      }
    } catch (e) {
      print('Permission request error: $e');
    }
  }

  void _showPermissionDeniedDialog(String permissionType) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$permissionType Permission Required'),
        content: Text(
          'This app needs $permissionType permission to select images. Please grant permission in app settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No image selected')),
          );
        }
        return;
      }

      if (mounted) {
        setState(() {
          _isLoading = true;
          _imageFile = File(pickedFile.path);
        });
      }

      await _uploadImage();
    } catch (e) {
      print('Image picking error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting image: ${e.toString()}')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _uploadImage() async {
    if (_imageFile == null) return;

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://events.ajiriwa.net/api/template/store/${widget.eventId}'),
      );
      request.files.add(
        await http.MultipartFile.fromPath('image', _imageFile!.path),
      );

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final template = json.decode(responseBody);
        if (mounted) {
          setState(() {
            _templateId = template['id'].toString();
            selections = {'name': null, 'qrcode': null};
          });
        }

        final decodedImage = img.decodeImage(await _imageFile!.readAsBytes());
        if (decodedImage != null && mounted) {
          _originalDimensions = Size(
            decodedImage.width.toDouble(),
            decodedImage.height.toDouble(),
          );
          _updateDisplayResolution();
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Image uploaded successfully!')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to upload image')),
          );
        }
      }
    } catch (e) {
      print('Upload error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleFileUpload() async {
    // Show source selection (Gallery or Camera)
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Select Image Source',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.photo_library, color: primaryColor),
                ),
                title: const Text('Gallery'),
                subtitle: const Text('Choose from your photos'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.camera_alt, color: primaryColor),
                ),
                title: const Text('Camera'),
                subtitle: const Text('Take a new photo'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    // Confirm before clearing existing selections if image already exists
    if (_imageFile != null || selections['name'] != null || selections['qrcode'] != null) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Replace Template'),
          content: const Text('Uploading a new image will clear existing selections. Continue?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    // Request permissions first
    await _requestPermissions(source);

    // Then pick the image
    await _pickImage(source);
  }

  void _startSelecting(String type) {
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload an image first')),
      );
      return;
    }
    setState(() {
      _selectingType = type;
      selections[type] = null;
    });
  }

  Future<void> _saveSelections() async {
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload an image first')),
      );
      return;
    }

    // If we have an image but no templateId, we need to upload the image first
    if (_templateId == null) {
      setState(() => _isLoading = true);
      try {
        await _uploadImage();
        if (_templateId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to process template. Please try again.')),
          );
          return;
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        setState(() => _isLoading = false);
        return;
      }
    }
    setState(() => _isLoading = true);
    try {
      final scaledSelections = {
        'name_selection': selections['name'] != null
            ? {
          'x': selections['name']!.left / _calculateScale(),
          'y': selections['name']!.top / _calculateScale(),
          'width': selections['name']!.width / _calculateScale(),
          'height': selections['name']!.height / _calculateScale(),
        }
            : null,
        'qrcode_selection': selections['qrcode'] != null
            ? {
          'x': selections['qrcode']!.left / _calculateScale(),
          'y': selections['qrcode']!.top / _calculateScale(),
          'width': selections['qrcode']!.width / _calculateScale(),
          'height': selections['qrcode']!.height / _calculateScale(),
        }
            : null,
        'resolution': {
          'width': _displayResolution?.width ?? 0,
          'height': _displayResolution?.height ?? 0,
        },
      };
      final response = await http.put(
        Uri.parse('https://events.ajiriwa.net/api/templates/$_templateId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(scaledSelections),
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selections saved successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save selections')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving selections: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildEmptyImageState() {
    return Card(
      elevation: Theme.of(context).cardTheme.elevation,
      shape: Theme.of(context).cardTheme.shape,
      child: InkWell(
        onTap: _handleFileUpload,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          height: 300,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: primaryColor.withOpacity(0.3),
              width: 2,
              style: BorderStyle.solid,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add_photo_alternate,
                  size: 48,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Upload Template to Start',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Tap here to select an invitation image\nfrom your gallery or camera',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          widget.event != null
              ? 'Customize: ${widget.event!['title']}'
              : 'Customize Invitation',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: primaryColor,
        elevation: 4,
        actions: [
          if (_imageFile != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Reset Selections',
              onPressed: _resetSelections,
            ),
        ],
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryColor.withOpacity(0.9), accentColor.withOpacity(0.9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Text(
                    'Customize Your Invitation',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Upload an image and select areas for name and QR code placement.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  const SizedBox(height: 24),

                  // Upload Button
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: ElevatedButton.icon(
                        onPressed: _handleFileUpload,
                        icon: const Icon(Icons.upload_file),
                        label: Text(_imageFile != null
                            ? 'Replace Invitation Image'
                            : 'Upload Invitation Image'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Selection Tools
                  if (_imageFile != null)
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Selection Tools',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Draw selection areas and drag them to reposition.',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                SizedBox(
                                  width: (MediaQuery.of(context).size.width - 80) / 2,
                                  child: ElevatedButton.icon(
                                    onPressed: () => _startSelecting('name'),
                                    icon: const Icon(Icons.text_fields, size: 20),
                                    label: const Text('Name Area'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: accentColor,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: (MediaQuery.of(context).size.width - 80) / 2,
                                  child: ElevatedButton.icon(
                                    onPressed: () => _startSelecting('qrcode'),
                                    icon: const Icon(Icons.qr_code, size: 20),
                                    label: const Text('QR Code'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: secondaryColor,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _saveSelections,
                                icon: const Icon(Icons.save, size: 20),
                                label: const Text('Save Selections'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber[700],
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Image Canvas Area
                  _imageFile != null
                      ? Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: AspectRatio(
                        aspectRatio: (_displayResolution?.width ?? 3) /
                            (_displayResolution?.height ?? 2),
                        child: InteractiveViewer(
                          minScale: 0.5,
                          maxScale: 3.0,
                          child: GestureDetector(
                            onPanStart: (details) {
                              final position = details.localPosition;

                              // Check if we're clicking on an existing selection
                              final selectionType = _getSelectionAtPoint(position);

                              if (selectionType != null) {
                                // We're starting to drag an existing selection
                                setState(() {
                                  _draggingType = selectionType;
                                  _dragStartOffset = position;
                                  _originalRect = selections[selectionType];
                                  print('Started dragging $selectionType selection');
                                });

                                // Show a brief message to indicate dragging has started
                                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Dragging ${selectionType == 'name' ? 'Name Area' : 'QR Code'} selection'),
                                    duration: const Duration(seconds: 1),
                                    backgroundColor: selectionType == 'name' ? Colors.green : Colors.red,
                                  ),
                                );
                              } else if (_selectingType != null) {
                                // We're drawing a new selection
                                setState(() {
                                  _isDrawing = true;
                                  _startPoint = position;
                                  selections[_selectingType!] = Rect.fromLTWH(
                                    _startPoint!.dx,
                                    _startPoint!.dy,
                                    0,
                                    0,
                                  );
                                });
                              }
                            },
                            onPanUpdate: (details) {
                              final position = details.localPosition;

                              if (_draggingType != null && _originalRect != null && _dragStartOffset != null) {
                                // We're dragging an existing selection
                                final dx = position.dx - _dragStartOffset!.dx;
                                final dy = position.dy - _dragStartOffset!.dy;

                                // Calculate new position
                                double newLeft = _originalRect!.left + dx;
                                double newTop = _originalRect!.top + dy;

                                // Constrain to image bounds
                                if (_displayResolution != null) {
                                  // Ensure the selection stays within the image bounds
                                  newLeft = newLeft.clamp(0, _displayResolution!.width - _originalRect!.width);
                                  newTop = newTop.clamp(0, _displayResolution!.height - _originalRect!.height);
                                }

                                setState(() {
                                  selections[_draggingType!] = Rect.fromLTWH(
                                    newLeft,
                                    newTop,
                                    _originalRect!.width,
                                    _originalRect!.height,
                                  );
                                });
                              } else if (_isDrawing && _selectingType != null && _startPoint != null) {
                                // We're drawing a new selection
                                final width = _selectingType == 'qrcode'
                                    ? (position.dx - _startPoint!.dx).abs()
                                    : (position.dx - _startPoint!.dx);
                                final height = _selectingType == 'qrcode'
                                    ? width
                                    : (position.dy - _startPoint!.dy);
                                setState(() {
                                  selections[_selectingType!] = Rect.fromLTWH(
                                    width >= 0 ? _startPoint!.dx : position.dx,
                                    height >= 0 ? _startPoint!.dy : position.dy,
                                    width.abs(),
                                    height.abs(),
                                  );
                                });
                              }
                            },
                            onPanEnd: (_) {
                              setState(() {
                                // Reset all interaction states
                                _isDrawing = false;
                                _selectingType = null;
                                _draggingType = null;
                                _dragStartOffset = null;
                                _originalRect = null;
                              });
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Stack(
                                children: [
                                  Image.file(
                                    _imageFile!,
                                    fit: BoxFit.contain,
                                    width: double.infinity,
                                    height: double.infinity,
                                  ),
                                  CustomPaint(
                                    size: _displayResolution ?? const Size(300, 200),
                                    painter: InvitationPainter(
                                      nameRect: selections['name'],
                                      qrCodeRect: selections['qrcode'],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                      : _buildEmptyImageState(),
                ],
              ),
            ),
          ),

          // Loading Overlay
          AnimatedOpacity(
            opacity: _isLoading ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: _isLoading
                ? Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                ),
              ),
            )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  void _resetSelections() {
    if (_imageFile == null) return;

    setState(() {
      selections.clear(); // Remove all rectangles
      _selectingType = null;
      _isDrawing = false;
      _draggingType = null;
      _dragStartOffset = null;
      _originalRect = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Selections have been reset')),
    );
  }

  // Helper method to check if a point is inside a selection
  String? _getSelectionAtPoint(Offset point) {
    for (final entry in selections.entries) {
      final type = entry.key;
      final rect = entry.value;
      if (rect != null && rect.contains(point)) {
        return type;
      }
    }
    return null;
  }


}

class InvitationPainter extends CustomPainter {
  final Rect? nameRect;
  final Rect? qrCodeRect;

  InvitationPainter({
    this.nameRect,
    this.qrCodeRect,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (nameRect != null) {
      // Draw the selection rectangle
      canvas.drawRect(
        nameRect!,
        Paint()
          ..color = Colors.green.withOpacity(0.3)
          ..style = PaintingStyle.fill,
      );
      canvas.drawRect(
        nameRect!,
        Paint()
          ..color = Colors.green
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );

      // Draw the main label
      final textPainter = TextPainter(
        text: const TextSpan(
          text: 'Invitee Name',
          style: TextStyle(
            color: Colors.black,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          nameRect!.center.dx - textPainter.width / 2,
          nameRect!.center.dy - textPainter.height / 2,
        ),
      );

      // Draw the drag handle icon
      final dragIconPainter = TextPainter(
        text: const TextSpan(
          text: '↔ Drag',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      dragIconPainter.layout();
      dragIconPainter.paint(
        canvas,
        Offset(
          nameRect!.center.dx - dragIconPainter.width / 2,
          nameRect!.bottom - dragIconPainter.height - 4,
        ),
      );
    }

    if (qrCodeRect != null) {
      // Draw the selection rectangle
      canvas.drawRect(
        qrCodeRect!,
        Paint()
          ..color = Colors.red.withOpacity(0.3)
          ..style = PaintingStyle.fill,
      );
      canvas.drawRect(
        qrCodeRect!,
        Paint()
          ..color = Colors.red
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );

      // Draw the main label
      final textPainter = TextPainter(
        text: const TextSpan(
          text: 'QR Code',
          style: TextStyle(
            color: Colors.black,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          qrCodeRect!.center.dx - textPainter.width / 2,
          qrCodeRect!.center.dy - textPainter.height / 2,
        ),
      );

      // Draw the drag handle icon
      final dragIconPainter = TextPainter(
        text: const TextSpan(
          text: '↔ Drag',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      dragIconPainter.layout();
      dragIconPainter.paint(
        canvas,
        Offset(
          qrCodeRect!.center.dx - dragIconPainter.width / 2,
          qrCodeRect!.bottom - dragIconPainter.height - 4,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
