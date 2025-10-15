import 'package:aj_events/screens/create_event_screen.dart';
import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:aj_events/theme.dart';
import 'package:aj_events/event_screen.dart';
import 'package:aj_events/api_service.dart';
import 'package:aj_events/main_layout.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List> _eventsFuture;
  String _searchQuery = '';
  final InAppUpdate _inAppUpdate = InAppUpdate();
  AppUpdateInfo? _updateInfo;

  // For iOS, we'll use these constants
  final String _appStoreId = '1450874784'; // Replace with your actual App Store ID
  final String _appStoreUrl = 'https://apps.apple.com/app/id1450874784'; // Replace with your actual App Store URL

  @override
  void initState() {
    super.initState();
    _eventsFuture = ApiService.fetchEvents();
    checkForUpdate();
  }

  Future<void> checkForUpdate() async {
    try {
      if (Platform.isAndroid) {
        await _checkForAndroidUpdate();
      } else if (Platform.isIOS) {
        await _checkForIOSUpdate();
      }
    } catch (e) {
      // Handle exceptions
      debugPrint('Update check error: $e');
    }
  }

  Future<void> _checkForAndroidUpdate() async {
    try {
      _updateInfo = await InAppUpdate.checkForUpdate();
      if (_updateInfo?.updateAvailability == UpdateAvailability.updateAvailable) {
        if (_updateInfo?.immediateUpdateAllowed == true) {
          // Immediate update
          InAppUpdate.performImmediateUpdate().catchError((e) {
            _handleUpdateError(e);
          });
        } else if (_updateInfo?.flexibleUpdateAllowed == true) {
          // Flexible update
          InAppUpdate.startFlexibleUpdate().then((_) {
            InAppUpdate.completeFlexibleUpdate().then((_) {
              Fluttertoast.showToast(
                msg: "App updated successfully!",
                toastLength: Toast.LENGTH_LONG,
              );
            }).catchError((e) {
              _handleUpdateError(e);
            });
          }).catchError((e) {
            _handleUpdateError(e);
          });
        }
      }
    } catch (e) {
      _handleUpdateError(e);
    }
  }

  void _handleUpdateError(dynamic e) {
    debugPrint('Android in-app update error: $e');

    // Don't show errors to users during development or when app is not from Play Store
    if (e.toString().contains('ERROR_APP_NOT_OWNED') || 
        e.toString().contains('The app is not owned by any user')) {
      // This is expected during development or when app is sideloaded
      // Just log it and don't show to the user
      debugPrint('App not installed from Play Store, skipping update check');
      return;
    }

    // For other errors, show a toast to the user
    Fluttertoast.showToast(
      msg: "Update check failed. Please try again later.",
      toastLength: Toast.LENGTH_LONG,
    );
  }

  Future<void> _checkForIOSUpdate() async {
    try {
      // Get current app info
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final String currentVersion = packageInfo.version;

      // In a real app, you would check with your server if there's a new version
      // For this example, we'll simulate an update is available
      // You should replace this with actual version checking logic
      bool updateAvailable = true; // This should be determined by comparing versions

      if (updateAvailable) {
        // Show update dialog
        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Update Available'),
              content: const Text('A new version of the app is available. Would you like to update now?'),
              actions: <Widget>[
                TextButton(
                  child: const Text('Later'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: const Text('Update'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    _launchAppStore();
                  },
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      debugPrint('iOS update check error: $e');
    }
  }

  Future<void> _launchAppStore() async {
    final Uri url = Uri.parse(_appStoreUrl);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        Fluttertoast.showToast(
          msg: "Could not launch App Store",
          toastLength: Toast.LENGTH_LONG,
        );
      }
    } catch (e) {
      debugPrint('Error launching App Store: $e');
    }
  }

  Future<void> _refreshEvents() async {
    setState(() {
      _eventsFuture = ApiService.fetchEvents();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      title: 'Your Events',
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSearchBar(),
              const SizedBox(height: 10),
              Expanded(
                child: FutureBuilder<List>(
                  future: _eventsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return _buildSkeletonLoader();
                    } else if (snapshot.hasError) {
                      return _buildErrorState();
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return _buildEmptyState();
                    }

                    final events = snapshot.data!
                        .where((event) =>
                    event['title']
                        ?.toString()
                        .toLowerCase()
                        .contains(_searchQuery.toLowerCase()) ??
                        false)
                        .toList();

                    if (events.isEmpty) {
                      return _buildEmptySearchState();
                    }

                    return RefreshIndicator(
                      onRefresh: _refreshEvents,
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: events.length,
                        itemBuilder: (context, index) {
                          return _buildEventCard(events[index]);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateEventScreen()),
          );
          if (result == true) _refreshEvents();
        },
        backgroundColor: primaryColor,
        tooltip: 'Create Event',
        child: const Icon(
          Icons.add,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Search events...',
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Colors.grey.shade100,
        contentPadding: const EdgeInsets.symmetric(vertical: 0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      onChanged: (val) => setState(() => _searchQuery = val),
    );
  }

  Widget _buildEventCard(Map event) {
    String eventName = event['title']?.toString().trim() ?? 'Unnamed Event';
    String date = event['date'] ?? '';
    String location = event['location'] ?? '';
    int eventId = event['id'] ?? -1;

    String formattedDate = '';
    try {
      if (date.isNotEmpty) {
        final parsedDate = DateTime.parse(date);
        formattedDate = DateFormat('EEE, MMM d, y').format(parsedDate);
      }
    } catch (_) {}

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding:
        const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        leading: Hero(
          tag: 'event-$eventId',
          child: CircleAvatar(
            radius: 24,
            backgroundColor: accentColor,
            foregroundColor: Colors.white,
            child: Text(
              eventName.isNotEmpty ? eventName[0].toUpperCase() : '?',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ),
        title: Text(
          eventName,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (formattedDate.isNotEmpty)
              Text('📅 $formattedDate', style: const TextStyle(fontSize: 14)),
            if (location.isNotEmpty)
              Text('📍 $location', style: const TextStyle(fontSize: 14)),
          ],
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 18,
          color: secondaryColor.withOpacity(0.8),
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EventScreen(eventId: eventId),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return ListView.builder(
      itemCount: 5,
      itemBuilder: (context, index) {
        return Card(
          elevation: 3,
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar shimmer
                Shimmer.fromColors(
                  baseColor: Colors.grey.shade300,
                  highlightColor: Colors.grey.shade100,
                  child: const CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                // Text placeholders shimmer
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title placeholder
                      Shimmer.fromColors(
                        baseColor: Colors.grey.shade300,
                        highlightColor: Colors.grey.shade100,
                        child: Container(
                          height: 18,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Date placeholder
                      Shimmer.fromColors(
                        baseColor: Colors.grey.shade300,
                        highlightColor: Colors.grey.shade100,
                        child: Container(
                          height: 14,
                          width: 150,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Location placeholder
                      Shimmer.fromColors(
                        baseColor: Colors.grey.shade300,
                        highlightColor: Colors.grey.shade100,
                        child: Container(
                          height: 14,
                          width: 100,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.event_busy, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text('No events available', style: TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildEmptySearchState() {
    return const Center(
      child: Text(
        'No events match your search',
        style: TextStyle(fontSize: 16, color: Colors.grey),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.error_outline, size: 80, color: Colors.redAccent),
          SizedBox(height: 16),
          Text('Failed to load events', style: TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}
