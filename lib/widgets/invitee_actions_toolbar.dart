import 'package:flutter/material.dart';
import 'package:aj_events/theme.dart';

class InviteeActionsToolbar extends StatelessWidget {
  final bool isFilterActive;
  final VoidCallback onAddInvitee;
  final VoidCallback onImportExcel;
  final VoidCallback onFilter;
  final VoidCallback onManageTemplates;

  const InviteeActionsToolbar({
    super.key,
    required this.isFilterActive,
    required this.onAddInvitee,
    required this.onImportExcel,
    required this.onFilter,
    required this.onManageTemplates,
  });

  Widget _actionButton(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool isActive = false,
  }) {
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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _actionButton(context, Icons.add, 'Add Invitee', onAddInvitee),
          const SizedBox(width: 24),
          _actionButton(context, Icons.upload_file, 'Import Excel', onImportExcel),
          const SizedBox(width: 24),
          _actionButton(
            context,
            Icons.filter_list,
            isFilterActive ? 'Filters Active' : 'Filter',
            onFilter,
            isActive: isFilterActive,
          ),
          const SizedBox(width: 24),
          _actionButton(
            context,
            Icons.message_outlined,
            'Manage Templates',
            onManageTemplates,
          ),
        ],
      ),
    );
  }
}
