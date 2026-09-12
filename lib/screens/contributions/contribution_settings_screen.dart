import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../api/contributions_api.dart';
import '../../models/contribution_models.dart';

/// Contribution round setup: what the card asks for, where the money goes, and
/// the copy that goes out with it.
///
/// The card *design* is not here — uploading and positioning it needs a big
/// canvas, so it stays on the web dashboard.
class ContributionSettingsScreen extends StatefulWidget {
  final int eventId;

  const ContributionSettingsScreen({super.key, required this.eventId});

  @override
  State<ContributionSettingsScreen> createState() => _ContributionSettingsScreenState();
}

class _ContributionSettingsScreenState extends State<ContributionSettingsScreen> {
  ContributionSettings? _s;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  bool _changed = false;

  final _target = TextEditingController();
  final _minAmount = TextEditingController();
  final _appeal = TextEditingController();
  final _kikaoDate = TextEditingController();
  final _kikaoTime = TextEditingController();
  final _kikaoVenue = TextEditingController();

  final _sms = TextEditingController();
  final _whatsapp = TextEditingController();
  final _reminder = TextEditingController();
  final _templateName = TextEditingController();
  final _bodyParam = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _target, _minAmount, _appeal, _kikaoDate, _kikaoTime, _kikaoVenue,
      _sms, _whatsapp, _reminder, _templateName, _bodyParam,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final s = await ContributionsApi.settings(widget.eventId);
      if (!mounted) return;

      _target.text = s.target == null ? '' : s.target!.toStringAsFixed(0);
      _minAmount.text = s.minAmount == null ? '' : s.minAmount!.toStringAsFixed(0);
      _appeal.text = s.appealText;
      _kikaoDate.text = s.kikaoDate;
      _kikaoTime.text = s.kikaoTime;
      _kikaoVenue.text = s.kikaoVenue;
      _sms.text = s.smsMessage;
      _whatsapp.text = s.whatsappMessage;
      _reminder.text = s.reminderMessage;
      _templateName.text = s.whatsappTemplateName;
      _bodyParam.text = s.whatsappBodyParamName;

      setState(() {
        _s = s;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  double? _num(TextEditingController c) {
    final raw = c.text.replaceAll(RegExp(r'[^0-9.]'), '');
    return raw.isEmpty ? null : double.tryParse(raw);
  }

  Future<void> _save() async {
    final s = _s;
    if (s == null) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    s.target = _num(_target);
    s.minAmount = _num(_minAmount);
    s.appealText = _appeal.text.trim();
    s.kikaoDate = _kikaoDate.text.trim();
    s.kikaoTime = _kikaoTime.text.trim();
    s.kikaoVenue = _kikaoVenue.text.trim();
    s.smsMessage = _sms.text.trim();
    s.whatsappMessage = _whatsapp.text.trim();
    s.reminderMessage = _reminder.text.trim();
    s.whatsappTemplateName = _templateName.text.trim();
    s.whatsappBodyParamName = _bodyParam.text.trim();

    try {
      await ContributionsApi.saveSettings(widget.eventId, s);
      await ContributionsApi.saveMessages(widget.eventId, s);

      if (!mounted) return;
      _changed = true;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Settings saved.')));
      setState(() => _saving = false);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Contribution settings'),
          actions: [
            if (!_loading && s != null)
              TextButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save', style: TextStyle(color: Colors.white)),
              ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : s == null
                ? _errorView()
                : ListView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
                    children: [
                      if (_error != null) _errorBanner(),
                      if (!s.hasCardDesign) _noDesignWarning(),
                      _roundSection(s),
                      _paymentSection(s),
                      _committeeSection(s),
                      _messagesSection(s),
                      _linkSection(s),
                    ],
                  ),
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 46, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(_error ?? 'Could not load the settings', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }

  Widget _errorBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Text(_error!, style: TextStyle(color: Colors.red.shade800, fontSize: 13)),
    );
  }

  Widget _noDesignWarning() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: const Text(
        'No contribution card design yet. Upload and position it on the web dashboard — '
        'cards cannot be sent until that is done.',
        style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
      ),
    );
  }

