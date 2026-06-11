import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';

class AddListingScreen extends StatefulWidget {
  const AddListingScreen({super.key});

  @override
  State<AddListingScreen> createState() => _AddListingScreenState();
}

class _AddListingScreenState extends State<AddListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dio = DioClient().dio;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ownerNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _workingHoursController = TextEditingController(text: "9:00 AM - 6:00 PM");
  final TextEditingController _descriptionController = TextEditingController();

  int? _selectedCategoryId;
  List<dynamic> _categories = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
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

  Future<void> _submitListing() async {
    if (!_formKey.currentState!.validate() || _selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all required fields")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Prepare form data
      final formData = FormData.fromMap({
        "name": _nameController.text.trim(),
        "category_id": _selectedCategoryId,
        "owner_name": _ownerNameController.text.trim(),
        "owner_phone": _phoneController.text.trim(),
        // Mock latitude/longitude for Hyderabad in development
        "latitude": 17.3850 + (0.01 * (_nameController.text.length % 5)),
        "longitude": 78.4867 + (0.01 * (_nameController.text.length % 3)),
        "address": _addressController.text.trim(),
        "working_days_json": "[1, 2, 3, 4, 5]", // Mon-Fri
        "working_hours": _workingHoursController.text.trim(),
        "description": _descriptionController.text.trim(),
      });

      final response = await _dio.post("/listings/", data: formData);

      if (response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Listing recommended successfully!")),
          );
          context.pop();
        }
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        final errData = e.response?.data['detail'];
        final existingId = errData['existing_listing_id'];
        _showDuplicateDialog(existingId);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed: ${e.response?.data['detail'] ?? 'Network error'}")),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showDuplicateDialog(String existingId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 28),
            SizedBox(width: 8),
            Text("Listing Already Exists"),
          ],
        ),
        content: const Text(
          "A recommendation for this service provider has already been listed in this category.\n\n"
          "Would you like to view the existing listing or submit suggestions/comments?",
        ),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text("View Listing"),
            onPressed: () {
              Navigator.pop(context); // close dialog
              this.context.pop(); // close add listing
              this.context.push('/listings/$existingId'); // view listing
            },
          ),
          ElevatedButton(
            child: const Text("Suggest Edits"),
            onPressed: () {
              Navigator.pop(context);
              _showSuggestionDialog(existingId);
            },
          ),
        ],
      ),
    );
  }

  void _showSuggestionDialog(String listingId) {
    final TextEditingController suggestController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Submit Suggestions"),
        content: TextField(
          controller: suggestController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: "Enter your updates (e.g. phone number changed, new working hours)...",
          ),
        ),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: const Text("Submit"),
            onPressed: () async {
              final text = suggestController.text.trim();
              if (text.isEmpty) return;
              try {
                await _dio.post("/listings/$listingId/suggestions", data: {
                  "comment": text,
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Suggestion submitted successfully!")),
                  );
                  Navigator.pop(context);
                  this.context.pop();
                }
              } catch (_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Failed to submit suggestion.")),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Recommend Service")),
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
                      value: _selectedCategoryId,
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
                      onPressed: _submitListing,
                      child: const Text("Submit Recommendation"),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
