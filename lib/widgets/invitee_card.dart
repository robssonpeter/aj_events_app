import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:aj_events/theme.dart';

class InviteeCard extends StatelessWidget {
  final Map invitee;
  final bool isBulkMode;
  final bool isSelected;
  final VoidCallback onLongPress;
  final VoidCallback onTap;
  final void Function(String action, Map invitee) onAction;
  final void Function(Map invitee) onPhoneCall;

  const InviteeCard({
    super.key,
    required this.invitee,
    required this.isBulkMode,
    required this.isSelected,
    required this.onLongPress,
    required this.onTap,
    required this.onAction,
    required this.onPhoneCall,
  });

  @override
  Widget build(BuildContext context) {
    final isRemoving = invitee['_isRemoving'] == true;
    final isOnWhatsapp = invitee['is_on_whatsapp'] == 1 || invitee['is_on_whatsapp'] == true;
    final isSeen = invitee['is_seen'] == 1 || invitee['is_seen'] == true;

    return AnimatedOpacity(
      opacity: isRemoving ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 500),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        child: isRemoving
            ? Container(height: 0)
            : GestureDetector(
                onLongPress: onLongPress,
                onTap: onTap,
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
                                isSelected
                                    ? Icons.check_box
                                    : Icons.check_box_outline_blank,
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
                                onSelected: (value) => onAction(value, invitee),
                                icon: Icon(Icons.more_vert, color: accentColor),
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                      value: 'send', child: Text('Send Invitation')),
                                  const PopupMenuItem(
                                      value: 'render_sms', child: Text('Render SMS')),
                                  const PopupMenuItem(
                                      value: 'call', child: Text('Call')),
                                  if (isOnWhatsapp)
                                    const PopupMenuItem(
                                        value: 'mark_whatsapp_sent',
                                        child: Text('Mark WhatsApp Sent')),
                                  if (!isSeen)
                                    const PopupMenuItem(
                                        value: 'mark_seen', child: Text('Mark as Seen')),
                                  const PopupMenuItem(
                                      value: 'send_download_card',
                                      child: Text('Send Download Card Msg')),
                                  const PopupMenuItem(
                                      value: 'preview', child: Text('Preview Card')),
                                  const PopupMenuItem(
                                      value: 'edit', child: Text('Edit')),
                                  const PopupMenuItem(
                                      value: 'delete', child: Text('Delete')),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => onPhoneCall(invitee),
                                child: Text(
                                  'Phone: ${invitee['phone_number']}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(color: Colors.blue),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            if (isOnWhatsapp)
                              const FaIcon(FontAwesomeIcons.whatsapp,
                                  color: Colors.green, size: 16),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Guests: ${invitee['number_of_invitees']}',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Colors.black54),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (invitee['attendance_status'] == 'attending' ||
                            invitee['attendance_status'] == 'not_attending') ...[
                          const SizedBox(height: 4),
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
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: invitee['attendance_status'] == 'attending'
                                          ? Colors.green
                                          : Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
