import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_theme.dart';

class SavedListingsScreen extends StatefulWidget {
  const SavedListingsScreen({super.key});

  @override
  State<SavedListingsScreen> createState() => _SavedListingsScreenState();
}

class _SavedListingsScreenState extends State<SavedListingsScreen> {
  final _dio = DioClient().dio;
  List<dynamic> _savedListings = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchSavedListings();
  }

  Future<void> _fetchSavedListings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _dio.get("/saved-listings/");
      if (response.statusCode == 200) {
        setState(() {
          _savedListings = response.data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = "Failed to load saved bookmarks.";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Connection error. Make sure backend is running.";
        _isLoading = false;
      });
      debugPrint("Error fetching saved listings: $e");
    }
  }

  Future<void> _removeBookmark(String listingId, String listingName) async {
    // Optimistic UI update
    final removedItem = _savedListings.firstWhere((item) => item['id'] == listingId);
    final removedIndex = _savedListings.indexOf(removedItem);

    setState(() {
      _savedListings.removeAt(removedIndex);
    });

    try {
      final response = await _dio.delete("/saved-listings/$listingId");
      if (response.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Removed '$listingName' from bookmarks"),
            action: SnackBarAction(
              label: "Undo",
              textColor: AppTheme.secondaryColor,
              onPressed: () async {
                // Re-add bookmark
                try {
                  await _dio.post("/saved-listings/$listingId");
                  // Refresh from server
                  _fetchSavedListings();
                } catch (_) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Failed to restore bookmark.")),
                    );
                  }
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      // Revert optimistic update
      setState(() {
        _savedListings.insert(removedIndex, removedItem);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to remove bookmark. Please try again.")),
        );
      }
      debugPrint("Error removing bookmark: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Saved Bookmarks"),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(_errorMessage!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _fetchSavedListings,
                          child: const Text("Retry"),
                        ),
                      ],
                    ),
                  ),
                )
              : _savedListings.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.bookmark_outline_rounded,
                              size: 80,
                              color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              "No bookmarks yet!",
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Pin your favorite local recommendations to find them here quickly.",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              child: const Text("Browse Services"),
                              onPressed: () => context.go('/'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16.0),
                      itemCount: _savedListings.length,
                      itemBuilder: (context, index) {
                        final listing = _savedListings[index];
                        final avgRating = listing['average_rating'] ?? 0.0;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 16.0),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16.0),
                            leading: const CircleAvatar(
                              radius: 28,
                              backgroundColor: Color(0xFFEEF2F6),
                              child: Icon(Icons.storefront, color: Color(0xFF6366F1)),
                            ),
                            title: Text(
                              listing['name'],
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(listing['address'], maxLines: 1, overflow: TextOverflow.ellipsis),
                                if (avgRating > 0.0) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.star, color: Colors.amber, size: 14),
                                      const SizedBox(width: 4),
                                      Text(
                                        "$avgRating",
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.bookmark, color: AppTheme.primaryColor),
                              onPressed: () => _removeBookmark(listing['id'], listing['name']),
                            ),
                            onTap: () => context.push('/listings/${listing['id']}').then((_) => _fetchSavedListings()),
                          ),
                        );
                      },
                    ),
    );
  }
}
