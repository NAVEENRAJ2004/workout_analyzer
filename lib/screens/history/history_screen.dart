import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/keypoint_model.dart';
import '../../services/local_db_service.dart';
import '../../services/firebase_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:io';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with SingleTickerProviderStateMixin {
  late Future<List<KeypointEntry>> _entriesFuture;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  bool _isConnected = true;

  @override
  void initState() {
    super.initState();
    _entriesFuture = _loadEntries();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();

    _checkConnectivity();
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      _updateConnectivityStatus(results);
    });
  }

  Future<void> _checkConnectivity() async {
    final connectivityResult = await (Connectivity().checkConnectivity());
    _updateConnectivityStatus(connectivityResult);
  }

  void _updateConnectivityStatus(dynamic result) {
    setState(() {
      if (result is List<ConnectivityResult>) {
        _isConnected = !result.contains(ConnectivityResult.none);
      } else if (result is ConnectivityResult) {
        _isConnected = result != ConnectivityResult.none;
      }
    });
  }

  Future<List<KeypointEntry>> _loadEntries() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Future.value([]);
    }

    final localEntries = await LocalDBService.getUserKeypoints(user.uid);

    if (_isConnected) {
      _syncWithFirebase(user.uid);
    }
    
    return localEntries;
  }

  Future<void> _syncWithFirebase(String userId) async {
    try {
      await FirebaseService.syncUserData(userId);
      if (mounted) {
        setState(() {
          _entriesFuture = LocalDBService.getUserKeypoints(userId);
        });
      }
    } catch (e) {
      print('Error syncing data in background: $e');
    }
  }

  Future<void> _deleteEntry(KeypointEntry entry) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Delete Entry'),
            content: const Text('Are you sure you want to delete this entry? This action cannot be undone.'),
            actions: <Widget>[
              TextButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.of(context).pop(false),
              ),
              TextButton(
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          );
        },
      );

      if (confirm == true) {
        await FirebaseService.deleteKeypointEntry(entry.id, user.uid);
        
        await LocalDBService.deleteKeypoint(entry.id);
        
        _loadEntries();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Entry deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting entry: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF084E4A), Color(0xFF0E736D)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Analysis History', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
        ),
        body: user == null
            ? const Center(
                child: Text(
                  'Please log in to view your history',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
              )
            : FutureBuilder<List<KeypointEntry>>(
                future: _entriesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error loading history: ${snapshot.error}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    );
                  }

                  final entries = snapshot.data ?? [];

                  if (entries.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'No analysis history yet',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                            ),
                          ),
                          if (!_isConnected)
                            const Padding(
                              padding: EdgeInsets.only(top: 10.0),
                              child: Text(
                                '(Showing available offline data)',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: entries.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.75,
                    ),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      
                      Widget imageWidget;
                      final bool hasProcessedImageUrl = entry.processedImageUrl != null && entry.processedImageUrl!.isNotEmpty;
                      final bool hasLocalImagePath = entry.imagePath.isNotEmpty && File(entry.imagePath).existsSync();

                      if (_isConnected && hasProcessedImageUrl) {
                        imageWidget = Image.network(entry.processedImageUrl!, fit: BoxFit.cover);
                      } else if (hasLocalImagePath) {
                        imageWidget = Image.file(File(entry.imagePath), fit: BoxFit.cover);
                      } else {
                        imageWidget = Container(
                          color: Colors.grey[300],
                          child: const Icon(
                            Icons.broken_image,
                            color: Colors.grey,
                            size: 50,
                          ),
                        );
                      }

                      return FadeTransition(
                        opacity: _fadeAnimation,
                        child: GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                backgroundColor: Colors.white,
                                title: const Text('Pose Analysis Details'),
                                content: SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: imageWidget,
                                      ),
                                      const SizedBox(height: 12),
                                      const Text('Keypoints JSON:',
                                          style: TextStyle(fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 6),
                                      Text(entry.keypointsJson),
                                    ],
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Close'),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 6,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                                    child: imageWidget,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        entry.timestamp.toString().split('.')[0],
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Keypoints: ${entry.keypointsJson.length} points',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () => _deleteEntry(entry),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.red,
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                          textStyle: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        child: const Text('Delete'),
                                      ),
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
                },
              ),
      ),
    );
  }
}
