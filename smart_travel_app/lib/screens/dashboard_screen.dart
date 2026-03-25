import 'package:flutter/material.dart';

import '../models/trip_plan.dart';
import '../services/api_service.dart';
import '../services/travel_data_service.dart';
import 'app_shell.dart';
import 'expense_screen.dart';
import 'map_screen.dart';
import 'memory_screen.dart';
import 'profile_screen.dart';
import 'travel_planner_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String userName;
  final String userEmail;
  final bool embedded;

  DashboardScreen({
    super.key,
    required this.userName,
    this.userEmail = '',
    this.embedded = false,
  });

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService api = ApiService();
  final TravelDataService travelData = TravelDataService.instance;
  final TextEditingController destinationController = TextEditingController();
  bool isLoading = true;
  String? errorMessage;
  bool backendConnected = false;
  DateTime? draftStartDate;
  DateTime? draftEndDate;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    travelData.addListener(_handleTravelDataChanged);
  }

  @override
  void dispose() {
    travelData.removeListener(_handleTravelDataChanged);
    destinationController.dispose();
    super.dispose();
  }

  void _handleTravelDataChanged() {
    if (!mounted) return;
    setState(() {
      errorMessage = travelData.errorMessage;
    });
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      await travelData.initialize();
      final response = await api.runAllAgents(
        location: travelData.cityName.isEmpty ? 'dashboard' : travelData.cityName,
        time: DateTime.now().toIso8601String(),
      );

      if (!mounted) return;
      setState(() {
        errorMessage = travelData.errorMessage;
        backendConnected = response['status'] == 'success';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = e.toString();
        backendConnected = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _retryCurrentCity() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    await travelData.initialize();
    await travelData.refreshSelectedCity();
    if (!mounted) return;
    setState(() {
      isLoading = false;
      errorMessage = travelData.errorMessage;
    });
  }

  Future<void> _openTripSearch() async {
    destinationController.text = travelData.cityName;
    draftStartDate ??= travelData.tripStartDate ?? DateTime.now();
    draftEndDate ??=
        travelData.tripEndDate ?? DateTime.now().add(const Duration(days: 2));

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> pickRange() async {
              final selected = await showDateRangePicker(
                context: context,
                initialDateRange: DateTimeRange(
                  start: draftStartDate ?? DateTime.now(),
                  end:
                      draftEndDate ??
                      (draftStartDate ?? DateTime.now()).add(
                        const Duration(days: 2),
                      ),
                ),
                firstDate: DateTime.now().subtract(const Duration(days: 30)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (selected == null) return;
              setSheetState(() {
                draftStartDate = selected.start;
                draftEndDate = selected.end;
              });
            }

            final startDate = draftStartDate ?? DateTime.now();
            final endDate = draftEndDate ?? startDate;
            final calculatedDays = endDate.difference(startDate).inDays + 1;

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Plan Trip',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: destinationController,
                      textInputAction: TextInputAction.search,
                      decoration: const InputDecoration(
                        labelText: 'Destination',
                        hintText: 'Enter any city',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: pickRange,
                            icon: const Icon(Icons.date_range_rounded),
                            label: Text(
                              '${_formatDate(startDate)} - ${_formatDate(endDate)}',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '$calculatedDays day trip',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF355264),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final destination = destinationController.text.trim();
                          if (destination.isEmpty) return;
                          Navigator.of(context).pop();
                          await travelData.createTrip(
                            destination: destination,
                            startDate: startDate,
                            endDate: endDate,
                          );
                          if (!mounted) return;
                          AppShell.switchToTab(this.context, 2);
                        },
                        child: const Text('Generate Trip'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openPreviousTrip(TravelTrip trip) async {
    setState(() => isLoading = true);
    await travelData.openPreviousTrip(trip);
    if (!mounted) return;
    setState(() => isLoading = false);
    AppShell.switchToTab(context, 2);
  }

  String _formatDate(DateTime date) {
    final month = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ][date.month - 1];
    return '$month ${date.day}';
  }

  Widget _buildPreviousTripCard(TravelTrip trip) {
    return GestureDetector(
      onTap: () => _openPreviousTrip(trip),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F4FB),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.flight_takeoff_rounded,
                color: Color(0xFF21536F),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trip.destination,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF20242C),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_formatDate(DateTime.parse(trip.startDate))} - ${_formatDate(DateTime.parse(trip.endDate))} • ${trip.tripDays} days',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.black.withOpacity(0.55),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF355264)),
          ],
        ),
      ),
    );
  }

  Widget _buildTripStatusCard(String title, TravelTrip trip) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(title),
          const SizedBox(height: 10),
          _buildPreviousTripCard(trip),
        ],
      ),
    );
  }

  String get _greetingName {
    final value = widget.userName.trim();
    if (value.isEmpty) return 'Traveler';
    return value[0].toUpperCase() + value.substring(1);
  }

  String get _totalExpenses {
    return '\$${travelData.currentTripExpenses.fold<double>(0, (sum, expense) => sum + expense.amount).toStringAsFixed(2)}';
  }

  String get _aiInsights {
    final focusPlace = travelData.topPicks.isNotEmpty
        ? travelData.topPicks.first.name
        : travelData.cityName;
    return 'Live nearby data suggests $focusPlace is one of the best stops to anchor your day in ${travelData.cityName}.';
  }

  String get _decision {
    return 'Cluster nearby attractions, one restaurant stop, and one museum to keep travel time low and the day balanced.';
  }

  String get _contextText {
    final connection = backendConnected
        ? 'Connected to TravelPilot AI'
        : 'Offline mode';
    return '$connection\nLoaded from OpenStreetMap for ${travelData.cityLabel} and cached locally for offline browsing after fetch.';
  }

  List<String> get _reminders {
    if (travelData.topPicks.isNotEmpty) {
      return [
        'Closest pick: ${travelData.topPicks.first.distanceKm.toStringAsFixed(1)} km away',
        '${travelData.places.length} nearby places loaded',
      ];
    }
    return const [
      'Daily limit: \$200.00',
      '+\$15.00 today',
    ];
  }

  Widget _buildSectionHeader(String title, {String? action}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF20242C),
          ),
        ),
        if (action != null)
          Text(
            action,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4D87AA),
            ),
          ),
      ],
    );
  }

  Widget _buildHeroCard() {
    return GestureDetector(
      onTap: _openTripSearch,
      child: Container(
        height: 196,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2AA8D4), Color(0xFF123F75)],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26123F75),
              blurRadius: 20,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              left: -10,
              top: 40,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              right: -28,
              bottom: -36,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.55),
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8DE8E0),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                backendConnected ? 'CONNECTED' : 'OFFLINE',
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0E5469),
                                ),
                              ),
                            ),
                            const Spacer(),
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.20),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.notifications_none_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          travelData.cityName.isEmpty
                              ? 'TravelPilot AI'
                              : '${travelData.cityName} Explorer',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 25,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          travelData.cityLabel.isEmpty
                              ? 'Plan smarter. Travel better.'
                              : travelData.cityLabel,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.78),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const Positioned(
              right: 18,
              bottom: 18,
              child: CircleAvatar(
                radius: 19,
                backgroundColor: Color(0x33FFFFFF),
                child: Icon(
                  Icons.share_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpendCard() {
    final reminders = _reminders;
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ExpenseScreen()),
        );
      },
      child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SPENT SO FAR',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.black.withOpacity(0.35),
                  letterSpacing: 0.9,
                ),
              ),
              const Text(
                '76% of budget',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2FA7A2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _totalExpenses,
            style: const TextStyle(
              fontSize: 29,
              fontWeight: FontWeight.w900,
              color: Color(0xFF173D56),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: const [
              _Bar(height: 14, color: Color(0xFFD6E1EA)),
              SizedBox(width: 6),
              _Bar(height: 22, color: Color(0xFFD6E1EA)),
              SizedBox(width: 6),
              _Bar(height: 12, color: Color(0xFFD6E1EA)),
              SizedBox(width: 6),
              _Bar(height: 28, color: Color(0xFF1C638C)),
              SizedBox(width: 6),
              _Bar(height: 16, color: Color(0xFFD6E1EA)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(
                Icons.circle,
                size: 8,
                color: Color(0xFF8E97A3),
              ),
              const SizedBox(width: 6),
              Text(
                reminders.isNotEmpty ? reminders.first : 'Daily limit: \$200.00',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.black.withOpacity(0.55),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                reminders.length > 1 ? reminders[1] : '+\$15.00 today',
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFFE15555),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildPickCard({
    required String title,
    required String subtitle,
    required List<Color> colors,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
      width: 118,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 86,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: colors,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: Colors.black.withOpacity(0.35),
                      letterSpacing: 0.7,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF20242C),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Near your stay',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.black.withOpacity(0.45),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildMemoryCard(String label, List<Color> colors) {
    return Container(
      width: 72,
      height: 72,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(colors: colors),
      ),
      alignment: Alignment.bottomLeft,
      padding: const EdgeInsets.all(8),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildMapCard() {
    final featuredPlace = travelData.selectedPlace ??
        (travelData.topPicks.isNotEmpty ? travelData.topPicks.first : null);
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const MapScreen()),
        );
      },
      child: Container(
      height: 122,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFFDFF2F3),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _MapPainter()),
          ),
          Positioned(
            left: 18,
            top: 18,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Destination\n${featuredPlace?.name ?? travelData.cityName}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF395061),
                ),
              ),
            ),
          ),
          Positioned(
            right: 18,
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFF0B5F8E),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'Open Maps',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const Positioned(
            left: 42,
            bottom: 28,
            child: Icon(
              Icons.location_on_rounded,
              color: Color(0xFF7AC54B),
              size: 22,
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildBody() {
    return isLoading
        ? const Center(child: CircularProgressIndicator())
        : Stack(
            children: [
              !travelData.hasSelectedCity
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Text(
                              'No trips yet',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Tap + to plan trip',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 15),
                            ),
                          ],
                        ),
                      ),
                    )
                  : errorMessage != null && travelData.places.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _retryCurrentCity,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadDashboardData,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
                        children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
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
                          onPressed: _openTripSearch,
                          icon: const Icon(
                            Icons.add_circle_outline_rounded,
                            color: Color(0xFF173D56),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ProfileScreen(
                                  userName: widget.userName,
                                  userEmail: widget.userEmail,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.person_outline_rounded,
                            color: Color(0xFF173D56),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildHeroCard(),
                    const SizedBox(height: 16),
                    _buildSpendCard(),
                    if (travelData.activeTrip != null)
                      _buildTripStatusCard('Active Trip', travelData.activeTrip!),
                    if (travelData.upcomingTrip != null)
                      _buildTripStatusCard(
                        'Upcoming Trip',
                        travelData.upcomingTrip!,
                      ),
                    if (travelData.pastTrips.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      _buildSectionHeader('Past Trips'),
                      const SizedBox(height: 12),
                      ...travelData.pastTrips
                          .take(2)
                          .map(_buildPreviousTripCard),
                    ],
                    const SizedBox(height: 18),
                    _buildSectionHeader('Top picks for $_greetingName'),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 180,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: _topPickCards(),
                      ),
                    ),
                    const SizedBox(height: 18),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const MemoryScreen()),
                        );
                      },
                      child: _buildSectionHeader('Memories', action: 'View All'),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _dashboardMemories(),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _buildMapCard(),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI insight',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black.withOpacity(0.4),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _aiInsights,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF223140),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _decision,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black.withOpacity(0.58),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _contextText,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.black.withOpacity(0.46),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _AgentChip('Planner agent active'),
                              _AgentChip('Expense agent active'),
                              _AgentChip('Memory agent active'),
                              _AgentChip(
                                travelData.tripIsActive
                                    ? 'Tracking agent active'
                                    : 'Tracking agent standby',
                              ),
                              _AgentChip(
                                travelData.tripIsActive
                                    ? 'Reminder agent active'
                                    : 'Reminder agent standby',
                              ),
                            ],
                          ),
                          if (travelData.activeReminders.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            ...travelData.activeReminders.map(
                              (reminder) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  reminder,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.black.withOpacity(0.52),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                        ],
                      ),
                    ),
              Positioned(
                right: 16,
                bottom: 16,
                child: FloatingActionButton(
                  onPressed: _openTripSearch,
                  backgroundColor: const Color(0xFF0B5F8E),
                  foregroundColor: Colors.white,
                  child: const Icon(Icons.add_rounded),
                ),
              ),
            ],
          );
  }

  List<Widget> _topPickCards() {
    if (travelData.topPicks.isEmpty) {
      return [
        _buildPickCard(
          title: 'Live picks loading',
          subtitle: 'NEARBY',
          colors: const [Color(0xFFBABF9D), Color(0xFFEAE3CE)],
        ),
      ];
    }

    final palettes = <List<Color>>[
      const [Color(0xFFBABF9D), Color(0xFFEAE3CE)],
      const [Color(0xFF2AB6A1), Color(0xFF72E0D1)],
      const [Color(0xFF7186C8), Color(0xFFB8C6F2)],
    ];

    return travelData.topPicks.asMap().entries.map((entry) {
      final place = entry.value;
      return _buildPickCard(
        title: place.name,
        subtitle:
            '${place.category.toUpperCase()} • ${place.distanceKm.toStringAsFixed(1)} km',
        colors: palettes[entry.key % palettes.length],
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const TravelPlannerScreen()),
          );
        },
      );
    }).toList();
  }

  List<Widget> _dashboardMemories() {
    if (travelData.memories.isEmpty) {
      return [
        _buildMemoryCard(
          'Memories',
          const [Color(0xFFE5DED2), Color(0xFFCFC8BA)],
        ),
      ];
    }

    final palettes = <List<Color>>[
      const [Color(0xFFE5DED2), Color(0xFFCFC8BA)],
      const [Color(0xFFE9DDCD), Color(0xFFF7F2EA)],
      const [Color(0xFF9FB7A9), Color(0xFFE6EFE8)],
      const [Color(0xFFADA59C), Color(0xFF756E67)],
    ];

    return travelData.memories.take(4).toList().asMap().entries.map((entry) {
      final words = entry.value.description.split(' ');
      final label = words.isEmpty ? 'Trip' : words.first;
      return _buildMemoryCard(
        label,
        palettes[entry.key % palettes.length],
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return _buildBody();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(title: const Text('Dashboard')),
      body: SafeArea(child: _buildBody()),
    );
  }
}

class _Bar extends StatelessWidget {
  final double height;
  final Color color;

  const _Bar({required this.height, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class _AgentChip extends StatelessWidget {
  final String label;

  const _AgentChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F4FB),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: Color(0xFF21536F),
        ),
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = const Color(0xFFB6DDE0)
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final accentPaint = Paint()
      ..color = const Color(0xFF80C8C1)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(0, size.height * 0.30)
      ..quadraticBezierTo(
        size.width * 0.25,
        size.height * 0.10,
        size.width * 0.48,
        size.height * 0.38,
      )
      ..quadraticBezierTo(
        size.width * 0.72,
        size.height * 0.66,
        size.width,
        size.height * 0.45,
      );

    final path2 = Path()
      ..moveTo(size.width * 0.15, size.height)
      ..quadraticBezierTo(
        size.width * 0.25,
        size.height * 0.68,
        size.width * 0.45,
        size.height * 0.75,
      )
      ..quadraticBezierTo(
        size.width * 0.70,
        size.height * 0.84,
        size.width * 0.86,
        size.height * 0.16,
      );

    canvas.drawPath(path, roadPaint);
    canvas.drawPath(path2, accentPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
