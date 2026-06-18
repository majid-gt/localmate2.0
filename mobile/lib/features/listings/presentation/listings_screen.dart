import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/network/dio_client.dart';

class ListingsScreen extends StatefulWidget {
  final String? refreshKey;
  const ListingsScreen({super.key, this.refreshKey});

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
  bool _nearbySelected = true;
  double? _currentLatitude;
  double? _currentLongitude;

  bool _isMapView = false;
  bool _isSatellite = false;
  dynamic _selectedListingForCard;
  final MapController _mapController = MapController();

  String _sortBy = 'created_at';
  bool _openNow = false;
  double _radiusKm = 3.0;

  String _getCategoryName(int categoryId) {
    final cat = _categories.firstWhere(
      (c) => c['id'] == categoryId,
      orElse: () => null,
    );
    return cat != null ? cat['name'] : '';
  }

  IconData _getCategoryIcon(String? categoryName) {
    if (categoryName == null) return Icons.storefront;
    final name = categoryName.toLowerCase();
    if (name.contains('plumb')) return Icons.plumbing;
    if (name.contains('electr')) return Icons.electrical_services;
    if (name.contains('clean')) return Icons.cleaning_services;
    if (name.contains('tutor') || name.contains('teach') || name.contains('school') || name.contains('educat')) {
      return Icons.school;
    }
    if (name.contains('doctor') || name.contains('health') || name.contains('clinic') || name.contains('med')) {
      return Icons.medical_services;
    }
    if (name.contains('food') || name.contains('restaur') || name.contains('cafe') || name.contains('bakery')) {
      return Icons.restaurant;
    }
    if (name.contains('mechanic') || name.contains('car') || name.contains('auto') || name.contains('repair')) {
      return Icons.build;
    }
    if (name.contains('salon') || name.contains('hair') || name.contains('beauty') || name.contains('spa')) {
      return Icons.face;
    }
    return Icons.storefront;
  }

