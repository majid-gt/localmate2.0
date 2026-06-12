import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
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
  bool _nearbySelected = false;
  double? _currentLatitude;
  double? _currentLongitude;

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

  Future<Position?> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return null;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return null;
    } 

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
    } catch (e) {
      debugPrint("Error getting GPS location: $e");
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }
  }

  Future<void> _toggleNearby(bool selected) async {
    if (selected) {
      setState(() {
        _isLoading = true;
        _nearbySelected = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Getting current location..."),
          duration: Duration(milliseconds: 800),
        ),
      );

      final position = await _getCurrentLocation();
      if (!mounted) return;
      if (position != null) {
        setState(() {
          _currentLatitude = position.latitude;
          _currentLongitude = position.longitude;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Could not retrieve GPS location. Using default location."),
          ),
        );
        setState(() {
          _currentLatitude = 17.3850;
          _currentLongitude = 78.4867;
        });
      }
      _fetchListings(query: _searchController.text, categoryId: _selectedCategoryId);
    } else {
      setState(() {
        _nearbySelected = false;
        _currentLatitude = null;
        _currentLongitude = null;
      });
      _fetchListings(query: _searchController.text, categoryId: _selectedCategoryId);
    }
  }

  Future<void> _fetchListings({String? query, int? categoryId}) async {
    setState(() => _isLoading = true);
    try {
      final Map<String, dynamic> params = {};
      final q = query ?? _searchController.text;
      final catId = categoryId ?? _selectedCategoryId;

      if (q.isNotEmpty) params['q'] = q;
      if (catId != null) params['category_id'] = catId;
      
      if (_nearbySelected) {
        params['latitude'] = _currentLatitude ?? 17.3850;
        params['longitude'] = _currentLongitude ?? 78.4867;
        params['radius_km'] = 3.0;
        params['sort_by'] = 'distance';
      }

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
              icon: const Icon(Icons.account_circle_outlined, color: Color(0xFF6366F1)),
              onPressed: () => context.push('/profile').then((_) {
                _checkLoginStatus();
                _fetchListings();
              }),
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
              itemCount: _categories.length + 2,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      avatar: Icon(
                        Icons.my_location_rounded,
                        size: 16,
                        color: _nearbySelected ? Colors.white : const Color(0xFF6366F1),
                      ),
                      label: const Text("Nearby (< 3 km)"),
                      selected: _nearbySelected,
                      selectedColor: const Color(0xFF6366F1),
                      onSelected: (selected) {
                        _toggleNearby(selected);
                      },
                    ),
                  );
                }
                if (index == 1) {
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
                final category = _categories[index - 2];
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
