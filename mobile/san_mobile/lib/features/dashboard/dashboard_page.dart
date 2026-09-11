import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/auth_controller.dart';
import '../../core/app_theme.dart';
import '../ngo/deliveries_page.dart';
import '../ngo/ngo_donations_page.dart';
import '../public/create_donation_page.dart';
import '../public/my_dependents_page.dart';
import '../public/my_donations_page.dart';
import '../public/my_aid_requests_page.dart';
import '../pps/pps_my_bookings_page.dart';
import 'dashboard_api.dart';
import '../shell/app_shell.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  final DashboardApi _api = DashboardApi();
  Future<Map<String, dynamic>>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final role = ref.read(authControllerProvider).user?.role ?? '';
    if (role == 'NGO_STAFF' || role == 'ADMIN') {
      _future = _api.fetchNgoDashboard();
    } else {
      _future = _api.fetchPublicDashboard();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final role = auth.user?.role ?? '';
    final name = auth.user?.fullName ?? 'there';
    final isNgo = role == 'NGO_STAFF' || role == 'ADMIN';

    return Scaffold(
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _ErrorView(
              message: snapshot.error.toString(),
              onRetry: _load,
            );
          }

          final data = (snapshot.data ?? {}).cast<String, dynamic>();

          if (data['ok'] != true) {
            return _ErrorView(
              message: (data['error'] ?? 'Dashboard failed').toString(),
              onRetry: _load,
            );
          }

          if (isNgo) {
            return _NgoDashboardHome(
              data: data,
              name: name,
              onRefresh: () async => _load(),
            );
          }

          return _PublicDashboardView(
            data: data,
            name: name,
            onRefresh: () async => _load(),
          );
        },
      ),
    );
  }
}

/* ───────────────────────── NGO DASHBOARD ───────────────────────── */

class _NgoDashboardHome extends StatelessWidget {
  final Map<String, dynamic> data;
  final String name;
  final Future<void> Function() onRefresh;

  const _NgoDashboardHome({
    required this.data,
    required this.name,
    required this.onRefresh,
  });

  int _asInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  double _asDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  Color _deliveryColor(String status, ColorScheme scheme) {
    switch (status) {
      case 'ROUTED':
        return scheme.secondary;
      case 'PLANNED':
        return Colors.amber;
      case 'IN_TRANSIT':
        return scheme.primary;
      case 'DELIVERED':
        return Colors.green;
      case 'CANCELLED':
        return scheme.error;
      default:
        return scheme.onSurface.withValues(alpha:0.5);
    }
  }

  IconData _deliveryIcon(String status) {
    switch (status) {
      case 'ROUTED':
        return Icons.route;
      case 'PLANNED':
        return Icons.event_note;
      case 'IN_TRANSIT':
        return Icons.local_shipping;
      case 'DELIVERED':
        return Icons.check_circle;
      case 'CANCELLED':
        return Icons.cancel;
      default:
        return Icons.inventory_2;
    }
  }

  String _deliveryLabel(String status) {
    switch (status) {
      case 'IN_TRANSIT':
        return 'In Transit';
      case 'DELIVERED':
        return 'Completed';
      case 'PLANNED':
        return 'Pending';
      default:
        return status;
    }
  }

  Color _donationStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
        return Colors.green;
      case 'CONFIRMED':
        return Colors.blue;
      case 'PENDING':
        return Colors.orange;
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final summary = (data['summary'] as Map).cast<String, dynamic>();

    final byDeliveryStatus =
        (summary['deliveries_by_status'] as Map).cast<String, dynamic>();

    final byDonationStatus =
        (summary['donations_by_status'] as Map?)?.cast<String, dynamic>() ??
            const {};

    final byDonationType =
        (summary['donations_by_type'] as Map?)?.cast<String, dynamic>() ??
            const {};

    final upcoming = (summary['upcoming_deliveries'] as List? ?? [])
        .cast<dynamic>()
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();

    final recentDonations = (summary['recent_donations'] as List? ?? [])
        .cast<dynamic>()
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();

    final routed = _asInt(byDeliveryStatus['ROUTED']);
    final planned = _asInt(byDeliveryStatus['PLANNED']);
    final inTransit = _asInt(byDeliveryStatus['IN_TRANSIT']);
    final delivered = _asInt(byDeliveryStatus['DELIVERED']);

    final deliveryActive = routed + planned + inTransit;

