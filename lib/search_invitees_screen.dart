import 'package:aj_events/common.dart';
import 'package:aj_events/theme.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shimmer/shimmer.dart';
import 'invitee_details_screen.dart';
import 'dart:async';

class SearchInviteesScreen extends StatefulWidget {
  final int eventId;

  const SearchInviteesScreen({super.key, required this.eventId});

  @override
  _SearchInviteesScreenState createState() => _SearchInviteesScreenState();
}

class _SearchInviteesScreenState extends State<SearchInviteesScreen> {
  final TextEditingController _searchController = TextEditingController();
  List _searchResults = [];
  bool _isLoading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();

    _searchController.addListener(() {
      _onSearchChanged(_searchController.text.trim());
    });
  }

  void _onSearchChanged(String query) {
    // Cancel any previous debounce timer that might be running
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    // Set a new timer to delay the search operation by 300ms
    // This prevents excessive API calls while the user is still typing
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _searchInvitees(query);
    });
  }

  Future<void> _searchInvitees(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.get(Uri.parse(
          'https://events.ajiriwa.net/api/search/invitees/${widget.eventId}?name=$query'));

      if (response.statusCode == 200) {
        setState(() {
          _searchResults = json.decode(response.body);
          _isLoading = false;
        });
      } else {
        throw Exception('Search failed');
      }
    } catch (e) {
      setState(() {
        _searchResults = [];
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }


  Future<void> _refreshResults() async {
    // For explicit refresh action, we bypass debounce
    await _searchInvitees(_searchController.text.trim());
  }

  Widget _buildInviteeTile(Map invitee) {
    final bool isRedeemed = invitee['is_redeemed'] == 1;
    final bgColor = isRedeemed ? Colors.green.shade400 : primaryColor;
    final name = invitee['name'] ?? '';
    final initials = name.isNotEmpty
        ? name.trim().split(' ').where((String e) => e.isNotEmpty).map((String e) => e[0]).take(2).join().toUpperCase()
        : 'NA';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        elevation: 3,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            final slug = invitee['slug'];
            if (slug == null || slug.toString().trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Invitee data is incomplete: missing code')),
              );
              return;
            }

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => InviteeDetailsScreen(
                  eventId: widget.eventId,
                  slug: slug.toString(),
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                colors: [bgColor.withOpacity(0.85), bgColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.white,
                  child: Text(
                    initials,
                    style: TextStyle(
                      color: bgColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isRedeemed ? 'Redeemed' : 'Not Redeemed',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildShimmerTile() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: const CircleAvatar(radius: 20, backgroundColor: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Shimmer.fromColors(
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 16, width: 150, color: Colors.white),
                  const SizedBox(height: 8),
                  Container(height: 12, width: 100, color: Colors.white),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return ListView.builder(
        itemCount: 6,
        itemBuilder: (context, index) => _buildShimmerTile(),
      );
    }

    if (_searchResults.isEmpty) {
      return const Center(
        child: Text(
          'No results found',
          style: TextStyle(fontSize: 16, color: Colors.black54),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshResults,
      child: ListView.builder(
        itemCount: _searchResults.length,
        itemBuilder: (context, index) {
          return _buildInviteeTile(_searchResults[index]);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Search Invitees'),
            if (_isLoading) ...[
              const SizedBox(width: 12),
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ],
          ],
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Find an Invitee',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: 'Enter invitee name',
                hintStyle: TextStyle(color: Colors.grey[500]),
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    // No need to manually clear results, the listener will trigger _onSearchChanged
                    // which will handle it through the debounce mechanism
                  },
                ),
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
