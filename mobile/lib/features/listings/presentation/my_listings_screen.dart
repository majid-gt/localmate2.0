import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_theme.dart';

class MyListingsScreen extends StatefulWidget {
  const MyListingsScreen({super.key});

  @override
  State<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends State<MyListingsScreen> {
  final _dio = DioClient().dio;
  List<dynamic> _myListings = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchMyListings();
  }

  Future<void> _fetchMyListings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _dio.get("/listings/my-listings");
      if (response.statusCode == 200) {
        setState(() {
          _myListings = response.data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = "Failed to fetch listings.";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Connection error. Make sure backend is running.";
        _isLoading = false;
      });
      debugPrint("Error fetching my listings: $e");
    }
  }

  Future<void> _toggleListingStatus(String listingId, String currentStatus) async {
    final nextStatus = currentStatus == "active" ? "disabled" : "active";
    try {
      final response = await _dio.put("/listings/$listingId", data: {
        "status": nextStatus,
      });

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Listing set to $nextStatus successfully!")),
        );
        _fetchMyListings();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to update listing status.")),
      );
      debugPrint("Error toggling status: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Recommendations"),
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
                          onPressed: _fetchMyListings,
                          child: const Text("Retry"),
                        ),
                      ],
                    ),
                  ),
                )
              : _myListings.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.storefront_rounded,
                              size: 80,
                              color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              "No recommendations yet!",
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Help fellow residents discover trusted services by listing them here.",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.add),
                              label: const Text("Recommend Service"),
                              onPressed: () => context.push('/listings/add').then((_) => _fetchMyListings()),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16.0),
                      itemCount: _myListings.length,
                      itemBuilder: (context, index) {
                        final listing = _myListings[index];
                        final isActive = listing['status'] == 'active';
                        final avgRating = listing['average_rating'] ?? 0.0;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 16.0),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => context.push('/listings/${listing['id']}').then((_) => _fetchMyListings()),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      // Status Badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isActive
                                              ? const Color(0xFFDCFCE7)
                                              : const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          isActive ? "Active" : "Disabled",
                                          style: TextStyle(
                                            color: isActive
                                                ? const Color(0xFF166534)
                                                : const Color(0xFF475569),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      // Average Rating badge if any
                                      if (avgRating > 0.0)
                                        Row(
                                          children: [
                                            const Icon(Icons.star, color: Colors.amber, size: 18),
                                            const SizedBox(width: 4),
                                            Text(
                                              "$avgRating",
                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    listing['name'],
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    listing['address'],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: Colors.grey.shade600),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(Icons.phone_iphone_rounded, size: 14, color: Colors.grey.shade500),
                                      const SizedBox(width: 4),
                                      Text(
                                        "Owner: ${listing['owner_phone']}",
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                      ),
                                      const Spacer(),
                                      // Toggle Switch / Action
                                      TextButton.icon(
                                        icon: Icon(
                                          isActive ? Icons.block : Icons.check_circle_outline,
                                          size: 16,
                                          color: isActive ? Colors.orange.shade700 : AppTheme.primaryColor,
                                        ),
                                        label: Text(
                                          isActive ? "Deactivate" : "Activate",
                                          style: TextStyle(
                                            color: isActive ? Colors.orange.shade700 : AppTheme.primaryColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                        onPressed: () => _toggleListingStatus(listing['id'], listing['status']),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
