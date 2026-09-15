import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/contributions_api.dart';
import '../../models/contribution_models.dart';
import '../../theme.dart';
import '../../widgets/contributions/contribution_widgets.dart';

/// One contributor: where they stand, their card, and their payments.
class ContributorDetailScreen extends StatefulWidget {
  final int eventId;
  final Contributor contributor;

  const ContributorDetailScreen({super.key, required this.eventId, required this.contributor});

  @override
  State<ContributorDetailScreen> createState() => _ContributorDetailScreenState();
}

class _ContributorDetailScreenState extends State<ContributorDetailScreen> {
  late Contributor _c;
  CardShare? _card;
  bool _busy = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _c = widget.contributor;
    _loadCard();
  }

  Future<void> _loadCard() async {
    try {
      final card = await ContributionsApi.card(_c.id);
      if (mounted) setState(() => _card = card);
    } catch (_) {
      // No card design yet, or offline — the card section just stays hidden.
    }
  }

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? Colors.red.shade700 : null,
      duration: Duration(seconds: error ? 6 : 3),
    ));
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Download the rendered card and hand it to the OS share sheet — which is
  /// how a card reaches a WhatsApp group, since no API can post to one.
  Future<void> _shareCard() async {
    final card = _card;
    if (card == null) return;

    await _run(() async {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/kadi-${_c.slug}.jpg';

      await Dio().download(card.cardUrl, path);

      await Share.shareXFiles(
        [XFile(path)],
        text: card.shareText,
        subject: 'Kadi ya mchango',
      );
    });
  }

  Future<void> _shareLinkOnly() async {
    final card = _card;
    if (card == null) return;

    await Share.share(card.shareText, subject: 'Kadi ya mchango');
  }

  Future<void> _sendCard() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Send to ${_c.name}?'),
        content: Text(_c.isOnWhatsapp
            ? 'Their card will be sent on WhatsApp to ${_c.phoneNumber}.'
            : 'They are not on WhatsApp, so an SMS will be sent to ${_c.phoneNumber}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Send')),
        ],
      ),
    );
    if (ok != true) return;

    await _run(() async {
      final message = await ContributionsApi.sendCard(_c.id);
      _snack(message);
      _changed = true;

      // Reflect the send without a round trip; the list reloads on the way back.
      setState(() => _c = _c.copyWithCardSentNow());
    });
  }

  Future<void> _call() async {
    final uri = Uri.parse('tel:${_c.phoneNumber}');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _recordPayment() async {
    final result = await showModalBottomSheet<Contributor>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PaymentSheet(contributor: _c),
    );

    if (result != null) {
      setState(() {
        _c = result;
        _changed = true;
      });
      _snack('Payment recorded.');
    }
  }

  Future<void> _editPromise() async {
    final result = await showModalBottomSheet<Contributor>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditSheet(contributor: _c),
    );

    if (result != null) {
      setState(() {
        _c = result;
        _changed = true;
      });
      _snack('Saved.');
    }
  }

  Future<void> _deletePayment(ContributionPayment p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove this payment?'),
        content: Text('${money(p.amount, p.currency)} will be taken off their total.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await _run(() async {
      final updated = await ContributionsApi.deletePayment(p.id);
      setState(() {
        _c = updated;
        _changed = true;
      });
      _snack('Payment removed.');
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_c.name, overflow: TextOverflow.ellipsis),
          actions: [
            IconButton(icon: const Icon(Icons.call), tooltip: 'Call', onPressed: _call),
            IconButton(icon: const Icon(Icons.edit), tooltip: 'Edit', onPressed: _editPromise),
          ],
        ),
        body: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.only(bottom: 90),
              children: [
                _summary(),
                if (_card != null) _cardSection(),
                _paymentsSection(),
              ],
            ),
            if (_busy)
              Container(
                  color: Colors.black26, child: const Center(child: CircularProgressIndicator())),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _recordPayment,
                    icon: const Icon(Icons.payments_outlined, size: 18),
                    label: const Text('Record payment'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _sendCard,
                    icon: const Icon(Icons.send, size: 18),
                    label: Text(_c.cardSent ? 'Resend' : 'Send card'),
                    style: OutlinedButton.styleFrom(foregroundColor: primaryColor),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _summary() {
    final color = statusColor(_c.status);

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(_c.statusLabel,
                      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
                ),
                const Spacer(),
                Flexible(
                  child: Text(_c.phoneNumber,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _figure('Ahadi', _c.hasPromised ? money(_c.amount, _c.currency) : '—'),
                _figure('Umelipa', money(_c.paidAmount, _c.currency),
                    color: const Color(0xFF047857)),
                _figure('Bakaa', _c.balance > 0 ? money(_c.balance, _c.currency) : '—',
                    color: _c.balance > 0 ? const Color(0xFFB45309) : null),
              ],
            ),
            if (_c.hasPromised) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (_c.progress / 100).clamp(0.0, 1.0),
                  minHeight: 7,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation(
                      _c.isSettled ? const Color(0xFF047857) : const Color(0xFFF59E0B)),
                ),
              ),
            ],
            if (_c.group != null && _c.group!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Kundi: ${_c.group}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
            ],
            if (_c.notes != null && _c.notes!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(_c.notes!, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
            ],
            if (_c.cardSent) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.check_circle, size: 14, color: Colors.green.shade600),
                  const SizedBox(width: 5),
                  Text('Card sent ${_dateLabel(_c.cardSentAt!)}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  if (_c.waTickStatus != null) ...[
                    const SizedBox(width: 8),
                    Icon(
                      _c.waTickStatus == 'sent' ? Icons.done : Icons.done_all,
                      size: 13,
                      color: _c.waTickStatus == 'read' ? Colors.blue : Colors.grey.shade500,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      {'sent': 'Sent', 'delivered': 'Delivered', 'read': 'Read'}[_c.waTickStatus]!,
                      style: TextStyle(
                        fontSize: 11,
                        color: _c.waTickStatus == 'read' ? Colors.blue : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _dateLabel(DateTime d) {
    final days = DateTime.now().difference(d).inDays;
    if (days <= 0) return 'today';
    if (days == 1) return 'yesterday';
    return '$days days ago';
  }

  Widget _figure(String label, String value, {Color? color}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          const SizedBox(height: 3),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _cardSection() {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 3 / 4,
            child: Container(
              color: Colors.grey.shade100,
              child: Image.network(
                _card!.cardUrl,
                fit: BoxFit.contain,
                loadingBuilder: (_, child, progress) =>
                    progress == null ? child : const Center(child: CircularProgressIndicator()),
                errorBuilder: (_, _, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.image_not_supported_outlined,
                          color: Colors.grey.shade400, size: 40),
                      const SizedBox(height: 8),
                      Text('Card preview unavailable',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _shareCard,
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('Share card'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Share the link only',
                  onPressed: _busy ? null : _shareLinkOnly,
                  icon: const Icon(Icons.link),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentsSection() {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Malipo (${_c.payments.length})',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (_c.payments.isEmpty)
              Text('Nothing paid yet.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600))
            else
              ..._c.payments.map((p) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(money(p.amount, p.currency),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text(
                      [
                        p.method,
                        if (p.reference != null && p.reference!.isNotEmpty) p.reference!,
                        if (p.paidAt != null)
                          '${p.paidAt!.day}/${p.paidAt!.month}/${p.paidAt!.year}',
                      ].join(' · '),
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.delete_outline, size: 20, color: Colors.red.shade400),
                      onPressed: _busy ? null : () => _deletePayment(p),
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet for booking a payment — defaults to the outstanding balance,
/// which is what the treasurer is usually entering.
class _PaymentSheet extends StatefulWidget {
  final Contributor contributor;

  const _PaymentSheet({required this.contributor});

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  late final TextEditingController _amount;
  final _reference = TextEditingController();
  String _method = 'mpesa';
  bool _saving = false;
  String? _error;

  static const _methods = <String, String>{
    'mpesa': 'M-Pesa',
    'tigopesa': 'Mixx (Tigo Pesa)',
    'airtelmoney': 'Airtel Money',
    'halopesa': 'HaloPesa',
    'azampesa': 'Azam Pesa',
    'bank': 'Bank',
    'cash': 'Cash',
    'other': 'Other',
  };

  @override
  void initState() {
    super.initState();
    final balance = widget.contributor.balance;
    _amount = TextEditingController(text: balance > 0 ? balance.toStringAsFixed(0) : '');
  }

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amount.text.replaceAll(RegExp(r'[^0-9.]'), ''));

    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter the amount paid.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final updated = await ContributionsApi.recordPayment(
        widget.contributor.id,
        amount: amount,
        method: _method,
        reference: _reference.text,
      );
      if (mounted) Navigator.pop(context, updated);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Record a payment', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            widget.contributor.balance > 0
                ? 'Outstanding: ${money(widget.contributor.balance, widget.contributor.currency)}'
                : 'Their promise is already fulfilled.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Amount', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _method,
            decoration: const InputDecoration(labelText: 'Method', border: OutlineInputBorder()),
            items: _methods.entries
                .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            onChanged: (v) => setState(() => _method = v ?? 'mpesa'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _reference,
            decoration: const InputDecoration(
              labelText: 'Reference (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Record'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet for correcting a contributor's details or their promise.
class _EditSheet extends StatefulWidget {
  final Contributor contributor;

  const _EditSheet({required this.contributor});

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _group;
  late final TextEditingController _amount;
  late final TextEditingController _notes;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final c = widget.contributor;
    _name = TextEditingController(text: c.name);
    _phone = TextEditingController(text: c.phoneNumber);
    _group = TextEditingController(text: c.group ?? '');
    _amount = TextEditingController(text: c.hasPromised ? c.amount!.toStringAsFixed(0) : '');
    _notes = TextEditingController(text: c.notes ?? '');
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _group, _amount, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _phone.text.trim().isEmpty) {
      setState(() => _error = 'Name and phone number are required.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final raw = _amount.text.replaceAll(RegExp(r'[^0-9.]'), '');

      final updated = await ContributionsApi.update(
        widget.contributor.id,
        name: _name.text.trim(),
        phoneNumber: _phone.text.trim(),
        group: _group.text.trim(),
        amount: raw.isEmpty ? null : double.tryParse(raw),
        notes: _notes.text.trim(),
      );

      if (mounted) Navigator.pop(context, updated);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Edit contributor', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 14),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration:
                  const InputDecoration(labelText: 'Phone number', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _group,
              decoration: const InputDecoration(
                  labelText: 'Group (optional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount promised',
                helperText: 'Leave empty if they have not promised yet',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _notes,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder()),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
