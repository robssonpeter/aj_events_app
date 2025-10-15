import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:aj_events/theme.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final InAppUpdate _inAppUpdate = InAppUpdate();
  AppUpdateInfo? _updateInfo;

  // For iOS, we'll use these constants
  final String _appStoreId = 'YOUR_APP_STORE_ID'; // Replace with your actual App Store ID
  final String _appStoreUrl = 'https://apps.apple.com/app/idYOUR_APP_STORE_ID'; // Replace with your actual App Store URL

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo image
                Image.asset(
                  'assets/logo.png',
                  width: 100,
                  height: 100,
                ),
                const SizedBox(height: 32),

                // App title
                const Text(
                  'Welcome to AJ Events',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 12),

                // Subtitle
                const Text(
                  'Access your event with a code, or login to manage all your events.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                  ),
                ),

                const SizedBox(height: 48),

                // Enter Event Code button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.lock_open),
                    label: const Text('Enter Event Code'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(fontSize: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pushNamed(context, '/event-code');
                    },
                  ),
                ),
                const SizedBox(height: 20),

                // Login button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.login, color: primaryColor),
                    label: const Text(
                      'Login to View All Events',
                      style: TextStyle(color: primaryColor),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: primaryColor),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(fontSize: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pushNamed(context, '/login');
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