  Widget _section(String title, List<Widget> children, {String? subtitle}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            if (subtitle != null) ...[
              const SizedBox(height: 3),
              Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label,
      {String? hint, int maxLines = 1, TextInputType? keyboard, String? helper}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        maxLines: maxLines,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          helperText: helper,
          helperMaxLines: 3,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  Widget _roundSection(ContributionSettings s) {
    return _section(
      'The round',
      [
        DropdownButtonFormField<String>(
          value: s.status,
          decoration: const InputDecoration(
              labelText: 'Status', border: OutlineInputBorder(), isDense: true),
          items: const [
            DropdownMenuItem(value: 'draft', child: Text('Draft — not collecting yet')),
            DropdownMenuItem(value: 'open', child: Text('Open — accepting contributions')),
            DropdownMenuItem(value: 'closed', child: Text('Closed — no new pledges')),
          ],
          onChanged: (v) => setState(() => s.status = v ?? 'draft'),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: s.mode,
          decoration: const InputDecoration(
              labelText: 'What the card asks for', border: OutlineInputBorder(), isDense: true),
          items: const [
            DropdownMenuItem(value: 'direct', child: Text('A contribution')),
            DropdownMenuItem(value: 'kikao', child: Text('Attending a kikao')),
          ],
          onChanged: (v) => setState(() => s.mode = v ?? 'direct'),
        ),
        const SizedBox(height: 10),
        _field(_target, 'Target amount', keyboard: TextInputType.number),
        _field(_minAmount, 'Minimum pledge', keyboard: TextInputType.number),
        _deadlineField(s),
        _field(_appeal, 'Appeal text', maxLines: 4, helper: 'Shown on the contribute page.'),
        if (s.isKikao) ...[
          const Divider(height: 20),
          Text('Kikao details',
              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.amber.shade900)),
          const SizedBox(height: 10),
          _field(_kikaoDate, 'Tarehe', hint: '12 Oktoba 2026'),
          _field(_kikaoTime, 'Muda', hint: '14:00'),
          _field(_kikaoVenue, 'Mahali'),
        ],
      ],
    );
  }

  Widget _deadlineField(ContributionSettings s) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () async {
          final now = DateTime.now();
          final picked = await showDatePicker(
            context: context,
            initialDate: DateTime.tryParse(s.deadline ?? '') ?? now.add(const Duration(days: 30)),
            firstDate: now.subtract(const Duration(days: 365)),
            lastDate: now.add(const Duration(days: 365 * 3)),
          );
          if (picked != null) {
            setState(() => s.deadline = picked.toIso8601String().split('T').first);
          }
        },
        child: InputDecorator(
          decoration: const InputDecoration(
              labelText: 'Deadline', border: OutlineInputBorder(), isDense: true),
          child: Row(
            children: [
              Expanded(child: Text(s.deadline ?? 'Not set')),
              if (s.deadline != null)
                GestureDetector(
                  onTap: () => setState(() => s.deadline = null),
                  child: const Icon(Icons.clear, size: 18),
                )
              else
                const Icon(Icons.calendar_today, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _paymentSection(ContributionSettings s) {
    return _section(
      'Payment numbers',
      subtitle: 'Printed on the card and shown on the contribute page.',
      [
        ...s.paymentMethods.asMap().entries.map((e) => _repeaterRow(
              onRemove: () => setState(() => s.paymentMethods.removeAt(e.key)),
              children: [
                _inline(e.value.label, 'Label', 'M-Pesa', (v) => e.value.label = v),
                _inline(e.value.number, 'Number', '0754 000 000', (v) => e.value.number = v,
                    keyboard: TextInputType.phone),
                _inline(e.value.name, 'Account name', 'Kamati', (v) => e.value.name = v),
              ],
            )),
        TextButton.icon(
          onPressed: () => setState(() => s.paymentMethods.add(PaymentMethod())),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add a number'),
        ),
      ],
    );
  }

  Widget _committeeSection(ContributionSettings s) {
    return _section(
      'Kamati contacts',
      [
        ...s.committeeContacts.asMap().entries.map((e) => _repeaterRow(
              onRemove: () => setState(() => s.committeeContacts.removeAt(e.key)),
              children: [
                _inline(e.value.role, 'Role', 'Mwenyekiti', (v) => e.value.role = v),
                _inline(e.value.name, 'Name', '', (v) => e.value.name = v),
                _inline(e.value.phone, 'Phone', '0754 000 000', (v) => e.value.phone = v,
                    keyboard: TextInputType.phone),
              ],
            )),
        TextButton.icon(
          onPressed: () => setState(() => s.committeeContacts.add(CommitteeContact())),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add a contact'),
        ),
      ],
    );
  }

  Widget _repeaterRow({required List<Widget> children, required VoidCallback onRemove}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(10, 10, 4, 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          ...children,
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline, size: 16),
              label: const Text('Remove'),
              style: TextButton.styleFrom(foregroundColor: Colors.red.shade600),
            ),
          ),
        ],
      ),
    );
  }

  /// Repeater fields keep their value in the model rather than a controller —
  /// rows are added and removed, so controllers would have to be juggled.
  Widget _inline(String value, String label, String hint, ValueChanged<String> onChanged,
      {TextInputType? keyboard}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 6),
      child: TextFormField(
        initialValue: value,
        onChanged: onChanged,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint.isEmpty ? null : hint,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  Widget _messagesSection(ContributionSettings s) {
    return _section(
      'Messages',
      subtitle: 'Placeholders: {name} {event} {link} {amount} {balance} {payment_details}',
      [
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: const Text(
            'WhatsApp only lets you message someone who wrote to you in the last 24 hours. '
            'Contribution cards go to people who never have, so an approved template is '
            'required — without one, only recently-active contacts will receive a card.',
            style: TextStyle(fontSize: 11.5, color: Color(0xFF92400E), height: 1.35),
          ),
        ),
        _field(_templateName, 'Approved template name', hint: 'contribution_card'),
        _field(_bodyParam, 'Body variable name',
            hint: 'contributor_name', helper: 'Leave blank for positional templates.'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: s.whatsappHasBodyParam,
          onChanged: (v) => setState(() => s.whatsappHasBodyParam = v),
          title: const Text('Template body has a variable for their name',
              style: TextStyle(fontSize: 13)),
        ),
        const Divider(height: 20),
        _field(_whatsapp, 'WhatsApp caption', maxLines: 4,
            helper: 'Used within the 24-hour window.'),
        _field(_sms, 'SMS message', maxLines: 4,
            helper: 'For contacts not on WhatsApp. Include {link}.'),
        _field(_reminder, 'Reminder message', maxLines: 4,
            helper: 'For chasing unpaid promises. {balance} is usually what you want.'),
      ],
    );
  }

  Widget _linkSection(ContributionSettings s) {
    if (s.generalLink.isEmpty) return const SizedBox.shrink();

    return _section(
      'Open contribution link',
      subtitle: 'Share this in a WhatsApp group. Anyone who opens it can pledge.',
      [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(s.generalLink, style: const TextStyle(fontSize: 12)),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: s.generalLink));
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('Link copied.')));
                },
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
