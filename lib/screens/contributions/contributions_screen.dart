import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/contributions_api.dart';
import '../../models/contribution_models.dart';
import '../../theme.dart';
import '../../widgets/contributions/contribution_widgets.dart';
import 'add_contributors_screen.dart';
import 'contribution_settings_screen.dart';
import 'contributor_detail_screen.dart';

/// The contribution round's home screen: where collection stands, who is on
/// the list, and the bulk actions the kamati runs from a phone.
class ContributionsScreen extends StatefulWidget {
  final int eventId;
  final String? eventTitle;

  const ContributionsScreen({super.key, required this.eventId, this.eventTitle});

  @override
  State<ContributionsScreen> createState() => _ContributionsScreenState();
}

class _ContributionsScreenState extends State<ContributionsScreen> {
  final _searchController = TextEditingController();

  ContributionsPage? _page;
  bool _loading = true;   // very first load — nothing on screen yet
  bool _refetching = false; // a filter or search is fetching over existing data
  String? _error;
  bool _busy = false;

  String _status = '';
  String _group = '';
  Timer? _searchDebounce;

  // Tapping chips quickly fires overlapping requests; on a slow connection an
  // earlier one can land last and show the wrong filter's data. Only the newest
  // request is allowed to write to state.
  int _requestId = 0;

  final Set<int> _selected = {};
  bool get _selectionMode => _selected.isNotEmpty;

