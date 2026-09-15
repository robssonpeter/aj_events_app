import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

/// One phone-book entry picked by the user, with its raw phone number as
/// stored on the device — the caller's own name/phone parser (used for both
/// contributors and invitees) already handles any punctuation/spacing/country
/// code, so no cleanup happens here.
class PickedContact {
  final String name;
  final String phone;

  const PickedContact({required this.name, required this.phone});
}

/// Lets the user multi-select people from their phone's contact list, so they
/// don't have to type names and numbers by hand. Only contacts with at least
/// one phone number are shown. Returns the selection via Navigator.pop, or
/// null if the user backed out / permission was refused.
class ContactPickerScreen extends StatefulWidget {
  const ContactPickerScreen({super.key});

  @override
  State<ContactPickerScreen> createState() => _ContactPickerScreenState();
}

class _ContactPickerScreenState extends State<ContactPickerScreen> {
  bool _loading = true;
  String? _error;
  List<Contact> _all = [];
  List<Contact> _filtered = [];
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final status = await FlutterContacts.permissions.request(PermissionType.read);

    if (status != PermissionStatus.granted && status != PermissionStatus.limited) {
      setState(() {
        _loading = false;
        _error = 'Contacts permission was not granted. '
            'Enable it in your phone\'s Settings to import from your phone book.';
      });
      return;
    }

    try {
      final contacts = await FlutterContacts.getAll(properties: {ContactProperty.phone});
      final withPhones = contacts.where((c) => c.id != null && c.phones.isNotEmpty).toList()
        ..sort((a, b) =>
            (a.displayName ?? '').toLowerCase().compareTo((b.displayName ?? '').toLowerCase()));

      if (!mounted) return;
      setState(() {
        _all = withPhones;
        _filtered = withPhones;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not read your contacts: $e';
      });
    }
  }

  void _onSearch(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _all
          : _all.where((c) => (c.displayName ?? '').toLowerCase().contains(q)).toList();
    });
  }

  void _toggle(Contact c) {
    final id = c.id!;
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _confirm() {
    final picked = _all
        .where((c) => _selectedIds.contains(c.id))
        .map((c) => PickedContact(
              name: (c.displayName ?? '').trim().isEmpty ? c.phones.first.number : c.displayName!,
              phone: c.phones.first.number,
            ))
        .toList();
    Navigator.pop(context, picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedIds.isEmpty
            ? 'Import from Contacts'
            : '${_selectedIds.length} selected'),
        actions: [
          if (_selectedIds.isNotEmpty)
            TextButton(
              onPressed: _confirm,
              child: const Text('Confirm',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.contacts_outlined, size: 40, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: _load,
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                      child: TextField(
                        onChanged: _onSearch,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Search contacts',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    Expanded(
                      child: _filtered.isEmpty
                          ? Center(
                              child: Text(
                                _all.isEmpty
                                    ? 'No contacts with a phone number were found.'
                                    : 'No matches.',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _filtered.length,
                              itemBuilder: (context, i) {
                                final c = _filtered[i];
                                final selected = _selectedIds.contains(c.id);
                                return CheckboxListTile(
                                  value: selected,
                                  onChanged: (_) => _toggle(c),
                                  controlAffinity: ListTileControlAffinity.leading,
                                  title: Text((c.displayName ?? '').isEmpty
                                      ? '(no name)'
                                      : c.displayName!),
                                  subtitle: Text(c.phones.first.number),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}
