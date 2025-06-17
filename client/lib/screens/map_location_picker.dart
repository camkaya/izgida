import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class MapLocationPicker extends StatefulWidget {
  final LatLng? initialLocation;

  const MapLocationPicker({super.key, this.initialLocation});

  @override
  State<MapLocationPicker> createState() => _MapLocationPickerState();
}

class _MapLocationPickerState extends State<MapLocationPicker> {
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    setState(() {
      _isLoading = true;
    });

    try {
      
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _errorMessage = 'Konum izni reddedildi.';
            _isLoading = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _errorMessage = 'Konum izinleri kalıcı olarak reddedildi, uygulama ayarlarından izin vermeniz gerekiyor.';
          _isLoading = false;
        });
        return;
      }

      if (widget.initialLocation != null) {
        _selectedLocation = widget.initialLocation;
        setState(() {
          _isLoading = false;
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      _selectedLocation = LatLng(position.latitude, position.longitude);
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Konum alınamadı: $e';
        _isLoading = false;
      });
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  void _selectLocation(LatLng location) {
    setState(() {
      _selectedLocation = location;
    });
  }

  Future<void> _goToCurrentLocation() async {
    setState(() {
      _isLoading = true;
    });

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      final currentLocation = LatLng(position.latitude, position.longitude);
      
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(currentLocation, 15),
      );
      
      setState(() {
        _selectedLocation = currentLocation;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Konum alınamadı: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Konum Seçin'),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
      ),
      body: _isLoading 
        ? const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF4CAF50),
            ),
          )
        : _errorMessage.isNotEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.location_off,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _initializeLocation,
                      child: const Text('Tekrar Dene'),
                    ),
                  ],
                ),
              ),
            )
          : Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      child: GoogleMap(
                        onMapCreated: _onMapCreated,
                        initialCameraPosition: CameraPosition(
                          target: _selectedLocation!,
                          zoom: 15,
                        ),
                        myLocationEnabled: true,
                        
                        myLocationButtonEnabled: false,
                        markers: _selectedLocation != null
                            ? {
                                Marker(
                                  markerId: const MarkerId('selected_location'),
                                  position: _selectedLocation!,
                                  draggable: true,
                                  onDragEnd: (newPosition) {
                                    _selectLocation(newPosition);
                                  },
                                ),
                              }
                            : {},
                        onTap: _selectLocation,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ElevatedButton(
                        onPressed: _selectedLocation != null
                            ? () {
                                Navigator.pop(context, _selectedLocation);
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(50),
                        ),
                        child: const Text('Bu Konumu Seç'),
                      ),
                    ),
                  ],
                ),
                
                Positioned(
                  right: 16,
                  top: 16,
                  child: FloatingActionButton(
                    onPressed: _goToCurrentLocation,
                    backgroundColor: Colors.white,
                    mini: true,
                    child: const Icon(
                      Icons.my_location,
                      color: Color(0xFF4CAF50),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
} 