import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/contributions_api.dart';
import '../../models/contribution_models.dart';
import '../../widgets/contributions/contribution_widgets.dart';

/// Add contributors by typing them, one per line.
///
/// Order does not matter — the server works out which token is a phone number
/// and which is an amount — so this screen's job is to show, live, exactly what
/// it understood before anything is saved.
class AddContributorsScreen extends StatefulWidget {
  final int eventId;

  const AddContributorsScreen({super.key, required this.eventId});

  @override
  State<AddContributorsScreen> createState() => _AddContributorsScreenState();
}

class _AddContributorsScreenState extends State<AddContributorsScreen> {
  final _controller = TextEditingController();

  List<ParsedLine> _rows = [];
  Timer? _debounce;
  bool _parsing = false;
  bool _saving = false;
  String? _error;

  int get _ready => _rows.where((r) => r.isReady).length;
  int get _skipped => _rows.length - _ready;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();

    if (text.trim().isEmpty) {
      setState(() {
        _rows = [];
        _error = null;
      });
      return;
    }

    setState(() => _parsing = true);
    _debounce = Timer(const Duration(milliseconds: 400), _parse);
  }

  Future<void> _parse() async {
    try {
      final rows = await ContributionsApi.parseLines(widget.eventId, _controller.text);
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _parsing = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _parsing = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final message = await ContributionsApi.addMany(widget.eventId, _controller.text);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add contributors')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _help(),
                const SizedBox(height: 10),
                TextField(
                  controller: _controller,
                  onChanged: _onChanged,
                  maxLines: 8,
                  minLines: 5,
                  autofocus: true,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'Asha Juma 0754 000 000 50,000\n'
                        '0713111222, Juma Hassan, 120000\n'
                        'Neema Paul 0765000003',
                    hintStyle: TextStyle(fontFamily: 'monospace', fontSize: 13),
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(_error!,
                        style: TextStyle(color: Colors.red.shade800, fontSize: 13)),
                  ),
                ],
                const SizedBox(height: 14),
                _preview(),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: (_ready == 0 || _saving) ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(_ready == 0
                          ? 'Nothing to add yet'
                          : 'Add $_ready contributor${_ready == 1 ? '' : 's'}'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _help() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, size: 16, color: Colors.blue.shade700),
              const SizedBox(width: 6),
              Text('One person per line',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13, color: Colors.blue.shade900)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Name, phone number and the amount promised. Order does not matter, and '
            'commas are optional. Leave the amount out for anyone who has not promised yet. '
            'Shorthand works: 75k, 1.5m, 50,000.',
            style: TextStyle(fontSize: 12, color: Colors.blue.shade900, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _preview() {
    if (_parsing && _rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text('What the system reads will appear here.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('$_ready ready',
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF047857))),
            if (_skipped > 0) ...[
              const SizedBox(width: 12),
              Text('$_skipped need attention',
                  style: const TextStyle(fontSize: 13, color: Color(0xFFB45309))),
            ],
            const Spacer(),
            if (_parsing)
              const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2)),
          ],
        ),
        const SizedBox(height: 8),
        ..._rows.map(_row),
      ],
    );
  }

  Widget _row(ParsedLine r) {
    final ok = r.isReady;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: ok ? Colors.white : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ok ? Colors.grey.shade200 : const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle : Icons.error_outline,
              size: 17, color: ok ? const Color(0xFF047857) : const Color(0xFFB45309)),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.name ?? '(no name)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: r.name == null ? const Color(0xFFB45309) : null,
                    )),
                const SizedBox(height: 1),
                Text(
                  [
                    r.phoneNumber ?? 'no phone number',
                    if (r.group != null && r.group!.isNotEmpty) r.group!,
                    if (r.amount != null) money(r.amount),
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
                if (!ok && r.reason != null) ...[
                  const SizedBox(height: 2),
                  Text(r.reason!,
                      style: const TextStyle(fontSize: 11, color: Color(0xFFB45309))),
                ],
              ],
            ),
          ),
          Text('${r.line}', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
        ],
      ),
    );
  }
}
