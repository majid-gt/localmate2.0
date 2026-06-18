import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';

class MapPickerScreen extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;

  const MapPickerScreen({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
  });

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  late LatLng _selectedLatLng;
  bool _isSatellite = false;
  final MapController _mapController = MapController();


  @override
  void initState() {
    super.initState();
    _selectedLatLng = LatLng(
      widget.initialLatitude ?? 17.3850,
      widget.initialLongitude ?? 78.4867,
    );
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

    Widget tileLayer = TileLayer(
      urlTemplate: _isSatellite
          ? 'https://mt{s}.google.com/vt/lyrs=y&x={x}&y={y}&z={z}'
          : 'https://mt{s}.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
      subdomains: const ['0', '1', '2', '3'],
      userAgentPackageName: 'com.majid.localmate',
    );

    if (!_isSatellite) {
      tileLayer = ColorFiltered(
        colorFilter: darkMapFilter,
        child: tileLayer,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Select Location"),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () => context.pop(_selectedLatLng),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedLatLng,
              initialZoom: 15.0,
              interactionOptions: const InteractionOptions(
                enableMultiFingerGestureRace: true,
                rotationThreshold: 20.0,
              ),
              onPositionChanged: (position, hasGesture) {
                if (position.center != null) {
                  setState(() {
                    _selectedLatLng = position.center!;
                  });
                }
              },
            ),
            children: [
              tileLayer,
            ],
          ),
          
          // Constant Center Pin Pointer
          const IgnorePointer(
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 40.0), // Shift up so the tip of the pin aligns exactly in the center
                child: Icon(
                  Icons.location_on,
                  color: Colors.red,
                  size: 45,
                ),
              ),
            ),
          ),
          
          // Toggle View FAB in top right
          Positioned(
            top: 16,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'map_picker_layer_toggle',
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
              heroTag: 'map_picker_north_align',
              backgroundColor: Theme.of(context).cardColor,
              foregroundColor: Theme.of(context).colorScheme.primary,
              child: const Icon(Icons.explore),
              onPressed: () {
                _mapController.rotate(0.0);
              },
            ),
          ),
          
          // Selection Floating Panel
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.pin_drop, color: Theme.of(context).colorScheme.secondary),
                        const SizedBox(width: 8),
                        const Text(
                          "Selected Coordinates",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Lat: ${_selectedLatLng.latitude.toStringAsFixed(6)}\n"
                      "Lng: ${_selectedLatLng.longitude.toStringAsFixed(6)}",
                      style: TextStyle(color: Colors.grey.shade700, fontFamily: 'monospace', fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => context.pop(_selectedLatLng),
                      child: const Text("Confirm Location", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