    final donationPending = _asInt(byDonationStatus['PENDING']);
    final donationConfirmed = _asInt(byDonationStatus['CONFIRMED']);
    final donationCompleted = _asInt(byDonationStatus['COMPLETED']);
    final donationTotal = donationPending +
        donationConfirmed +
        donationCompleted +
        _asInt(byDonationStatus['CANCELLED']);

    final moneyDonations = _asInt(byDonationType['MONEY']);
    final itemDonations = _asInt(byDonationType['ITEM']);
    final totalMoneyReceived = _asDouble(summary['total_money_received']);
    final dropoffWaiting = _asInt(summary['dropoff_waiting']);
    final proofUploaded = _asInt(summary['proof_uploaded']);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _DashboardHero(
              icon: Icons.dashboard_customize_rounded,
              title: 'NGO Operations Hub',
              subtitle:
                  'Hi $name, monitor donations, deliveries, proof submissions, and today’s relief operations.',
              stats: [
                _HeroStatData(
                  icon: Icons.volunteer_activism,
                  label: 'Donations',
                  value: donationTotal.toString(),
                ),
                _HeroStatData(
                  icon: Icons.local_shipping_outlined,
                  label: 'Active Delivery',
                  value: deliveryActive.toString(),
                ),
                _HeroStatData(
                  icon: Icons.payments_outlined,
                  label: 'Funds',
                  value: 'RM ${totalMoneyReceived.toStringAsFixed(0)}',
                ),
              ],
              pills: [
                _HeroPillData(
                  icon: Icons.inventory_2_outlined,
                  label: '$itemDonations Item',
                ),
                _HeroPillData(
                  icon: Icons.account_balance_wallet_outlined,
                  label: '$moneyDonations Money',
                ),
                _HeroPillData(
                  icon: Icons.photo_camera_outlined,
                  label: '$proofUploaded Proof',
                ),
              ],
              alert: dropoffWaiting > 0
                  ? '$dropoffWaiting item donation${dropoffWaiting == 1 ? '' : 's'} waiting for donor drop-off confirmation.'
                  : null,
            ),
          ),

          SliverToBoxAdapter(
            child: _NgoTodayPriorityCard(
              donationPending: donationPending,
              donationConfirmed: donationConfirmed,
              donationCompleted: donationCompleted,
              deliveryActive: deliveryActive,
              inTransit: inTransit,
              dropoffWaiting: dropoffWaiting,
              onOpenDonations: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NgoDonationsPage()),
                );
              },
              onOpenDeliveries: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DeliveriesPage()),
                );
              },
            ),
          ),

          SliverToBoxAdapter(
            child: _DashboardSnapshotStrip(
              title: 'Operations Snapshot',
              subtitle: 'A quick view of today’s NGO workload',
              items: [
                _SnapshotItem(
                  icon: Icons.volunteer_activism,
                  label: 'Donations',
                  value: donationTotal.toString(),
                  color: colorScheme.primary,
                ),
                _SnapshotItem(
                  icon: Icons.inventory_2_outlined,
                  label: 'Item Aid',
                  value: itemDonations.toString(),
                  color: colorScheme.secondary,
                ),
                _SnapshotItem(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Money Aid',
                  value: moneyDonations.toString(),
                  color: Colors.indigo,
                ),
                _SnapshotItem(
                  icon: Icons.photo_camera_outlined,
                  label: 'Proofs',
                  value: proofUploaded.toString(),
                  color: Colors.teal,
                ),
                _SnapshotItem(
                  icon: Icons.route_outlined,
                  label: 'Routed',
                  value: routed.toString(),
                  color: _deliveryColor('ROUTED', colorScheme),
                ),
                _SnapshotItem(
                  icon: Icons.local_shipping_outlined,
                  label: 'In Transit',
                  value: inTransit.toString(),
                  color: _deliveryColor('IN_TRANSIT', colorScheme),
                ),
              ],
            ),
          ),

          SliverToBoxAdapter(
            child: _MainActionPanel(
              title: 'Main Workflows',
              subtitle: 'Go directly to the work that matters most',
              primaryTitle: 'Manage Donations',
              primarySubtitle: 'Verify donor drop-offs, proofs, and money donations',
              primaryIcon: Icons.volunteer_activism,
              primaryColor: colorScheme.primary,
              onPrimaryTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NgoDonationsPage()),
                );
              },
              secondaryTitle: 'Manage Deliveries',
              secondarySubtitle: 'Plan, route, and monitor aid delivery progress',
              secondaryIcon: Icons.local_shipping_outlined,
              secondaryColor: colorScheme.secondary,
              onSecondaryTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DeliveriesPage()),
                );
              },
              footerActions: [
                _MiniDashboardAction(
                  icon: Icons.map_outlined,
                  label: 'Map',
                  onTap: () {
                    AppTabController.openMapTab();
                  },
                ),
                _MiniDashboardAction(
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                  onTap: () {
                    AppTabController.openSettingsTab();
                  },
                ),
              ],
            ),
          ),

          SliverToBoxAdapter(
            child: _RecentNgoDonations(
              donations: recentDonations,
              statusColor: _donationStatusColor,
            ),
          ),

          SliverToBoxAdapter(
            child: _ActiveDeliveriesCard(
              deliveries: upcoming,
              statusLabel: _deliveryLabel,
              statusColor: (s) => _deliveryColor(s, colorScheme),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

/* ───────────────────────── PUBLIC DASHBOARD ───────────────────────── */

class _PublicDashboardView extends StatelessWidget {
  final Map<String, dynamic> data;
  final String name;
  final Future<void> Function() onRefresh;

  const _PublicDashboardView({
    required this.data,
    required this.name,
    required this.onRefresh,
  });

  int _asInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  double _asDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
        return Colors.green;
      case 'CONFIRMED':
        return Colors.blue;
      case 'PENDING':
        return Colors.orange;
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _typeIcon(String type) {
    return type.toUpperCase() == 'MONEY'
        ? Icons.account_balance_wallet_outlined
        : Icons.inventory_2_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final summary = (data['summary'] as Map).cast<String, dynamic>();

    final donationStats =
        (summary['my_donation_stats'] as Map).cast<String, dynamic>();

    final donationTypes =
        (summary['my_donation_type_stats'] as Map?)?.cast<String, dynamic>() ??
            const {};

    final shelterRequestStats =
        (summary['shelter_request_stats'] as Map?)?.cast<String, dynamic>() ??
            const {};

    final recentDonations = (data['recent_donations'] as List? ?? [])
        .cast<dynamic>()
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();

    final recentShelterRequests =
        (data['recent_shelter_requests'] as List? ?? [])
            .cast<dynamic>()
            .map((e) => (e as Map).cast<String, dynamic>())
            .toList();

    final totalShelters = _asInt(summary['total_shelters']);
    final totalNgos = _asInt(summary['total_ngos']);
    final availableCapacity = _asInt(summary['available_shelter_capacity']);
    final activeDependents = _asInt(summary['active_dependents']);

    final pending = _asInt(donationStats['PENDING']);
    final confirmed = _asInt(donationStats['CONFIRMED']);
    final completed = _asInt(donationStats['COMPLETED']);
    final cancelled = _asInt(donationStats['CANCELLED']);
    final totalDonations = pending + confirmed + completed + cancelled;

    final moneyDonationCount = _asInt(donationTypes['MONEY']);
    final itemDonationCount = _asInt(donationTypes['ITEM']);
    final totalAmount = _asDouble(summary['my_total_donation_amount']);

    final requestPending = _asInt(shelterRequestStats['PENDING']);
    final requestConfirmed = _asInt(shelterRequestStats['CONFIRMED']);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _PublicHeroBanner(
              name: name,
              totalDonations: totalDonations,
              completed: completed,
              activeDependents: activeDependents,
            ),
          ),

          SliverToBoxAdapter(
            child: _PublicStatusCard(
              pendingDonations: pending,
              requestPending: requestPending,
              requestConfirmed: requestConfirmed,
              availableCapacity: availableCapacity,
              onAidRequests: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MyAidRequestsPage()),
                );
              },
              onPps: () {
                AppTabController.openPpsBookingTab();
              },
              onDonations: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MyDonationsPage()),
                );
              },
            ),
          ),

          SliverToBoxAdapter(
            child: _PublicQuickActionsSection(
              onAidRequests: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MyAidRequestsPage()),
                );
              },
              onDonate: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CreateDonationPage()),
                );
              },
              onMyDonations: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MyDonationsPage()),
                );
              },
              onPps: () {
                AppTabController.openPpsBookingTab();
              },
              onDependents: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MyDependentsPage()),
                );
              },
              onMap: () {
                AppTabController.openMapTab();
              },
            ),
          ),

          SliverToBoxAdapter(
            child: _PublicActivityCard(
              totalDonations: totalDonations,
              completed: completed,
              moneyDonationCount: moneyDonationCount,
              itemDonationCount: itemDonationCount,
              activeDependents: activeDependents,
              totalAmount: totalAmount,
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
              child: const _ModernSectionHeader(
                title: 'Donation Activity',
                subtitle: 'Latest contribution records and donation updates',
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: _RecentPublicDonations(
              donations: recentDonations,
              statusColor: _statusColor,
              typeIcon: _typeIcon,
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
              child: const _ModernSectionHeader(
                title: 'Shelter Requests',
                subtitle: 'Monitor shelter booking requests and approvals',
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: _RecentShelterRequests(
              requests: recentShelterRequests,
              statusColor: _statusColor,
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

class _PublicHeroBanner extends StatelessWidget {
  final String name;
  final int totalDonations;
  final int completed;
  final int activeDependents;

  const _PublicHeroBanner({
    required this.name,
    required this.totalDonations,
    required this.completed,
    required this.activeDependents,
  });

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final firstName = name.trim().isEmpty ? 'there' : name.trim().split(' ').first;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF005B89),
              Color(0xFF0087C7),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF005B89).withValues(alpha:0.22),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$_greeting 👋',
              style: TextStyle(
                color: Colors.white.withValues(alpha:0.82),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              firstName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Stay connected with shelters, aid requests, donations and nearby support.',
              style: TextStyle(
                color: Colors.white.withValues(alpha:0.84),
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _HeroMiniStat(value: totalDonations.toString(), label: 'Donations'),
                _HeroMiniStat(value: completed.toString(), label: 'Completed'),
                _HeroMiniStat(value: activeDependents.toString(), label: 'Family'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroMiniStat extends StatelessWidget {
  final String value;
  final String label;

  const _HeroMiniStat({
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha:0.16),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha:0.75),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PublicStatusCard extends StatelessWidget {
  final int pendingDonations;
  final int requestPending;
  final int requestConfirmed;
  final int availableCapacity;
  final VoidCallback onAidRequests;
  final VoidCallback onPps;
  final VoidCallback onDonations;

  const _PublicStatusCard({
    required this.pendingDonations,
    required this.requestPending,
    required this.requestConfirmed,
    required this.availableCapacity,
    required this.onAidRequests,
    required this.onPps,
    required this.onDonations,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon;
    String title;
    String subtitle;
    String buttonText;
    VoidCallback action;
    Color color;

    if (requestPending > 0) {
      icon = Icons.hourglass_top_rounded;
      title = 'PPS Request Pending';
      subtitle = 'Your shelter request is waiting for confirmation.';
      buttonText = 'View Status';
      action = onPps;
      color = Colors.orange;
    } else if (requestConfirmed > 0) {
      icon = Icons.verified_rounded;
      title = 'PPS Booking Confirmed';
      subtitle = 'Your shelter booking has been approved.';
      buttonText = 'View Booking';
      action = onPps;
      color = Colors.green;
    } else if (pendingDonations > 0) {
      icon = Icons.volunteer_activism;
      title = 'Donation In Progress';
      subtitle = 'You have a donation that still needs follow-up.';
      buttonText = 'View Donations';
      action = onDonations;
      color = const Color(0xFF005B89);
    } else {
      icon = Icons.handshake_outlined;
      title = 'Need Help Today?';
      subtitle = availableCapacity > 0
          ? '$availableCapacity shelter places are currently available.'
          : 'Submit an aid request or find nearby support.';
      buttonText = 'Request Aid';
      action = onAidRequests;
      color = const Color(0xFF005B89);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha:0.06),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha:0.10),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: Colors.black.withValues(alpha:0.55), fontSize: 12)),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 34,
                    child: FilledButton(
                      onPressed: action,
                      child: Text(buttonText),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PublicQuickActionsSection extends StatelessWidget {
  final VoidCallback onAidRequests;
  final VoidCallback onDonate;
  final VoidCallback onMyDonations;
  final VoidCallback onPps;
  final VoidCallback onDependents;
  final VoidCallback onMap;

  const _PublicQuickActionsSection({
    required this.onAidRequests,
    required this.onDonate,
    required this.onMyDonations,
    required this.onPps,
    required this.onDependents,
    required this.onMap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ModernSectionHeader(
            title: 'Quick Actions',
            subtitle: 'Choose what you want to do',
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 0.95,
              children: [
                _QuickActionTile(
                  title: 'Aid Request',
                  subtitle: 'Ask for needed items',
                  icon: Icons.handshake_outlined,
                  iconColor: const Color(0xFF1683D8),
                  iconBg: const Color(0xFFF7F9FC),
                  onTap: onAidRequests,
                ),
                _QuickActionTile(
                  title: 'Donate Aid',
                  subtitle: 'Give items or money',
                  icon: Icons.volunteer_activism,
                  iconColor: const Color(0xFFFF6B2C),
                  iconBg: const Color(0xFFF7F9FC),
                  onTap: onDonate,
                ),
                _QuickActionTile(
                  title: 'PPS Booking',
                  subtitle: 'Check shelter request status',
                  icon: Icons.meeting_room_outlined,
                  iconColor: const Color(0xFF6C4FE0),
                  iconBg: const Color(0xFFF7F9FC),
                  onTap: onPps,
                ),
                _QuickActionTile(
                  title: 'Aid Map',
                  subtitle: 'Find nearby shelters and NGOs',
                  icon: Icons.map_outlined,
                  iconColor: const Color(0xFF14A99A),
                  iconBg: const Color(0xFFF7F9FC),
                  onTap: onMap,
                ),
                _QuickActionTile(
                  title: 'My Donations',
                  subtitle: 'Track your contributions',
                  icon: Icons.receipt_long_outlined,
                  iconColor: const Color(0xFF35A852),
                  iconBg: const Color(0xFFF7F9FC),
                  onTap: onMyDonations,
                ),
                _QuickActionTile(
                  title: 'Dependents',
                  subtitle: 'Manage family members',
                  icon: Icons.family_restroom,
                  iconColor: const Color(0xFF9333EA),
                  iconBg: const Color(0xFFF7F9FC),
                  onTap: onDependents,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: iconBg,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Stack(
            children: [
              Positioned(
                right: 0,
                bottom: 4,
                child: Icon(
                  Icons.chevron_right,
                  color: iconColor.withValues(alpha: 0.55),
                  size: 24,
                ),
              ),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(icon, color: iconColor, size: 28),
                  ),

                  const Spacer(),

                  Padding(
                    padding: const EdgeInsets.only(right: 18),
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                  ),

                  const SizedBox(height: 5),

                  Padding(
                    padding: const EdgeInsets.only(right: 18),
                    child: Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.50),
                        fontSize: 12,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
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
}

class _PublicActivityCard extends StatelessWidget {
  final int totalDonations;
  final int completed;
  final int moneyDonationCount;
  final int itemDonationCount;
  final int activeDependents;
  final double totalAmount;

  const _PublicActivityCard({
    required this.totalDonations,
    required this.completed,
    required this.moneyDonationCount,
    required this.itemDonationCount,
    required this.activeDependents,
    required this.totalAmount,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your Activity', style: TextStyle(color: Colors.white.withValues(alpha:0.70), fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Row(
              children: [
                _ActivityNumber(value: totalDonations.toString(), label: 'Donations'),
                _ActivityNumber(value: completed.toString(), label: 'Completed'),
                _ActivityNumber(value: activeDependents.toString(), label: 'Family'),
              ],
            ),
            const Divider(height: 24, color: Colors.white24),
            Row(
              children: [
                Expanded(child: Text('Money: $moneyDonationCount', style: const TextStyle(color: Colors.white70, fontSize: 12))),
                Expanded(child: Text('Items: $itemDonationCount', style: const TextStyle(color: Colors.white70, fontSize: 12))),
                Expanded(child: Text('RM ${totalAmount.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white70, fontSize: 12))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityNumber extends StatelessWidget {
  final String value;
  final String label;

  const _ActivityNumber({
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha:0.62), fontSize: 11)),
        ],
      ),
    );
  }
}

class _ModernSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _ModernSectionHeader({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(subtitle, style: TextStyle(color: Colors.black.withValues(alpha:0.45), fontSize: 12)),
      ],
    );
  }
}

/* ───────────────────────── SHARED UI ───────────────────────── */

class _DashboardHero extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<_HeroStatData> stats;
  final List<_HeroPillData> pills;
  final String? alert;

  const _DashboardHero({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.stats,
    required this.pills,
    this.alert,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.darkAzure, AppColors.azure],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha:0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha:0.85),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              for (int i = 0; i < stats.length; i++) ...[
                Expanded(child: _HeroStat(data: stats[i])),
                if (i != stats.length - 1) const SizedBox(width: 10),
              ],
            ],
          ),
          if (pills.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                for (int i = 0; i < pills.length; i++) ...[
                  Expanded(child: _HeroPill(data: pills[i])),
                  if (i != pills.length - 1) const SizedBox(width: 8),
                ],
              ],
            ),
          ],
          if (alert != null && alert!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha:0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.notifications_active_outlined,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      alert!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroStatData {
  final IconData icon;
  final String label;
  final String value;

  const _HeroStatData({
    required this.icon,
    required this.label,
    required this.value,
  });
}

class _HeroPillData {
  final IconData icon;
  final String label;

  const _HeroPillData({
    required this.icon,
    required this.label,
  });
}

class _HeroStat extends StatelessWidget {
  final _HeroStatData data;

  const _HeroStat({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha:0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(data.icon, color: Colors.white, size: 20),
          const SizedBox(height: 4),
          Text(
            data.value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            data.label,
            style: TextStyle(
              color: Colors.white.withValues(alpha:0.8),
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  final _HeroPillData data;

  const _HeroPill({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha:0.13),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(data.icon, color: Colors.white, size: 14),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              data.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  final ColorScheme colorScheme;

  const _SectionTitle({
    required this.title,
    required this.subtitle,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 36,
          decoration: BoxDecoration(
            color: colorScheme.primary,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.primary,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurface.withValues(alpha:0.55),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/* ───────────────────────── RECENT LISTS ───────────────────────── */

class _RecentPublicDonations extends StatelessWidget {
  final List<Map<String, dynamic>> donations;
  final Color Function(String status) statusColor;
  final IconData Function(String type) typeIcon;

  const _RecentPublicDonations({
    required this.donations,
    required this.statusColor,
    required this.typeIcon,
  });

  @override
  Widget build(BuildContext context) {
    return _RecentCardShell(
      title: 'Recent Donations',
      subtitle: 'Latest contribution records',
      icon: Icons.volunteer_activism,
      actionLabel: 'View All',
      onAction: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const MyDonationsPage()),
        );
      },
      emptyText: 'No donations yet. Start by making your first contribution.',
      children: donations.map((d) {
        final id = d['donation_id']?.toString() ?? '';
        final type = d['donation_type']?.toString() ?? '';
        final status = d['status']?.toString() ?? '';
        final ngo = d['ngo_name']?.toString() ?? 'General Donation';
        final amount = d['payment_amount']?.toString() ?? '';
        final currency = d['payment_currency']?.toString() ?? 'MYR';

        return _ActivityTile(
          icon: typeIcon(type),
          title: 'Donation #$id • ${type == 'MONEY' ? 'Money' : 'Items'}',
          subtitle: type == 'MONEY' && amount.isNotEmpty
              ? '$ngo • $currency $amount'
              : ngo,
          badge: status,
          badgeColor: statusColor(status),
        );
      }).toList(),
    );
  }
}

class _RecentNgoDonations extends StatelessWidget {
  final List<Map<String, dynamic>> donations;
  final Color Function(String status) statusColor;

  const _RecentNgoDonations({
    required this.donations,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return _RecentCardShell(
      title: 'Recent Donations',
      subtitle: 'Latest incoming donor activity',
      icon: Icons.volunteer_activism,
      actionLabel: 'Manage',
      onAction: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NgoDonationsPage()),
        );
      },
      emptyText: 'No incoming donations yet.',
      children: donations.map((d) {
        final id = d['donation_id']?.toString() ?? '';
        final type = d['donation_type']?.toString() ?? '';
        final status = d['status']?.toString() ?? '';
        final donor = d['donor_name']?.toString() ?? 'Unknown donor';
        final amount = d['payment_amount']?.toString() ?? '';
        final currency = d['payment_currency']?.toString() ?? 'MYR';
        final hasProof =
            (d['proof_photo_url']?.toString().trim() ?? '').isNotEmpty;

        return _ActivityTile(
          icon: type == 'MONEY'
              ? Icons.account_balance_wallet_outlined
              : Icons.inventory_2_outlined,
          title: 'Donation #$id • $donor',
          subtitle: type == 'MONEY' && amount.isNotEmpty
              ? '$currency $amount${hasProof ? ' • Proof uploaded' : ''}'
              : '${type == 'MONEY' ? 'Money' : 'Item'} donation${hasProof ? ' • Proof uploaded' : ''}',
          badge: status,
          badgeColor: statusColor(status),
        );
      }).toList(),
    );
  }
}

class _ActiveDeliveriesCard extends StatelessWidget {
  final List<Map<String, dynamic>> deliveries;
  final String Function(String status) statusLabel;
  final Color Function(String status) statusColor;

  const _ActiveDeliveriesCard({
    required this.deliveries,
    required this.statusLabel,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return _RecentCardShell(
      title: 'Delivery Activity',
      subtitle: 'Upcoming and recent delivery movements',
      icon: Icons.local_shipping_outlined,
      actionLabel: 'View All',
      onAction: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const DeliveriesPage()),
        );
      },
      emptyText: 'No delivery activity available.',
      children: deliveries.take(5).map((d) {
        final id = d['delivery_id']?.toString() ?? '';
        final status = d['status']?.toString() ?? '';
        final shelterName = d['shelter_name']?.toString() ?? 'Unknown Shelter';
        final scheduledDate = d['scheduled_date']?.toString() ?? '';
        final eta = d['eta_minutes']?.toString() ?? '';

        final subtitle = eta.isNotEmpty
            ? '$shelterName • ETA $eta min'
            : scheduledDate.isNotEmpty
                ? '$shelterName • $scheduledDate'
                : shelterName;

        return _ActivityTile(
          icon: Icons.local_shipping_outlined,
          title: 'Delivery #$id',
          subtitle: subtitle,
          badge: statusLabel(status),
          badgeColor: statusColor(status),
        );
      }).toList(),
    );
  }
}

class _RecentShelterRequests extends StatelessWidget {
  final List<Map<String, dynamic>> requests;
  final Color Function(String status) statusColor;

  const _RecentShelterRequests({
    required this.requests,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return _RecentCardShell(
      title: 'Recent PPS Requests',
      subtitle: 'Your latest shelter booking activity',
      icon: Icons.meeting_room_outlined,
      actionLabel: 'View',
      onAction: () {
        AppTabController.openPpsBookingTab();
      },  
      emptyText: 'No PPS requests yet.',
      children: requests.map((r) {
        final id = r['request_id']?.toString() ?? '';
        final status = r['status']?.toString() ?? '';
        final shelter = r['shelter_name']?.toString() ?? 'Shelter';
        final total = r['total_people']?.toString() ?? '0';

        return _ActivityTile(
          icon: Icons.meeting_room_outlined,
          title: 'Request #$id • $shelter',
          subtitle: '$total people',
          badge: status,
          badgeColor: statusColor(status),
        );
      }).toList(),
    );
  }
}

class _RecentCardShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String actionLabel;
  final VoidCallback onAction;
  final String emptyText;
  final List<Widget> children;

  const _RecentCardShell({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.actionLabel,
    required this.onAction,
    required this.emptyText,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 2, 14, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              Row(
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: colorScheme.primary,
                  ),

                  const SizedBox(width: 9),

                  Text(
                    title.contains('Donation')
                        ? 'Donation List'
                        : 'Request List',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.primary,
                    ),
                  ),

                  const Spacer(),

                  TextButton(
                    onPressed: onAction,
                    child: Text(actionLabel),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              if (children.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 18, 8, 22),
                  child: Text(
                    emptyText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha:0.55),
                    ),
                  ),
                )
              else
                ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final Color badgeColor;

  const _ActivityTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha:0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: colorScheme.primary, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withValues(alpha:0.58),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha:0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              badge,
              style: TextStyle(
                color: badgeColor,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NgoTodayPriorityCard extends StatelessWidget {
  final int donationPending;
  final int donationConfirmed;
  final int donationCompleted;
  final int deliveryActive;
  final int inTransit;
  final int dropoffWaiting;
  final VoidCallback onOpenDonations;
  final VoidCallback onOpenDeliveries;

  const _NgoTodayPriorityCard({
    required this.donationPending,
    required this.donationConfirmed,
    required this.donationCompleted,
    required this.deliveryActive,
    required this.inTransit,
    required this.dropoffWaiting,
    required this.onOpenDonations,
    required this.onOpenDeliveries,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    String title;
    String subtitle;
    IconData icon;
    Color color;
    String buttonLabel;
    VoidCallback action;

    if (dropoffWaiting > 0) {
      title = 'Drop-off confirmation needed';
      subtitle =
          '$dropoffWaiting item donation${dropoffWaiting == 1 ? '' : 's'} are waiting for donor proof or confirmation.';
      icon = Icons.photo_camera_outlined;
      color = Colors.orange;
      buttonLabel = 'Review Donations';
      action = onOpenDonations;
    } else if (donationConfirmed > 0) {
      title = 'Donations ready to receive';
      subtitle =
          '$donationConfirmed donation${donationConfirmed == 1 ? '' : 's'} are confirmed and ready for NGO verification.';
      icon = Icons.verified_outlined;
      color = Colors.blue;
      buttonLabel = 'Receive Donations';
      action = onOpenDonations;
    } else if (inTransit > 0) {
      title = 'Deliveries currently moving';
      subtitle =
          '$inTransit delivery route${inTransit == 1 ? '' : 's'} are in transit. Monitor progress and ETA.';
      icon = Icons.local_shipping_outlined;
      color = colorScheme.primary;
      buttonLabel = 'Track Deliveries';
      action = onOpenDeliveries;
    } else if (deliveryActive > 0) {
      title = 'Delivery work scheduled';
      subtitle =
          'You have $deliveryActive active delivery task${deliveryActive == 1 ? '' : 's'} planned or routed.';
      icon = Icons.route_outlined;
      color = Colors.teal;
      buttonLabel = 'Open Deliveries';
      action = onOpenDeliveries;
    } else {
      title = 'Operations are stable';
      subtitle =
          'No urgent donation or delivery action right now. $donationCompleted donation${donationCompleted == 1 ? '' : 's'} completed.';
      icon = Icons.check_circle_outline;
      color = Colors.green;
      buttonLabel = 'View Donations';
      action = onOpenDonations;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha:0.1),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha:0.22)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha:0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha:0.65),
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.tonalIcon(
                      onPressed: action,
                      icon: const Icon(Icons.arrow_forward, size: 16),
                      label: Text(buttonLabel),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardSnapshotStrip extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<_SnapshotItem> items;

  const _DashboardSnapshotStrip({
    required this.title,
    required this.subtitle,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 0, 0),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _SectionTitle(
              title: title,
              subtitle: subtitle,
              colorScheme: colorScheme,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 108,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 16),
              itemBuilder: (context, index) {
                return _SnapshotChip(item: items[index]);
              },
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemCount: items.length,
            ),
          ),
        ],
      ),
    );
  }
}

class _SnapshotItem {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SnapshotItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
}

class _SnapshotChip extends StatelessWidget {
  final _SnapshotItem item;

  const _SnapshotChip({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 128,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: item.color.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: item.color.withValues(alpha:0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(item.icon, color: item.color, size: 24),
          const Spacer(),
          Text(
            item.value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            item.label,
            style: TextStyle(
              color: item.color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _MainActionPanel extends StatelessWidget {
  final String title;
  final String subtitle;

  final String primaryTitle;
  final String primarySubtitle;
  final IconData primaryIcon;
  final Color primaryColor;
  final VoidCallback onPrimaryTap;

  final String secondaryTitle;
  final String secondarySubtitle;
  final IconData secondaryIcon;
  final Color secondaryColor;
  final VoidCallback onSecondaryTap;

  final List<_MiniDashboardAction> footerActions;

  const _MainActionPanel({
    required this.title,
    required this.subtitle,
    required this.primaryTitle,
    required this.primarySubtitle,
    required this.primaryIcon,
    required this.primaryColor,
    required this.onPrimaryTap,
    required this.secondaryTitle,
    required this.secondarySubtitle,
    required this.secondaryIcon,
    required this.secondaryColor,
    required this.onSecondaryTap,
    required this.footerActions,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
      child: Column(
        children: [
          _SectionTitle(
            title: title,
            subtitle: subtitle,
            colorScheme: colorScheme,
          ),
          const SizedBox(height: 12),
          _LargeDashboardAction(
            title: primaryTitle,
            subtitle: primarySubtitle,
            icon: primaryIcon,
            color: primaryColor,
            onTap: onPrimaryTap,
          ),
          const SizedBox(height: 10),
          _LargeDashboardAction(
            title: secondaryTitle,
            subtitle: secondarySubtitle,
            icon: secondaryIcon,
            color: secondaryColor,
            onTap: onSecondaryTap,
          ),
          if (footerActions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  children: footerActions
                      .map(
                        (a) => Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: a.onTap,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Column(
                                children: [
                                  Icon(
                                    a.icon,
                                    color: colorScheme.primary,
                                    size: 22,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    a.label,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LargeDashboardAction extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _LargeDashboardAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha:0.1),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha:0.18)),
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: color.withValues(alpha:0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 29),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha:0.6),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color),
          ],
        ),
      ),
    );
  }
}

class _MiniDashboardAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MiniDashboardAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

/* ───────────────────────── ERROR VIEW ───────────────────────── */

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 58, color: colorScheme.error),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.error),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}