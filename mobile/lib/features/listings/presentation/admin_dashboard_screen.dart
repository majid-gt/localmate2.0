import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _dio = DioClient().dio;
  String? _adminSecret;
  bool _isLoading = true;
  String? _errorMessage;

  List<dynamic> _listings = [];
  List<dynamic> _users = [];
  List<dynamic> _reviews = [];

  @override
  void initState() {
    super.initState();
    _loadSecretAndFetchData();
  }

  Future<void> _loadSecretAndFetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final prefs = await SharedPreferences.getInstance();
    _adminSecret = prefs.getString('admin_secret');

    if (_adminSecret == null) {
      setState(() {
        _errorMessage = "Admin secret not found. Please re-authenticate.";
        _isLoading = false;
      });
      return;
    }

    await Future.wait([
      _fetchListings(),
      _fetchUsers(),
      _fetchReviews(),
    ]);

    setState(() => _isLoading = false);
  }

  Future<void> _fetchListings() async {
    try {
      final response = await _dio.get(
        "/admin/listings",
        options: Options(headers: {"x-admin-secret": _adminSecret}),
      );
      if (response.statusCode == 200) {
        setState(() => _listings = response.data);
      }
    } catch (e) {
      debugPrint("Error fetching admin listings: $e");
      setState(() => _errorMessage = "Authorization failed. Check your admin secret.");
    }
  }

  Future<void> _fetchUsers() async {
    try {
      final response = await _dio.get(
        "/admin/users",
        options: Options(headers: {"x-admin-secret": _adminSecret}),
      );
      if (response.statusCode == 200) {
        setState(() => _users = response.data);
      }
    } catch (e) {
      debugPrint("Error fetching admin users: $e");
    }
  }

  Future<void> _fetchReviews() async {
    try {
      final response = await _dio.get(
        "/admin/reviews",
        options: Options(headers: {"x-admin-secret": _adminSecret}),
      );
      if (response.statusCode == 200) {
        setState(() => _reviews = response.data);
      }
    } catch (e) {
      debugPrint("Error fetching admin reviews: $e");
    }
  }

  Future<void> _disableListing(String id) async {
    setState(() => _isLoading = true);
    try {
      final response = await _dio.put(
        "/admin/listings/$id/disable",
        options: Options(headers: {"x-admin-secret": _adminSecret}),
      );
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Listing disabled successfully.")),
          );
        }
        await _fetchListings();
      }
    } catch (e) {
      debugPrint("Error disabling listing: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to disable listing.")),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _disableUser(String id) async {
    setState(() => _isLoading = true);
    try {
      final response = await _dio.put(
        "/admin/users/$id/disable",
        options: Options(headers: {"x-admin-secret": _adminSecret}),
      );
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("User deactivated successfully.")),
          );
        }
        await _fetchUsers();
      }
    } catch (e) {
      debugPrint("Error disabling user: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to deactivate user.")),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _enableUser(String id) async {
    setState(() => _isLoading = true);
    try {
      final response = await _dio.put(
        "/admin/users/$id/enable",
        options: Options(headers: {"x-admin-secret": _adminSecret}),
      );
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("User activated successfully.")),
          );
        }
        await _fetchUsers();
      }
    } catch (e) {
      debugPrint("Error enabling user: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to activate user.")),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _enableListing(String id) async {
    setState(() => _isLoading = true);
    try {
      final response = await _dio.put(
        "/admin/listings/$id/enable",
        options: Options(headers: {"x-admin-secret": _adminSecret}),
      );
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Listing enabled successfully.")),
          );
        }
        await _fetchListings();
      }
    } catch (e) {
      debugPrint("Error enabling listing: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to enable listing.")),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Admin Dashboard"),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.storefront_rounded), text: "Listings"),
              Tab(icon: Icon(Icons.people_rounded), text: "Users"),
              Tab(icon: Icon(Icons.rate_review_rounded), text: "Reviews"),
            ],
          ),
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
                          const Icon(Icons.security_rounded, size: 64, color: Colors.orange),
                          const SizedBox(height: 16),
                          Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadSecretAndFetchData,
                            child: const Text("Retry"),
                          ),
                        ],
                      ),
                    ),
                  )
                : TabBarView(
                    children: [
                      _buildListingsTab(),
                      _buildUsersTab(),
                      _buildReviewsTab(),
                    ],
                  ),
      ),
    );
  }

  Widget _buildListingsTab() {
    if (_listings.isEmpty) {
      return const Center(child: Text("No listings found."));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _listings.length,
      itemBuilder: (context, index) {
        final listing = _listings[index];
        final isActive = listing['status'] == 'active';
        return Card(
          margin: const EdgeInsets.only(bottom: 12.0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16.0),
            title: Text(listing['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text("Owner: ${listing['owner_name']} (${listing['owner_phone']})"),
                const SizedBox(height: 4),
                Text(listing['address'], maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isActive ? "Active" : "Disabled",
                    style: TextStyle(color: isActive ? const Color(0xFF166534) : const Color(0xFF991B1B), fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(50, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => isActive ? _disableListing(listing['id']) : _enableListing(listing['id']),
                    child: Text(
                      isActive ? "Disable" : "Enable",
                      style: TextStyle(
                        color: isActive ? Colors.red : Colors.green,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUsersTab() {
    if (_users.isEmpty) {
      return const Center(child: Text("No users found."));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _users.length,
      itemBuilder: (context, index) {
        final user = _users[index];
        final isActive = user['is_active'] ?? true;
        return Card(
          margin: const EdgeInsets.only(bottom: 12.0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16.0),
            leading: const CircleAvatar(
              child: Icon(Icons.person),
            ),
            title: Text(user['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(user['phone_number']),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isActive ? "Active" : "Disabled",
                    style: TextStyle(color: isActive ? const Color(0xFF166534) : const Color(0xFF991B1B), fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(50, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => isActive ? _disableUser(user['id']) : _enableUser(user['id']),
                    child: Text(
                      isActive ? "Disable" : "Enable",
                      style: TextStyle(
                        color: isActive ? Colors.red : Colors.green,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReviewsTab() {
    if (_reviews.isEmpty) {
      return const Center(child: Text("No reviews found."));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _reviews.length,
      itemBuilder: (context, index) {
        final review = _reviews[index];
        final rating = review['rating'] ?? 5;
        return Card(
          margin: const EdgeInsets.only(bottom: 12.0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(review['author']?['name'] ?? 'Anonymous User', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Row(
                      children: List.generate(5, (starIdx) {
                        return Icon(
                          starIdx < rating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 16,
                        );
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  review['comment'] ?? 'No comment provided.',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 8),
                Text(
                  "Listing ID: ${review['listing_id']}",
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
