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

    // Everything here talks to a native platform channel, so wrap the whole
    // thing — a permission-request failure (e.g. the native plugin isn't
    // registered in this build) must still clear _loading, or the spinner
    // spins forever with no way for the user to know what happened.
    try {
      final status = await FlutterContacts.permissions.request(PermissionType.read);

      if (status != PermissionStatus.granted && status != PermissionStatus.limited) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'Contacts permission was not granted. '
              'Enable it in your phone\'s Settings to import from your phone book.';
        });
        return;
      }

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
        _error = e.toString().contains('MissingPluginException')
            ? 'Contacts import isn\'t available in this build yet — it needs a full '
                'rebuild (not just a hot reload/restart) after being added. Please '
                'do a clean rebuild and try again.'
            : 'Could not read your contacts: $e';
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

  Future<void> _confirm() async {
    final picked = _all
        .where((c) => _selectedIds.contains(c.id))
        .map((c) => PickedContact(
              name: (c.displayName ?? '').trim().isEmpty ? c.phones.first.number : c.displayName!,
              phone: c.phones.first.number,
            ))
        .toList();

    // A saved contact name is often a nickname ("My Brother") rather than the
    // full name someone wants on the list — let them fix names before this
    // actually leaves the picker. The phone number is left alone; it's
    // already correct, straight from the device.
    final reviewed = await Navigator.of(context).push<List<PickedContact>>(
      MaterialPageRoute(builder: (_) => ContactImportReviewScreen(contacts: picked)),
    );

    if (reviewed == null || !mounted) return;
    Navigator.pop(context, reviewed);
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

/// Shows exactly the contacts the user just selected, letting them rename
/// any of them (e.g. a phone-book nickname like "My Brother" -> a full name)
/// before the import actually happens. Phone numbers are shown but not
/// editable — they're already correct, straight from the device. Backing out
/// (the app-bar back arrow) returns to the picker with the selection intact;
/// "Import" is the only way to finish and hand the final list back.
class ContactImportReviewScreen extends StatefulWidget {
  final List<PickedContact> contacts;

  const ContactImportReviewScreen({super.key, required this.contacts});

  @override
  State<ContactImportReviewScreen> createState() => _ContactImportReviewScreenState();
}

class _ContactImportReviewScreenState extends State<ContactImportReviewScreen> {
  late List<PickedContact> _contacts;

  @override
  void initState() {
    super.initState();
    _contacts = List.of(widget.contacts);
  }

  Future<void> _editName(int index) async {
    final controller = TextEditingController(text: _contacts[index].name);

    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    final trimmed = newName?.trim();
    if (trimmed == null || trimmed.isEmpty) return;

    setState(() {
      _contacts[index] = PickedContact(name: trimmed, phone: _contacts[index].phone);
    });
  }

  void _import() => Navigator.pop(context, _contacts);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Review ${_contacts.length} contact${_contacts.length == 1 ? '' : 's'}'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: _contacts.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final c = _contacts[i];
          return ListTile(
            title: Text(c.name),
            subtitle: Text(c.phone),
            trailing: IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit name',
              onPressed: () => _editName(i),
            ),
            onTap: () => _editName(i),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: _contacts.isEmpty ? null : _import,
              child: Text('Import ${_contacts.length} contact${_contacts.length == 1 ? '' : 's'}'),
            ),
          ),
        ),
      ),
    );
  }
}