  LatLng _getInitialMapCenter() {
    if (_currentLatitude != null && _currentLongitude != null) {
      return LatLng(_currentLatitude!, _currentLongitude!);
    }
    if (_listings.isNotEmpty) {
      final firstListing = _listings.first;
      final double lat = double.tryParse(firstListing['latitude'].toString()) ?? 17.3850;
      final double lng = double.tryParse(firstListing['longitude'].toString()) ?? 78.4867;
      return LatLng(lat, lng);
    }
    return const LatLng(17.3850, 78.4867);
  }

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
    _fetchCategories();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _toggleNearby(true);
    });
  }

  @override
  void didUpdateWidget(ListingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshKey != oldWidget.refreshKey) {
      _checkLoginStatus();
      _fetchListings();
    }
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

  String _getFullImageUrl(String path) {
    if (path.startsWith("http")) return path;
    final rootHost = DioClient.baseUrl.replaceAll("/api/v1", "");
    return "$rootHost$path";
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Sort & Filter",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: () {
                          setSheetState(() {
                            _sortBy = 'created_at';
                            _openNow = false;
                          });
                        },
                        child: const Text("Clear All", style: TextStyle(color: Color(0xFFE11D48))),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  
                  const Text(
                    "Sort By",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: [
                      ChoiceChip(
                        label: const Text("Newest"),
                        selected: _sortBy == 'created_at',
                        onSelected: (selected) {
                          if (selected) setSheetState(() => _sortBy = 'created_at');
                        },
                      ),
                      ChoiceChip(
                        label: const Text("Highest Rating"),
                        selected: _sortBy == 'rating',
                        onSelected: (selected) {
                          if (selected) setSheetState(() => _sortBy = 'rating');
                        },
                      ),
                      ChoiceChip(
                        label: const Text("Most Reviewed"),
                        selected: _sortBy == 'reviews_count',
                        onSelected: (selected) {
                          if (selected) setSheetState(() => _sortBy = 'reviews_count');
                        },
                      ),
                      ChoiceChip(
                        label: const Text("Distance"),
                        selected: _sortBy == 'distance',
                        onSelected: _nearbySelected || (_currentLatitude != null && _currentLongitude != null)
                            ? (selected) {
                                if (selected) setSheetState(() => _sortBy = 'distance');
                              }
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    "Filters & Options",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Open Now"),
                    subtitle: const Text("Show only recommendations open at the moment"),
                    value: _openNow,
                    activeThumbColor: const Color(0xFFE11D48),
                    onChanged: (val) {
                      setSheetState(() {
                        _openNow = val;
                      });
                    },
                  ),
                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _fetchListings();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE11D48),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text("Apply Filters", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _fetchListings({String? query, int? categoryId}) async {
    setState(() => _isLoading = true);
    try {
      final Map<String, dynamic> params = {};
      final q = query ?? _searchController.text;
      final catId = categoryId ?? _selectedCategoryId;

      if (q.isNotEmpty) params['q'] = q;
      if (catId != null) params['category_id'] = catId;
      if (_openNow) params['open_now'] = true;
      if (_sortBy != 'created_at') params['sort_by'] = _sortBy;
      
      if (_nearbySelected || _sortBy == 'distance') {
        params['latitude'] = _currentLatitude ?? 17.3850;
        params['longitude'] = _currentLongitude ?? 78.4867;
        if (_nearbySelected) {
          params['radius_km'] = _radiusKm;
        }
      }

      final response = await _dio.get("/listings/", queryParameters: params);
      if (response.statusCode == 200) {
        setState(() {
          _listings = response.data;
          _selectedListingForCard = null;
        });
        if (_isMapView && _listings.isNotEmpty) {
          try {
            _mapController.move(_getInitialMapCenter(), 13.0);
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint("Error fetching listings: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Color matrix to invert Google Roadmap colors into a sleek dark theme with white text labels
    const darkMapFilter = ColorFilter.matrix([
      -0.85, 0.0, 0.0, 0.0, 255.0,
      0.0, -0.85, 0.0, 0.0, 255.0,
      0.0, 0.0, -0.75, 0.0, 255.0,
      0.0, 0.0, 0.0, 1.0, 0.0,
    ]);

    Widget homepageTileLayer = TileLayer(
      urlTemplate: _isSatellite
          ? 'https://mt{s}.google.com/vt/lyrs=y&x={x}&y={y}&z={z}'
          : 'https://mt{s}.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
      subdomains: const ['0', '1', '2', '3'],
      userAgentPackageName: 'com.majid.localmate',
    );

    if (!_isSatellite) {
      homepageTileLayer = ColorFiltered(
        colorFilter: darkMapFilter,
        child: homepageTileLayer,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("LocalMate"),
        actions: [
          IconButton(
            icon: Icon(_isMapView ? Icons.list : Icons.map, color: const Color(0xFFE11D48)),
            onPressed: () {
              setState(() {
                _isMapView = !_isMapView;
                _selectedListingForCard = null;
              });
            },
          ),
          if (_isLoggedIn) ...[
            IconButton(
              icon: const Icon(Icons.add_box_outlined, color: Color(0xFFE11D48)),
              onPressed: () => context.push('/listings/add').then((_) => _fetchListings()),
            ),
            IconButton(
              icon: const Icon(Icons.account_circle_outlined, color: Color(0xFFE11D48)),
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
          // Search Bar & Filter Button Row
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
            child: Row(
              children: [
                Expanded(
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
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: _openNow || _sortBy != 'created_at'
                        ? const Color(0x1AE11D48)
                        : (Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF1E293B)
                            : Colors.grey.shade100),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _openNow || _sortBy != 'created_at'
                          ? const Color(0xFFE11D48)
                          : (Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF334155)
                              : Colors.grey.shade300),
                    ),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.filter_list_rounded,
                      color: _openNow || _sortBy != 'created_at'
                          ? const Color(0xFFE11D48)
                          : (Theme.of(context).brightness == Brightness.dark
                              ? Colors.white70
                              : Colors.black54),
                    ),
                    onPressed: _showFilterBottomSheet,
                  ),
                ),
              ],
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
                  final bool isDark = Theme.of(context).brightness == Brightness.dark;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Center(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(100),
                        onTap: () {
                          _toggleNearby(!_nearbySelected);
                        },
                        child: Ink(
                          decoration: BoxDecoration(
                            color: _nearbySelected
                                ? const Color(0xFFE11D48)
                                : (isDark ? const Color(0xFF1E293B) : Colors.grey.shade100),
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                              color: _nearbySelected
                                  ? const Color(0xFFE11D48)
                                  : (isDark ? const Color(0xFF334155) : Colors.grey.shade300),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.my_location_rounded,
                                size: 16,
                                color: _nearbySelected ? Colors.white : const Color(0xFFE11D48),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "Nearby",
                                style: TextStyle(
                                  color: _nearbySelected
                                      ? Colors.white
                                      : (isDark ? Colors.white70 : Colors.black87),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                height: 14,
                                width: 1,
                                color: _nearbySelected
                                    ? Colors.white30
                                    : (isDark ? Colors.white24 : Colors.black26),
                              ),
                              const SizedBox(width: 6),
                              DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: _radiusKm.toInt(),
                                  dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                  icon: Icon(
                                    Icons.arrow_drop_down,
                                    size: 16,
                                    color: _nearbySelected ? Colors.white : const Color(0xFFE11D48),
                                  ),
                                  style: TextStyle(
                                    color: _nearbySelected ? Colors.white : const Color(0xFFE11D48),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                  isDense: true,
                                  items: [1, 2, 3, 5, 8, 10, 15, 20, 30, 40, 50].map((int val) {
                                    return DropdownMenuItem<int>(
                                      value: val,
                                      child: Text(
                                        "$val km",
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (int? newVal) {
                                    if (newVal != null) {
                                      setState(() {
                                        _radiusKm = newVal.toDouble();
                                        _nearbySelected = true;
                                      });
                                      _toggleNearby(true);
                                    }
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
                    : _isMapView
                        ? Stack(
                            children: [
                              FlutterMap(
                                mapController: _mapController,
                                options: MapOptions(
                                  initialCenter: _getInitialMapCenter(),
                                  initialZoom: 13.0,
                                  interactionOptions: const InteractionOptions(
                                    enableMultiFingerGestureRace: true,
                                    rotationThreshold: 20.0,
                                  ),
                                ),
                                children: [
                                  homepageTileLayer,
                                  MarkerLayer(
                                    markers: _listings.map<Marker>((listing) {
                                      final double lat = double.tryParse(listing['latitude'].toString()) ?? 17.3850;
                                      final double lng = double.tryParse(listing['longitude'].toString()) ?? 78.4867;
                                      final isSelected = _selectedListingForCard?['id'] == listing['id'];
                                      return Marker(
                                        point: LatLng(lat, lng),
                                        width: 50.0,
                                        height: 50.0,
                                        child: GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _selectedListingForCard = listing;
                                            });
                                          },
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              Container(
                                                width: 38,
                                                height: 38,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: isSelected
                                                      ? const Color(0xFFE11D48).withValues(alpha: 0.4)
                                                      : Colors.black12,
                                                ),
                                              ),
                                              Container(
                                                width: 32,
                                                height: 32,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: isSelected
                                                      ? const Color(0xFFE11D48)
                                                      : Theme.of(context).colorScheme.primaryContainer,
                                                  border: Border.all(
                                                    color: Colors.white,
                                                    width: 2,
                                                  ),
                                                  boxShadow: const [
                                                    BoxShadow(
                                                      color: Colors.black26,
                                                      blurRadius: 4,
                                                      offset: Offset(0, 2),
                                                    ),
                                                  ],
                                                ),
                                                child: Icon(
                                                  _getCategoryIcon(_getCategoryName(listing['category_id'])),
                                                  color: isSelected
                                                      ? Colors.white
                                                      : Theme.of(context).colorScheme.onPrimaryContainer,
                                                  size: 16,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                              if (_selectedListingForCard != null)
                                Positioned(
                                  bottom: 16,
                                  left: 16,
                                  right: 16,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).cardColor,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.15),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                CircleAvatar(
                                                  radius: 24,
                                                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                                  child: Icon(
                                                    _getCategoryIcon(_getCategoryName(_selectedListingForCard['category_id'])),
                                                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                                                    size: 24,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Expanded(
                                                            child: Text(
                                                              _selectedListingForCard['name'] ?? '',
                                                              style: const TextStyle(
                                                                fontWeight: FontWeight.bold,
                                                                fontSize: 16,
                                                              ),
                                                              maxLines: 1,
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ),
                                                          const SizedBox(width: 4),
                                                          Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              const Icon(Icons.star, color: Colors.amber, size: 16),
                                                              const SizedBox(width: 2),
                                                              Text(
                                                                (_selectedListingForCard['average_rating'] ?? 0.0).toStringAsFixed(1),
                                                                style: const TextStyle(
                                                                  fontWeight: FontWeight.bold,
                                                                  fontSize: 13,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Row(
                                                        children: [
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                            decoration: BoxDecoration(
                                                              color: Theme.of(context).colorScheme.secondaryContainer,
                                                              borderRadius: BorderRadius.circular(6),
                                                            ),
                                                            child: Text(
                                                              _getCategoryName(_selectedListingForCard['category_id']),
                                                              style: TextStyle(
                                                                fontSize: 11,
                                                                fontWeight: FontWeight.w600,
                                                                color: Theme.of(context).colorScheme.onSecondaryContainer,
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(width: 8),
                                                          Icon(Icons.location_on, size: 13, color: Colors.grey[600]),
                                                          const SizedBox(width: 2),
                                                          Text(
                                                            _selectedListingForCard['distance'] != null
                                                                ? "${_selectedListingForCard['distance'].toStringAsFixed(1)} km"
                                                                : "Unknown dist",
                                                            style: TextStyle(
                                                              color: Colors.grey[600],
                                                              fontSize: 12,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 6),
                                                      Text(
                                                        _selectedListingForCard['address'] ?? '',
                                                        style: TextStyle(
                                                          color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                                                          fontSize: 13,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                      if (_selectedListingForCard['working_hours'] != null &&
                                                          _selectedListingForCard['working_hours'].toString().trim().isNotEmpty) ...[
                                                        const SizedBox(height: 4),
                                                        Row(
                                                          children: [
                                                            Icon(Icons.access_time_rounded, size: 14, color: Colors.grey[600]),
                                                            const SizedBox(width: 4),
                                                            Expanded(
                                                              child: Text(
                                                                "Hours: ${_selectedListingForCard['working_hours']}",
                                                                style: TextStyle(
                                                                  color: Colors.grey[600],
                                                                  fontSize: 12,
                                                                ),
                                                                maxLines: 1,
                                                                overflow: TextOverflow.ellipsis,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                IconButton(
                                                  constraints: const BoxConstraints(),
                                                  padding: EdgeInsets.zero,
                                                  icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                                                  onPressed: () {
                                                    setState(() {
                                                      _selectedListingForCard = null;
                                                    });
                                                  },
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 16),
                                            Divider(height: 1, color: Colors.grey[200]),
                                            const SizedBox(height: 12),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: ElevatedButton.icon(
                                                    onPressed: () async {
                                                      final phone = _selectedListingForCard['owner_phone'];
                                                      if (phone != null && phone.toString().isNotEmpty) {
                                                        final telUri = Uri.parse("tel:$phone");
                                                        if (await canLaunchUrl(telUri)) {
                                                          await launchUrl(telUri);
                                                        } else {
                                                          if (context.mounted) {
                                                            ScaffoldMessenger.of(context).showSnackBar(
                                                              SnackBar(content: Text("Calling owner: $phone")),
                                                            );
                                                          }
                                                        }
                                                      }
                                                    },
                                                    icon: const Icon(Icons.call, size: 16),
                                                    label: const Text("Call"),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: const Color(0xFF10B981),
                                                      foregroundColor: Colors.white,
                                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(10),
                                                      ),
                                                      elevation: 0,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: ElevatedButton.icon(
                                                    onPressed: () async {
                                                      final double lat = double.tryParse(_selectedListingForCard['latitude'].toString()) ?? 17.3850;
                                                      final double lng = double.tryParse(_selectedListingForCard['longitude'].toString()) ?? 78.4867;
                                                      final geoUri = Uri.parse("geo:$lat,$lng?q=$lat,$lng");
                                                      final webUri = Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lng");
                                                      try {
                                                        if (await canLaunchUrl(geoUri)) {
                                                          await launchUrl(geoUri);
                                                        } else if (await canLaunchUrl(webUri)) {
                                                          await launchUrl(webUri);
                                                        } else {
                                                          if (context.mounted) {
                                                            ScaffoldMessenger.of(context).showSnackBar(
                                                              const SnackBar(content: Text("Could not launch navigation application.")),
                                                            );
                                                          }
                                                        }
                                                      } catch (e) {
                                                        debugPrint("Error launching map: $e");
                                                      }
                                                    },
                                                    icon: const Icon(Icons.directions, size: 16),
                                                    label: const Text("Directions"),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: Colors.blue[600],
                                                      foregroundColor: Colors.white,
                                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(10),
                                                      ),
                                                      elevation: 0,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: ElevatedButton.icon(
                                                    onPressed: () {
                                                      context.push('/listings/${_selectedListingForCard['id']}').then((_) {
                                                        _fetchListings();
                                                      });
                                                    },
                                                    icon: const Icon(Icons.info_outline, size: 16),
                                                    label: const Text("Details"),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: const Color(0xFFE11D48),
                                                      foregroundColor: Colors.white,
                                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(10),
                                                      ),
                                                      elevation: 0,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              // Toggle View FAB in top right
                              Positioned(
                                top: 16,
                                right: 16,
                                child: FloatingActionButton.small(
                                  heroTag: 'home_map_layer_toggle',
                                  backgroundColor: Theme.of(context).cardColor,
                                  foregroundColor: Theme.of(context).colorScheme.primary,
                                  child: Icon(_isSatellite ? Icons.map : Icons.satellite_alt),
                                  onPressed: () {
                                    setState(() {
                                      _isSatellite = !_isSatellite;
                                    });
                                  },
                                ),
                              ),
                              // Align to North FAB in top right
                              Positioned(
                                top: 72,
                                right: 16,
                                child: FloatingActionButton.small(
                                  heroTag: 'home_map_north_align',
                                  backgroundColor: Theme.of(context).cardColor,
                                  foregroundColor: Theme.of(context).colorScheme.primary,
                                  child: const Icon(Icons.explore),
                                  onPressed: () {
                                    _mapController.rotate(0.0);
                                  },
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16.0),
                            itemCount: _listings.length,
                            itemBuilder: (context, index) {
                              final listing = _listings[index];
                              final distance = listing['distance'] != null
                                  ? "${listing['distance'].toStringAsFixed(1)} km away"
                                  : null;
                              final avgRating = listing['average_rating'] ?? 0.0;
                              final reviewsCount = listing['reviews_count'] ?? 0;
                              final isOpen = listing['is_open'] ?? true;
                              
                              String? firstImageUrl;
                              if (listing['images'] != null && (listing['images'] as List).isNotEmpty) {
                                firstImageUrl = _getFullImageUrl(listing['images'][0]['image_url']);
                              }

                              return Card(
                                margin: const EdgeInsets.only(bottom: 16.0),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.grey.shade800
                                        : const Color(0xFFE2E8F0),
                                    width: 1.0,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: () => context.push('/listings/${listing['id']}').then((_) {
                                    _fetchListings();
                                  }),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (firstImageUrl != null)
                                        SizedBox(
                                          width: 110,
                                          height: 110,
                                          child: Image.network(
                                            firstImageUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) => Container(
                                              color: Colors.grey.shade200,
                                              child: const Icon(Icons.broken_image, color: Colors.grey),
                                            ),
                                          ),
                                        )
                                      else
                                        Container(
                                          width: 110,
                                          height: 110,
                                          color: Theme.of(context).brightness == Brightness.dark
                                              ? const Color(0xFF1E293B)
                                              : const Color(0xFFF1F5F9),
                                          child: Icon(
                                            _getCategoryIcon(_getCategoryName(listing['category_id'])),
                                            color: const Color(0xFFE11D48),
                                            size: 36,
                                          ),
                                        ),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.all(12.0),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0x1AE11D48),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      _getCategoryName(listing['category_id']),
                                                      style: const TextStyle(
                                                        color: Color(0xFFE11D48),
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: isOpen
                                                          ? const Color(0x1A10B981)
                                                          : const Color(0x1AE11D48),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      isOpen ? "Open Now" : "Closed",
                                                      style: TextStyle(
                                                        color: isOpen
                                                            ? const Color(0xFF10B981)
                                                            : const Color(0xFFE11D48),
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                listing['name'],
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                listing['address'],
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 13,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 6),
                                              Row(
                                                children: [
                                                  if (avgRating > 0.0) ...[
                                                    const Icon(Icons.star, color: Colors.amber, size: 14),
                                                    const SizedBox(width: 2),
                                                    Text(
                                                      avgRating.toStringAsFixed(1),
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      "($reviewsCount ${reviewsCount == 1 ? 'review' : 'reviews'})",
                                                      style: TextStyle(
                                                        color: Colors.grey[500],
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  ] else ...[
                                                    Text(
                                                      "No reviews yet",
                                                      style: TextStyle(
                                                        color: Colors.grey[500],
                                                        fontSize: 11,
                                                        fontStyle: FontStyle.italic,
                                                      ),
                                                    ),
                                                  ],
                                                  if (distance != null) ...[
                                                    const Spacer(),
                                                    Icon(Icons.location_on, size: 12, color: Colors.grey[500]),
                                                    const SizedBox(width: 2),
                                                    Text(
                                                      distance,
                                                      style: TextStyle(
                                                        color: Colors.grey[600],
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
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
