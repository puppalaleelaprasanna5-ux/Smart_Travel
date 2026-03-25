import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/travel_place.dart';
import '../models/trip_plan.dart';
import '../services/travel_data_service.dart';

class MapScreen extends StatefulWidget {
  final bool embedded;

  const MapScreen({super.key, this.embedded = false});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController mapController = MapController();
  final TravelDataService travelData = TravelDataService.instance;
  static final LatLng _fallbackCenter = LatLng(20.5937, 78.9629);

  @override
  void initState() {
    super.initState();
    travelData.addListener(_handleTravelDataChanged);
    _initialize();
  }

  @override
  void dispose() {
    travelData.removeListener(_handleTravelDataChanged);
    super.dispose();
  }

  Future<void> _initialize() async {
    await travelData.initialize();
    await travelData.refreshTripLocation();
    if (!mounted) return;
    mapController.move(travelData.cityCenter ?? _fallbackCenter, 13);
    setState(() {});
  }

  void _handleTravelDataChanged() {
    if (!mounted) return;
    mapController.move(travelData.cityCenter ?? _fallbackCenter, 13);
    setState(() {});
  }

  void _recenterMap() {
    mapController.move(travelData.cityCenter ?? _fallbackCenter, 13);
  }

  void _selectPlace(TravelPlace place) {
    travelData.selectPlace(place);
  }

  Color _stopColor(PlannerStop stop) {
    if (travelData.visitedPlaceIds.contains(stop.place)) {
      return const Color(0xFF1EAF5D);
    }
    return stop.category == 'event'
        ? const Color(0xFFE3A32B)
        : const Color(0xFF0B5F8E);
  }

  Color _cardColor(TravelPlace place) {
    switch (place.category) {
      case 'restaurant':
        return const Color(0xFF6EBE7B);
      case 'hotel':
        return const Color(0xFF5B79A5);
      case 'museum':
        return const Color(0xFFB58153);
      default:
        return const Color(0xFF2B9EC3);
    }
  }

  IconData _placeIcon(TravelPlace place) {
    switch (place.category) {
      case 'restaurant':
        return Icons.restaurant_rounded;
      case 'hotel':
        return Icons.hotel_rounded;
      case 'museum':
        return Icons.museum_rounded;
      default:
        return Icons.place_rounded;
    }
  }

  Widget _buildGemCard(TravelPlace place) {
    final selected = travelData.selectedPlace?.id == place.id;
    return GestureDetector(
      onTap: () => _selectPlace(place),
      child: Container(
        width: 178,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: selected
              ? Border.all(color: const Color(0xFF0B5F8E), width: 1.5)
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 126,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _cardColor(place),
                      _cardColor(place).withOpacity(0.45),
                    ],
                  ),
                ),
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _placeIcon(place),
                        color: const Color(0xFF0B5F8E),
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                place.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF20252D),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    size: 12,
                    color: Color(0xFF0B8B7A),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${place.category.toUpperCase()} • ${place.distanceKm.toStringAsFixed(1)} km away',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.black.withOpacity(0.56),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final selectedPlace =
        travelData.selectedPlace ??
        (travelData.nearbyGems.isNotEmpty ? travelData.nearbyGems.first : null);

    if (travelData.loadingPlaces && travelData.places.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F9FC),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: const [
                              CircleAvatar(
                                radius: 8,
                                backgroundColor: Color(0xFFF3B09E),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'TravelPilot AI',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF355264),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: _recenterMap,
                          icon: const Icon(
                            Icons.notifications_none_rounded,
                            color: Color(0xFF0F567F),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                travelData.cityName.isEmpty
                                    ? 'TravelPilot AI'
                                    : travelData.cityName,
                                style: const TextStyle(
                                  fontSize: 27,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0B5F8E),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                travelData.cityLabel.isEmpty
                                    ? 'Search any city to load live suggestions.'
                                    : travelData.cityLabel,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black.withOpacity(0.48),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          children: [
                            const Icon(
                              Icons.explore_rounded,
                              color: Color(0xFF1B92D0),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${travelData.places.length}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF243343),
                              ),
                            ),
                            Text(
                              'Live places',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.black.withOpacity(0.48),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: FlutterMap(
                  mapController: mapController,
                  options: MapOptions(
                    center: travelData.cityCenter ?? _fallbackCenter,
                    zoom: 13,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.smart_travel_app',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          width: 44,
                          height: 44,
                          point: travelData.cityCenter ?? _fallbackCenter,
                          builder: (_) => const Icon(
                            Icons.location_on_rounded,
                            color: Color(0xFF0B5F8E),
                            size: 30,
                          ),
                        ),
                        if (travelData.currentLocation != null)
                          Marker(
                            width: 40,
                            height: 40,
                            point: travelData.currentLocation!,
                            builder: (_) => Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF22A7F0),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                              ),
                              child: const Icon(
                                Icons.my_location_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ...travelData.places.map(
                          (place) => Marker(
                            width: 42,
                            height: 42,
                            point: LatLng(place.latitude, place.longitude),
                            builder: (_) => GestureDetector(
                              onTap: () => _selectPlace(place),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _cardColor(place),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  _placeIcon(place),
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ),
                        ...travelData.itineraryStops.map(
                          (stop) => Marker(
                            width: 38,
                            height: 38,
                            point: LatLng(stop.latitude, stop.longitude),
                            builder: (_) => Container(
                              decoration: BoxDecoration(
                                color: _stopColor(stop),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                travelData.visitedPlaceIds.contains(stop.place)
                                    ? Icons.check_rounded
                                    : stop.category == 'event'
                                    ? Icons.celebration_rounded
                                    : Icons.route_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                        ...travelData.events.map(
                          (event) => Marker(
                            width: 34,
                            height: 34,
                            point: LatLng(event.latitude, event.longitude),
                            builder: (_) => Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFE3A32B),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.local_activity_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 16,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(28),
                bottom: Radius.circular(22),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD8DDE4),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Nearby Gems',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1F252D),
                      ),
                    ),
                    Text(
                      'See All',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF4D87AA),
                      ),
                    ),
                  ],
                ),
                if (travelData.events.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    '${travelData.itineraryStops.length} itinerary markers • ${travelData.events.length} event markers',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.black.withOpacity(0.5),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (travelData.currentLocation != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Current location tracking active',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.black.withOpacity(0.5),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: travelData.nearbyGems.map(_buildGemCard).toList(),
                  ),
                ),
                if (selectedPlace != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    selectedPlace.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1F252D),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${selectedPlace.category.toUpperCase()} • ${selectedPlace.distanceKm.toStringAsFixed(1)} km away${selectedPlace.address.isNotEmpty ? ' • ${selectedPlace.address}' : ''}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.black.withOpacity(0.5),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (travelData.errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    travelData.errorMessage!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFD64545),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Positioned(
          right: 20,
          bottom: 180,
          child: FloatingActionButton(
            onPressed: _recenterMap,
            backgroundColor: const Color(0xFF0B5F8E),
            foregroundColor: Colors.white,
            child: const Icon(Icons.explore_rounded),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return _buildBody();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(title: const Text('Map')),
      body: SafeArea(child: _buildBody()),
    );
  }
}
