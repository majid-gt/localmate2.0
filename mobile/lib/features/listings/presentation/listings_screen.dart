import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/dio_client.dart';

class ListingsScreen extends StatefulWidget {
  const ListingsScreen({super.key});

  @override
  State<ListingsScreen> createState() => _ListingsScreenState();
}

class _ListingsScreenState extends State<ListingsScreen> {
  final _dio = DioClient().dio;
  List<dynamic> _categories = [];
  List<dynamic> _listings = [];
  int? _selectedCategoryId;
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
    _fetchCategories();
    _fetchListings();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    setState(() => _isLoggedIn = token != null);
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    setState(() => _isLoggedIn = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Logged out successfully")),
      );
    }
  }

  Future<void> _fetchCategories() async {
    try {
      final response = await _dio.get("/categories/");
      if (response.statusCode == 200) {
        setState(() => _categories = response.data);
      }
    } catch (e) {
      debugPrint("Error fetching categories: $e");
    }
  }

  Future<void> _fetchListings({String? query, int? categoryId}) async {
    setState(() => _isLoading = true);
    try {
      final Map<String, dynamic> params = {};
      if (query != null && query.isNotEmpty) params['q'] = query;
      if (categoryId != null) params['category_id'] = categoryId;
      
      // For nearby sorting demonstration, send Hyderabad center coordinates
      params['latitude'] = 17.3850;
      params['longitude'] = 78.4867;
      params['sort_by'] = 'distance';

      final response = await _dio.get("/listings/", queryParameters: params);
      if (response.statusCode == 200) {
        setState(() => _listings = response.data);
      }
    } catch (e) {
      debugPrint("Error fetching listings: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("LocalMate"),
        actions: [
          if (_isLoggedIn) ...[
            IconButton(
              icon: const Icon(Icons.add_box_outlined, color: Color(0xFF6366F1)),
              onPressed: () => context.push('/listings/add').then((_) => _fetchListings()),
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _logout,
            ),
          ] else
            TextButton.icon(
              icon: const Icon(Icons.login),
              label: const Text("Login"),
              onPressed: () => context.push('/login').then((_) {
                _checkLoginStatus();
                _fetchListings();
              }),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search services (e.g. plumber, tutor)...",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _fetchListings(categoryId: _selectedCategoryId);
                  },
                ),
              ),
              onSubmitted: (val) => _fetchListings(query: val, categoryId: _selectedCategoryId),
            ),
          ),
          
          // Categories List
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              itemCount: _categories.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  final isSelected = _selectedCategoryId == null;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: const Text("All"),
                      selected: isSelected,
                      onSelected: (_) {
                        setState(() => _selectedCategoryId = null);
                        _fetchListings(query: _searchController.text);
                      },
                    ),
                  );
                }
                final category = _categories[index - 1];
                final isSelected = _selectedCategoryId == category['id'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(category['name']),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() => _selectedCategoryId = category['id']);
                      _fetchListings(query: _searchController.text, categoryId: category['id']);
                    },
                  ),
                );
              },
            ),
          ),
          
          // Listings Area
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _listings.isEmpty
                    ? const Center(child: Text("No recommendations found. Be the first to add one!"))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: _listings.length,
                        itemBuilder: (context, index) {
                          final listing = _listings[index];
                          final distance = listing['distance'] != null 
                              ? "${listing['distance']} km away" 
                              : "Distance unknown";
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16.0),
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
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on, size: 14, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(distance, style: const TextStyle(color: Colors.grey)),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => context.push('/listings/${listing['id']}'),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
