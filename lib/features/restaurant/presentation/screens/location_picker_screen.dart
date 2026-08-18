import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:merchant_app/core/config/google_config.dart';
import 'package:merchant_app/core/services/google_places_service.dart';
import 'package:merchant_app/core/theme/app_colors.dart';
import 'package:merchant_app/core/theme/app_typography.dart';

/// Full-screen picker: move the map under the centre pin, or search a place by
/// name, then confirm. Pops a [PlaceResult] (lat/lng + address) on success.
class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key, this.initialLat, this.initialLng});

  final double? initialLat;
  final double? initialLng;

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final _places = GooglePlacesService();
  final _searchController = TextEditingController();
  final _sessionToken =
      'sess_${DateTime.now().microsecondsSinceEpoch}'; // groups billing

  GoogleMapController? _mapController;
  late LatLng _center;
  String _address = '';
  bool _resolvingAddress = false;

  List<PlacePrediction> _predictions = const [];
  bool _searching = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _center = LatLng(
      widget.initialLat ?? GoogleConfig.defaultLat,
      widget.initialLng ?? GoogleConfig.defaultLng,
    );
    _resolveAddress();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _resolveAddress() async {
    setState(() => _resolvingAddress = true);
    try {
      final marks =
          await placemarkFromCoordinates(_center.latitude, _center.longitude);
      final p = marks.isNotEmpty ? marks.first : null;
      final parts = <String?>[
        p?.name,
        p?.subLocality,
        p?.locality,
        p?.administrativeArea,
        p?.postalCode,
      ].where((s) => s != null && s.trim().isNotEmpty).toList();
      if (mounted) {
        setState(() => _address = parts.isEmpty ? '' : parts.join(' '));
      }
    } catch (_) {
      // Reverse geocoding is best-effort; the coordinates are what matter.
    } finally {
      if (mounted) setState(() => _resolvingAddress = false);
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() => _predictions = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(value));
  }

  Future<void> _search(String value) async {
    setState(() => _searching = true);
    try {
      final results = await _places.autocomplete(
        value.trim(),
        lat: _center.latitude,
        lng: _center.longitude,
        sessionToken: _sessionToken,
      );
      if (mounted) setState(() => _predictions = results);
    } catch (e) {
      if (mounted) {
        setState(() => _predictions = const []);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ค้นหาสถานที่ไม่สำเร็จ: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _selectPrediction(PlacePrediction p) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _predictions = const [];
      _searchController.text = p.mainText.isNotEmpty ? p.mainText : p.description;
    });
    try {
      final place =
          await _places.placeDetails(p.placeId, sessionToken: _sessionToken);
      final target = LatLng(place.lat, place.lng);
      await _mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, 17));
      setState(() {
        _center = target;
        _address = place.address;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ดึงข้อมูลสถานที่ไม่สำเร็จ: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _confirm() {
    Navigator.of(context).pop(
      PlaceResult(
        lat: _center.latitude,
        lng: _center.longitude,
        address: _address,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _center, zoom: 16),
            onMapCreated: (c) => _mapController = c,
            onCameraMove: (pos) => _center = pos.target,
            onCameraIdle: _resolveAddress,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // Fixed centre pin (map moves underneath it)
          IgnorePointer(
            child: Center(
              child: Padding(
                // lift so the tip sits on the map centre
                padding: const EdgeInsets.only(bottom: 40),
                child: Icon(Icons.location_on,
                    size: 48, color: AppColors.primary),
              ),
            ),
          ),

          // Top: back + search
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Material(
                    elevation: 3,
                    borderRadius: BorderRadius.circular(12),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: _onSearchChanged,
                            textInputAction: TextInputAction.search,
                            decoration: const InputDecoration(
                              hintText: 'ค้นหาชื่อสถานที่ / ที่อยู่',
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        if (_searching)
                          const Padding(
                            padding: EdgeInsets.only(right: 12),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        else if (_searchController.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _predictions = const []);
                            },
                          ),
                      ],
                    ),
                  ),
                  if (_predictions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      constraints: const BoxConstraints(maxHeight: 260),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: _predictions.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        itemBuilder: (_, i) {
                          final p = _predictions[i];
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.place_outlined,
                                color: AppColors.primary),
                            title: Text(p.mainText,
                                style: AppTypography.body2,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            subtitle: p.secondaryText.isEmpty
                                ? null
                                : Text(p.secondaryText,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                            onTap: () => _selectPrediction(p),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Bottom: address + confirm
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                  20, 16, 20, 16 + MediaQuery.paddingOf(context).bottom),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 16)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ตำแหน่งที่เลือก',
                      style: AppTypography.label2.copyWith(
                          color: AppColors.semanticGrayNeutralFgHigh)),
                  const SizedBox(height: 4),
                  Text(
                    _resolvingAddress
                        ? 'กำลังค้นหาที่อยู่…'
                        : (_address.isEmpty ? 'เลื่อนแผนที่เพื่อเลือกตำแหน่ง' : _address),
                    style: AppTypography.body2.copyWith(
                        color: AppColors.semanticGrayNeutralFgMidOnWhite),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_center.latitude.toStringAsFixed(6)}, ${_center.longitude.toStringAsFixed(6)}',
                    style: AppTypography.caption5
                        .copyWith(color: AppColors.semanticGrayNeutralFgMidOnWhite),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _confirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('ยืนยันตำแหน่งนี้',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
