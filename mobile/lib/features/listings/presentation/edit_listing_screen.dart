import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/network/dio_client.dart';

class EditListingScreen extends StatefulWidget {
  final String listingId;
  const EditListingScreen({super.key, required this.listingId});

  @override
  State<EditListingScreen> createState() => _EditListingScreenState();
}

class _EditListingScreenState extends State<EditListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dio = DioClient().dio;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ownerNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _workingHoursController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();

  int? _selectedCategoryId;
  List<dynamic> _categories = [];
  bool _isLoading = true;
  List<int> _workingDays = [1, 2, 3, 4, 5]; // Fallback default (Mon-Fri)

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    setState(() => _isLoading = true);
    try {
      // Fetch categories
      final catResponse = await _dio.get("/categories/");
      if (catResponse.statusCode == 200) {
        _categories = catResponse.data;
      }

      // Fetch listing details
      final listingResponse = await _dio.get("/listings/${widget.listingId}");
      if (listingResponse.statusCode == 200) {
        final listing = listingResponse.data;
        _nameController.text = listing['name'] ?? '';
        _ownerNameController.text = listing['owner_name'] ?? '';
        _phoneController.text = listing['owner_phone'] ?? '';
        _addressController.text = listing['address'] ?? '';
        _workingHoursController.text = listing['working_hours'] ?? '';
        _descriptionController.text = listing['description'] ?? '';
        _latitudeController.text = (listing['latitude'] ?? 17.3850).toString();
        _longitudeController.text = (listing['longitude'] ?? 78.4867).toString();
        _selectedCategoryId = listing['category_id'];
        
        if (listing['working_days'] != null) {
          _workingDays = List<int>.from(listing['working_days']);
        }
      }
    } catch (e) {
      debugPrint("Error fetching edit data: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error loading listing details.")),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Location services are disabled. Please enable them.")),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Location permissions are denied.")),
            );
          }
          setState(() => _isLoading = false);
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Location permissions are permanently denied.")),
          );
        }
        setState(() => _isLoading = false);
        return;
      } 

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _latitudeController.text = position.latitude.toString();
        _longitudeController.text = position.longitude.toString();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Location updated successfully!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error getting location: $e")),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateListing() async {
    if (!_formKey.currentState!.validate() || _selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all required fields")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final double lat = double.tryParse(_latitudeController.text) ?? 17.3850;
      final double lng = double.tryParse(_longitudeController.text) ?? 78.4867;

      final Map<String, dynamic> updateData = {
        "name": _nameController.text.trim(),
        "category_id": _selectedCategoryId,
        "owner_name": _ownerNameController.text.trim(),
        "owner_phone": _phoneController.text.trim(),
        "latitude": lat,
        "longitude": lng,
        "address": _addressController.text.trim(),
        "working_days": _workingDays,
        "working_hours": _workingHoursController.text.trim(),
        "description": _descriptionController.text.trim(),
      };

      final response = await _dio.put("/listings/${widget.listingId}", data: updateData);

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Listing updated successfully!")),
          );
          context.pop(true); // Return success flag to parent screen
        }
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Update failed: ${e.response?.data['detail'] ?? 'Network error'}")),
        );
      }
      debugPrint("Error updating listing: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Recommendation")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Category Selection
                    DropdownButtonFormField<int>(
                      initialValue: _selectedCategoryId,
                      hint: const Text("Select Category"),
                      items: _categories.map<DropdownMenuItem<int>>((cat) {
                        return DropdownMenuItem<int>(
                          value: cat['id'],
                          child: Text(cat['name']),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedCategoryId = val),
                      validator: (val) => val == null ? "Required" : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: "Service Name *"),
                      validator: (val) => val!.trim().isEmpty ? "Required" : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _ownerNameController,
                      decoration: const InputDecoration(labelText: "Owner Name *"),
                      validator: (val) => val!.trim().isEmpty ? "Required" : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: "Owner Phone Number *", hintText: "+91 9999988888"),
                      validator: (val) => val!.trim().isEmpty ? "Required" : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(labelText: "Address *"),
                      validator: (val) => val!.trim().isEmpty ? "Required" : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _latitudeController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: "Latitude *"),
                            validator: (val) => val!.trim().isEmpty ? "Required" : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _longitudeController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: "Longitude *"),
                            validator: (val) => val!.trim().isEmpty ? "Required" : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.my_location, size: 16),
                            label: const Text("Get GPS Location", style: TextStyle(fontSize: 12)),
                            onPressed: _getCurrentLocation,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                              foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
                              minimumSize: const Size(0, 45),
                              elevation: 0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.map_outlined, size: 16),
                            label: const Text("Pick on Map", style: TextStyle(fontSize: 12)),
                            onPressed: () async {
                              final double currentLat = double.tryParse(_latitudeController.text) ?? 17.3850;
                              final double currentLng = double.tryParse(_longitudeController.text) ?? 78.4867;
                              final result = await context.push('/map-picker?lat=$currentLat&lng=$currentLng');
                              if (result != null && result is LatLng) {
                                setState(() {
                                  _latitudeController.text = result.latitude.toString();
                                  _longitudeController.text = result.longitude.toString();
                                });
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                              foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
                              minimumSize: const Size(0, 45),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _workingHoursController,
                      decoration: const InputDecoration(labelText: "Working Hours"),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: "Description / Notes (Optional)"),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _updateListing,
                      child: const Text("Save Changes"),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
