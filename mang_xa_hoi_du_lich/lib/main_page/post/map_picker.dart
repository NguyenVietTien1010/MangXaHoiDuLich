import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';

class MapPickerScreen extends StatefulWidget {
  @override
  _MapPickerScreenState createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  GoogleMapController? _mapController;
  LatLng _pickedLocation = const LatLng(10.762622, 106.660172); // Hồ Chí Minh
  Marker? _marker;
  final TextEditingController _searchController = TextEditingController();
  String? _searchedPlaceName; // Lưu tên địa điểm người dùng nhập
  final Color _primaryColor = const Color(0xFF63AB83);

  Future<void> _searchLocation() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    try {
      List<Location> locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        final location = locations.first;
        LatLng newLatLng = LatLng(location.latitude, location.longitude);

        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(newLatLng, 15),
        );

        setState(() {
          _pickedLocation = newLatLng;
          _searchedPlaceName = query; // Lưu tên người dùng nhập
          _marker = Marker(
            markerId: const MarkerId('searched'),
            position: newLatLng,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueGreen,
            ),
          );
        });
      }
    } catch (e) {
      print('Không tìm thấy địa điểm: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Không tìm thấy địa điểm')));
    }
  }

  void _selectLocation(LatLng position) {
    setState(() {
      _pickedLocation = position;
      _searchedPlaceName = null; // Xóa tên tìm kiếm khi chọn thủ công
      _marker = Marker(
        markerId: const MarkerId('selected'),
        position: position,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      );
    });
  }

  Future<void> _confirmLocation() async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        _pickedLocation.latitude,
        _pickedLocation.longitude,
      );

      String placeName;
      String fullAddress;

      if (_searchedPlaceName != null) {
        // Nếu có tìm kiếm, ưu tiên tên người dùng nhập
        placeName = _searchedPlaceName!;
        // Lấy địa chỉ chi tiết từ placemark để lưu
        if (placemarks.isNotEmpty) {
          final placemark = placemarks.first;
          List<String> addressParts = [];
          if (placemark.subThoroughfare?.isNotEmpty ?? false) {
            addressParts.add(placemark.subThoroughfare!);
          }
          if (placemark.thoroughfare?.isNotEmpty ??
              false && placemark.thoroughfare != placemark.subThoroughfare) {
            addressParts.add(placemark.thoroughfare!);
          }
          if (placemark.subAdministrativeArea?.isNotEmpty ?? false) {
            addressParts.add(placemark.subAdministrativeArea!);
          }
          if (placemark.administrativeArea?.isNotEmpty ??
              false &&
                  placemark.administrativeArea !=
                      placemark.subAdministrativeArea) {
            addressParts.add(placemark.administrativeArea!);
          }
          if (placemark.country?.isNotEmpty ?? false) {
            addressParts.add(placemark.country!);
          }
          fullAddress =
              addressParts.isNotEmpty
                  ? addressParts.join(', ')
                  : 'Unknown location';
        } else {
          fullAddress = 'Unknown location';
        }
      } else if (placemarks.isNotEmpty) {
        // Nếu không tìm kiếm, lấy từ placemark như trước
        final placemark = placemarks.first;
        final name = placemark.name ?? '';
        final thoroughfare = placemark.thoroughfare ?? '';
        final subLocality = placemark.subLocality ?? '';
        final locality = placemark.locality ?? '';

        placeName =
            name.isNotEmpty && !RegExp(r'^\d+$').hasMatch(name)
                ? name
                : thoroughfare.isNotEmpty
                ? thoroughfare
                : subLocality.isNotEmpty
                ? subLocality
                : locality.isNotEmpty
                ? locality
                : 'Unknown place';

        List<String> addressParts = [];
        if (placemark.subThoroughfare?.isNotEmpty ?? false) {
          addressParts.add(placemark.subThoroughfare!);
        }
        if (placemark.thoroughfare?.isNotEmpty ??
            false && placemark.thoroughfare != placemark.subThoroughfare) {
          addressParts.add(placemark.thoroughfare!);
        }
        if (placemark.subAdministrativeArea?.isNotEmpty ?? false) {
          addressParts.add(placemark.subAdministrativeArea!);
        }
        if (placemark.administrativeArea?.isNotEmpty ??
            false &&
                placemark.administrativeArea !=
                    placemark.subAdministrativeArea) {
          addressParts.add(placemark.administrativeArea!);
        }
        if (placemark.country?.isNotEmpty ?? false) {
          addressParts.add(placemark.country!);
        }
        fullAddress =
            addressParts.isNotEmpty
                ? addressParts.join(', ')
                : 'Unknown location';
      } else {
        placeName = 'Unknown place';
        fullAddress = 'Unknown location';
      }

      Navigator.pop(context, {
        'placeName': placeName,
        'address': fullAddress,
        'coordinates': _pickedLocation,
      });
    } catch (e) {
      print('Error reverse geocoding: $e');
      Navigator.pop(context, {
        'placeName': _searchedPlaceName ?? 'Unknown place',
        'address': 'Unknown location',
        'coordinates': _pickedLocation,
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_primaryColor, _primaryColor.withOpacity(0.9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
        ),
        title: const Text(
          'Chọn vị trí',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: _confirmLocation,
              icon: const Icon(Icons.check, size: 20),
              label: const Text('Xác nhận'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(80),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onSubmitted: (_) => _searchLocation(),
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm địa điểm (VD: Núi Bà Đen)',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  prefixIcon: Icon(Icons.search, color: _primaryColor),
                  suffixIcon:
                      _searchController.text.isNotEmpty
                          ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchedPlaceName = null;
                              });
                            },
                          )
                          : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) => _mapController = controller,
            initialCameraPosition: CameraPosition(
              target: _pickedLocation,
              zoom: 14,
            ),
            markers: _marker != null ? {_marker!} : {},
            onTap: _selectLocation,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: Column(
              children: [
                FloatingActionButton(
                  mini: true,
                  backgroundColor: Colors.white,
                  foregroundColor: _primaryColor,
                  onPressed: () {
                    _mapController?.animateCamera(CameraUpdate.zoomIn());
                  },
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  mini: true,
                  backgroundColor: Colors.white,
                  foregroundColor: _primaryColor,
                  onPressed: () {
                    _mapController?.animateCamera(CameraUpdate.zoomOut());
                  },
                  child: const Icon(Icons.remove),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
