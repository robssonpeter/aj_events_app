import 'package:flutter/material.dart';
import 'package:aj_events/theme.dart';

class InvitationSelectionTools extends StatelessWidget {
  final VoidCallback onSelectName;
  final VoidCallback onSelectQrCode;
  final VoidCallback onSave;

  const InvitationSelectionTools({
    super.key,
    required this.onSelectName,
    required this.onSelectQrCode,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final halfWidth = (MediaQuery.of(context).size.width - 80) / 2;

    return Card(
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
                  width: halfWidth,
                  child: ElevatedButton.icon(
                    onPressed: onSelectName,
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
                  width: halfWidth,
                  child: ElevatedButton.icon(
                    onPressed: onSelectQrCode,
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
                onPressed: onSave,
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
    );
  }
}