  static const _statusFilters = <String, String>{
    '': 'All',
    'pending': 'Not promised',
    'pledged': 'Promised',
    'partial': 'Part paid',
    'paid': 'Fully paid',
    'declined': 'Declined',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// [showSkeleton] is off for pull-to-refresh, which draws its own spinner.
  Future<void> _load({bool showSkeleton = true}) async {
    final requestId = ++_requestId;

    setState(() {
      _loading = _page == null;
      _refetching = showSkeleton && _page != null;
      _error = null;
    });

    try {
      final page = await ContributionsApi.fetch(
        widget.eventId,
        status: _status,
        group: _group,
        search: _searchController.text,
      );

      if (!mounted || requestId != _requestId) return;
      setState(() {
        _page = page;
        _loading = false;
        _refetching = false;
        // Drop anything that filtered out from under the selection.
        _selected.removeWhere((id) => !page.contributors.any((c) => c.id == id));
      });
    } catch (e) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _loading = false;
        _refetching = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), _load);
  }

  void _toggle(int id) {
    setState(() => _selected.contains(id) ? _selected.remove(id) : _selected.add(id));
  }

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? Colors.red.shade700 : null,
      duration: Duration(seconds: error ? 6 : 3),
    ));
  }

  /// Long operations get a blocking spinner — sending cards uploads an image
  /// per contributor and can take a while on a slow connection.
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

  Future<void> _sendCards() async {
    final ids = _selected.toList();
    final ok = await _confirm(
      'Send ${ids.length} card${ids.length == 1 ? '' : 's'}?',
      'Each contributor gets their own card on WhatsApp, or an SMS if they are not on WhatsApp.',
      'Send',
    );
    if (ok != true) return;

    await _run(() async {
      final result = await ContributionsApi.sendCards(widget.eventId, ids);
      _snack(result.message);

      if (result.failed.isNotEmpty) {
        _showFailures(result.failed);
      }

      setState(_selected.clear);
      await _load();
    });
  }

  Future<void> _sendReminders() async {
    final ids = _selected.toList();
    final ok = await _confirm(
      'Remind ${ids.length} contributor${ids.length == 1 ? '' : 's'}?',
      'They will get a message showing what is still outstanding on their promise.',
      'Send',
    );
    if (ok != true) return;

    await _run(() async {
      final message = await ContributionsApi.sendReminders(widget.eventId, ids);
      _snack(message);
      setState(_selected.clear);
      await _load();
    });
  }

  Future<bool?> _confirm(String title, String body, String confirmLabel) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(confirmLabel)),
        ],
      ),
    );
  }

  /// Failures usually share one cause (no template, no SMS body) — show them
  /// in full rather than a count, because the message says how to fix it.
  void _showFailures(List<String> failed) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('${failed.length} could not be sent'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: failed
                .map((f) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(f, style: const TextStyle(fontSize: 13)),
                    ))
                .toList(),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  Future<void> _openAdd() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AddContributorsScreen(eventId: widget.eventId)),
    );
    if (changed == true) _load();
  }

  Future<void> _openSettings() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ContributionSettingsScreen(eventId: widget.eventId)),
    );
    if (changed == true) _load();
  }

  Future<void> _openContributor(Contributor c) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ContributorDetailScreen(eventId: widget.eventId, contributor: c),
      ),
    );
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final page = _page;

    return Scaffold(
      appBar: AppBar(
        title: Text(_selectionMode ? '${_selected.length} selected' : 'Mchango'),
        leading: _selectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(_selected.clear),
              )
            : null,
        actions: _selectionMode
            ? [
                IconButton(
                  tooltip: 'Select all',
                  icon: const Icon(Icons.select_all),
                  onPressed: () => setState(() {
                    _selected.addAll((page?.contributors ?? []).map((c) => c.id));
                  }),
                ),
              ]
            : [
                IconButton(
                  tooltip: 'Settings',
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: _openSettings,
                ),
              ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () => _load(showSkeleton: false),
            child: _buildBody(page),
          ),
          if (_busy)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
      floatingActionButton: _selectionMode
          ? null
          : FloatingActionButton.extended(
              onPressed: _openAdd,
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Add'),
            ),
      bottomNavigationBar: _selectionMode ? _selectionBar() : null,
    );
  }

  Widget _buildBody(ContributionsPage? page) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          ContributionEmptyState(
            icon: Icons.cloud_off,
            title: 'Could not load',
            message: _error!,
            actionLabel: 'Try again',
            onAction: _load,
          ),
        ],
      );
    }

    if (page == null) return const SizedBox.shrink();

    final list = page.contributors;
    final filtering = _status.isNotEmpty || _group.isNotEmpty || _searchController.text.isNotEmpty;

    return Column(
      children: [
        ContributionStatsHeader(stats: page.stats),
        if (!page.canSend) _warning(
          'No contribution card design yet. Upload one on the web dashboard before sending cards.',
        ),
        _filters(page),
        Expanded(
          child: _refetching
              ? const ContributorSkeletonList()
              : list.isEmpty
              ? ListView(
                  children: [
                    const SizedBox(height: 40),
                    filtering
                        ? const ContributionEmptyState(
                            icon: Icons.search_off,
                            title: 'Nobody matches',
                            message: 'Try a different filter or search.',
                          )
                        : ContributionEmptyState(
                            icon: Icons.groups_outlined,
                            title: 'No contributors yet',
                            message:
                                'Add the people you expect to contribute, then send them their cards.',
                            actionLabel: 'Add contributors',
                            onAction: _openAdd,
                          ),
                  ],
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => Divider(height: 1, color: Colors.grey.shade200),
                  itemBuilder: (_, i) {
                    final c = list[i];
                    return ContributorTile(
                      contributor: c,
                      selected: _selected.contains(c.id),
                      selectionMode: _selectionMode,
                      onTap: () => _selectionMode ? _toggle(c.id) : _openContributor(c),
                      onLongPress: () => _toggle(c.id),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _warning(String text) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: Color(0xFF92400E)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFF92400E))),
          ),
        ],
      ),
    );
  }

  Widget _filters(ContributionsPage page) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search name or phone',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _load();
                      },
                    ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              ..._statusFilters.entries.map((e) {
                final count = e.key.isEmpty ? null : page.stats.counts[e.key];
                final label = count == null ? e.value : '${e.value} ($count)';

                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(label, style: const TextStyle(fontSize: 12)),
                    selected: _status == e.key,
                    onSelected: (_) {
                      setState(() => _status = e.key);
                      _load();
                    },
                  ),
                );
              }),
              if (page.groups.isNotEmpty) ...[
                const VerticalDivider(width: 16),
                ...page.groups.map((g) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(g, style: const TextStyle(fontSize: 12)),
                        selected: _group == g,
                        onSelected: (on) {
                          setState(() => _group = on ? g : '');
                          _load();
                        },
                      ),
                    )),
              ],
            ],
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _selectionBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8)],
        ),
        child: Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _busy ? null : _sendCards,
                icon: const Icon(Icons.send, size: 18),
                label: const Text('Send cards'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _sendReminders,
                icon: const Icon(Icons.notifications_none, size: 18),
                label: const Text('Remind'),
                style: OutlinedButton.styleFrom(foregroundColor: primaryColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
