import 'package:flutter/material.dart';

class InviteeFilterBar extends StatelessWidget {
  final int totalCount;
  final bool? filterWhatsappStatus;
  final bool? filterInvitationSent;
  final String? filterAttendanceStatus;
  final bool? filterCardRedeemed;
  final bool? filterSeenStatus;
  final VoidCallback onClearWhatsapp;
  final VoidCallback onClearInvitationSent;
  final VoidCallback onClearAttendance;
  final VoidCallback onClearRedeemed;
  final VoidCallback onClearSeen;
  final VoidCallback onClearAll;

  const InviteeFilterBar({
    super.key,
    required this.totalCount,
    required this.filterWhatsappStatus,
    required this.filterInvitationSent,
    required this.filterAttendanceStatus,
    required this.filterCardRedeemed,
    required this.filterSeenStatus,
    required this.onClearWhatsapp,
    required this.onClearInvitationSent,
    required this.onClearAttendance,
    required this.onClearRedeemed,
    required this.onClearSeen,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
          child: Text(
            'Found $totalCount ${totalCount == 1 ? 'invitee' : 'invitees'}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.start,
              children: [
                if (filterWhatsappStatus != null)
                  Chip(
                    label: Text(filterWhatsappStatus! ? 'Has WhatsApp' : 'No WhatsApp'),
                    onDeleted: onClearWhatsapp,
                  ),
                if (filterInvitationSent != null)
                  Chip(
                    label: Text(filterInvitationSent! ? 'Invitation Sent' : 'Not Sent'),
                    onDeleted: onClearInvitationSent,
                  ),
                if (filterAttendanceStatus != null)
                  Chip(
                    label: Text(filterAttendanceStatus == 'attending'
                        ? 'Attending'
                        : filterAttendanceStatus == 'not_attending'
                            ? 'Not Attending'
                            : 'Pending'),
                    onDeleted: onClearAttendance,
                  ),
                if (filterCardRedeemed != null)
                  Chip(
                    label: Text(filterCardRedeemed! ? 'Card Redeemed' : 'Card Not Redeemed'),
                    onDeleted: onClearRedeemed,
                  ),
                if (filterSeenStatus != null)
                  Chip(
                    label: Text(filterSeenStatus! ? 'Seen' : 'Not Seen'),
                    onDeleted: onClearSeen,
                  ),
                TextButton(
                  onPressed: onClearAll,
                  child: const Text('Clear All'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
