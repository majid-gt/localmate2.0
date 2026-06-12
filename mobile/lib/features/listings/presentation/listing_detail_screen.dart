import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/dio_client.dart';

class ListingDetailScreen extends StatefulWidget {
  final String listingId;
  const ListingDetailScreen({super.key, required this.listingId});

  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  final _dio = DioClient().dio;
  Map<String, dynamic>? _listing;
  List<dynamic> _reviews = [];
  bool _isLoading = true;
  bool _isSaved = false;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkLoginAndFetchDetails();
  }

  Future<void> _checkLoginAndFetchDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    _isLoggedIn = token != null;
    
    await _fetchDetails();
    if (_isLoggedIn) {
      await _checkIfSaved();
    }
  }

  Future<void> _fetchDetails() async {
    try {
      final response = await _dio.get("/listings/${widget.listingId}");
      if (response.statusCode == 200) {
        setState(() {
          _listing = response.data;
        });
      }
      
      final reviewsResp = await _dio.get("/reviews/listings/${widget.listingId}");
      if (reviewsResp.statusCode == 200) {
        setState(() {
          _reviews = reviewsResp.data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching details: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkIfSaved() async {
    try {
      final response = await _dio.get("/saved-listings/");
      if (response.statusCode == 200) {
        final List saved = response.data;
        final alreadySaved = saved.any((item) => item['id'] == widget.listingId);
        setState(() => _isSaved = alreadySaved);
      }
    } catch (_) {}
  }

  Future<void> _toggleSave() async {
    if (!_isLoggedIn) {
      context.push('/login').then((_) => _checkLoginAndFetchDetails());
      return;
    }

    try {
      if (_isSaved) {
        await _dio.delete("/saved-listings/${widget.listingId}");
        setState(() => _isSaved = false);
      } else {
        await _dio.post("/saved-listings/${widget.listingId}");
        setState(() => _isSaved = true);
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to update bookmark status.")),
      );
    }
  }

  void _addReviewDialog() {
    if (!_isLoggedIn) {
      context.push('/login').then((_) => _checkLoginAndFetchDetails());
      return;
    }

    double selectedRating = 5.0;
    final TextEditingController commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Write a Review"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final ratingValue = index + 1.0;
                  return IconButton(
                    icon: Icon(
                      selectedRating >= ratingValue ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 36,
                    ),
                    onPressed: () => setDialogState(() => selectedRating = ratingValue),
                  );
                }),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: commentController,
                maxLines: 2,
                decoration: const InputDecoration(hintText: "Add your comment here..."),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              child: const Text("Submit"),
              onPressed: () async {
                try {
                  await _dio.post("/reviews/listings/${widget.listingId}", data: {
                    "rating": selectedRating.toInt(),
                    "comment": commentController.text.trim(),
                  });
                  Navigator.pop(context);
                  _fetchDetails();
                } catch (_) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Error submitting review.")),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_listing == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text("Listing not found")),
      );
    }

    final listing = _listing!;
    final avgRating = listing['average_rating'] ?? 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(listing['name']),
        actions: [
          IconButton(
            icon: Icon(_isSaved ? Icons.bookmark : Icons.bookmark_border_outlined, color: const Color(0xFF6366F1)),
            onPressed: _toggleSave,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Section (Main Details Card)
            Container(
              color: Colors.grey.shade50,
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          listing['category']['name'] ?? '',
                          style: const TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (avgRating > 0.0)
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 20),
                            const SizedBox(width: 4),
                            Text("$avgRating / 5.0", style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    listing['name'],
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    listing['description'] ?? 'No description provided.',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 16),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Provider Information", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.person, color: Color(0xFF6366F1)),
                    title: Text(listing['owner_name']),
                    subtitle: const Text("Owner"),
                    trailing: IconButton(
                      icon: const Icon(Icons.call, color: Colors.green),
                      onPressed: () {
                        // In real device, launch url: tel:${listing['owner_phone']}
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Calling owner: ${listing['owner_phone']}")),
                        );
                      },
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.location_on, color: Color(0xFF6366F1)),
                    title: Text(listing['address']),
                    subtitle: Text("Lat: ${listing['latitude']}, Lng: ${listing['longitude']}"),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.access_time, color: Color(0xFF6366F1)),
                    title: Text(listing['working_hours']),
                    subtitle: const Text("Working Hours"),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Contributor Row
                  if (listing['contributor'] != null) ...[
                    const Text("Recommended By", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(child: Icon(Icons.face)),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(listing['contributor']['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                              const Text("Local Resident Contributor"),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),
                  
                  // Reviews Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("User Reviews", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      TextButton.icon(
                        icon: const Icon(Icons.rate_review_outlined),
                        label: const Text("Write Review"),
                        onPressed: _addReviewDialog,
                      ),
                    ],
                  ),
                  const Divider(),
                  
                  if (_reviews.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Center(child: Text("No reviews yet. Share your experience!")),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _reviews.length,
                      itemBuilder: (context, index) {
                        final rev = _reviews[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(rev['author']?['name'] ?? 'Anonymous', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  const Spacer(),
                                  Row(
                                    children: List.generate(5, (starIdx) {
                                      return Icon(
                                        starIdx < rev['rating'] ? Icons.star : Icons.star_border,
                                        color: Colors.amber,
                                        size: 16,
                                      );
                                    }),
                                  ),
                                ],
                              ),
                              if (rev['comment'] != null && rev['comment'].isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(rev['comment'], style: TextStyle(color: Colors.grey.shade700)),
                              ],
                              const Divider(height: 16),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
