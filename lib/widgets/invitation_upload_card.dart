import 'dart:io';
import 'package:flutter/material.dart';
import 'package:aj_events/theme.dart';

class InvitationUploadCard extends StatelessWidget {
  final File? imageFile;
  final VoidCallback onUpload;

  const InvitationUploadCard({
    super.key,
    required this.imageFile,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton.icon(
          onPressed: onUpload,
          icon: const Icon(Icons.upload_file),
          label: Text(imageFile != null
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
    );
  }
}
