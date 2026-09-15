import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/contribution_models.dart';
import '../../theme.dart';

/// Money the way a kamati reads it: whole shillings, thousands separated.
String money(num? amount, [String currency = 'TZS']) {
  final value = (amount ?? 0).toDouble();
  return '${NumberFormat('#,##0', 'en_US').format(value)} $currency';
}

/// Shorter form for tight spaces — 1.2M / 450K.
String moneyShort(num? amount, [String currency = 'TZS']) {
  final value = (amount ?? 0).toDouble();

  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(value % 1000000 == 0 ? 0 : 1)}M $currency';
  }
  if (value >= 10000) {
    return '${(value / 1000).toStringAsFixed(0)}K $currency';
  }

  return money(value, currency);
}

Color statusColor(String status) {
  switch (status) {
    case 'paid':
      return const Color(0xFF047857);
    case 'partial':
      return const Color(0xFFB45309);
    case 'pledged':
      return const Color(0xFF1D4ED8);
    case 'declined':
      return const Color(0xFFB91C1C);
    default:
      return const Color(0xFF6B7280);
  }
}

/// The headline panel: where collection stands, at a glance.
class ContributionStatsHeader extends StatelessWidget {
  final ContributionStats stats;
  final VoidCallback? onTapOutstanding;

  const ContributionStatsHeader({super.key, required this.stats, this.onTapOutstanding});

  @override
  Widget build(BuildContext context) {
    final hasTarget = stats.target > 0;
    final progress = hasTarget ? (stats.targetProgress ?? 0) : stats.promiseProgress;

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      elevation: 0,
      color: primaryColor.withOpacity(0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: primaryColor.withOpacity(0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Imekusanywa',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                      const SizedBox(height: 2),
                      Text(
                        money(stats.collected, stats.currency),
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                      ),
                    ],
                  ),
                ),
                if (hasTarget)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Lengo', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                      const SizedBox(height: 2),
                      Text(moneyShort(stats.target, stats.currency),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (progress / 100).clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: Colors.white,
                valueColor: const AlwaysStoppedAnimation(Color(0xFF047857)),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              hasTarget ? '$progress% ya lengo' : '$progress% ya ahadi zilizotolewa',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
            ),
            const Divider(height: 20),
            Row(
              children: [
                _stat('Wachangiaji', '${stats.contributors}'),
                _stat('Ahadi', moneyShort(stats.promised, stats.currency)),
                _stat('Bakaa', moneyShort(stats.outstanding, stats.currency),
                    color: stats.outstanding > 0 ? const Color(0xFFB45309) : null),
                _stat('Kadi', '${stats.cardsSent}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value, {Color? color}) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade700)),
        ],
      ),
    );
  }
}

/// One row in the contribution list. Tap opens them; long-press starts a
/// selection for bulk sending.
class ContributorTile extends StatelessWidget {
  final Contributor contributor;
  final bool selected;
  final bool selectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const ContributorTile({
    super.key,
    required this.contributor,
    required this.selected,
    required this.selectionMode,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final c = contributor;
    final color = statusColor(c.status);

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        color: selected ? primaryColor.withOpacity(0.08) : null,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            if (selectionMode)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Icon(
                  selected ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: selected ? primaryColor : Colors.grey.shade400,
                ),
              )
            else
              Container(
                width: 40,
                height: 40,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(
                  c.name.isNotEmpty ? c.name.characters.first.toUpperCase() : '?',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(c.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      ),
                      if (c.waTickStatus != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Icon(
                            c.waTickStatus == 'sent' ? Icons.done : Icons.done_all,
                            size: 13,
                            color: c.waTickStatus == 'read' ? Colors.blue : Colors.grey.shade500,
                          ),
                        )
                      else if (c.cardSent)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Icon(Icons.send, size: 13, color: Colors.grey.shade500),
                        ),
                      if (c.isOnWhatsapp)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Icon(Icons.chat, size: 13, color: Colors.green.shade600),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    c.group == null || c.group!.isEmpty
                        ? c.phoneNumber
                        : '${c.phoneNumber} · ${c.group}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(c.statusLabel,
                            style: TextStyle(
                                fontSize: 10, color: color, fontWeight: FontWeight.w600)),
                      ),
                      if (c.hasPromised) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            c.balance > 0
                                ? '${money(c.paidAmount, c.currency)} / ${money(c.amount, c.currency)}'
                                : money(c.paidAmount, c.currency),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Placeholder rows shown while a filter or search refetches.
///
/// Skeletons rather than a spinner: they keep the list's shape, so the screen
/// does not jump when the real rows land, and they make it obvious *which*
/// part of the screen is changing — the totals above stay put because they are
/// event-wide and unaffected by the filter.
class ContributorSkeletonList extends StatefulWidget {
  final int rows;

  const ContributorSkeletonList({super.key, this.rows = 6});

  @override
  State<ContributorSkeletonList> createState() => _ContributorSkeletonListState();
}

class _ContributorSkeletonListState extends State<ContributorSkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, _) {
        final opacity = 0.35 + (_pulse.value * 0.35);

        return ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: widget.rows,
          separatorBuilder: (_, _) => Divider(height: 1, color: Colors.grey.shade200),
          itemBuilder: (_, _) => Opacity(
            opacity: opacity,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _bar(140, 12),
                        const SizedBox(height: 7),
                        _bar(190, 10),
                        const SizedBox(height: 8),
                        _bar(90, 10),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _bar(double width, double height) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(4),
        ),
      );
}

/// Shown when a filter or an empty list leaves nothing to display.
class ContributionEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const ContributionEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: Colors.grey.shade400),
            const SizedBox(height: 14),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
