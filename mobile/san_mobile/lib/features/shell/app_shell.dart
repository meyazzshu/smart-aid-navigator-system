import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:san_mobile/auth/auth_state.dart';

import '../../auth/auth_controller.dart';

import '../dashboard/dashboard_page.dart';
import '../map/aid_map_page.dart';
import '../map/guest_request_storage.dart';
import '../map/guest_shelter_request_api.dart';

import '../ngo/deliveries_page.dart';
import '../ngo/ngo_donations_page.dart';

import '../pps/pps_my_bookings_page.dart';
import '../public/donation_hub_page.dart';
import '../public/public_home_page.dart';
import '../settings/settings_page.dart';

class AppTabController {
  static final GlobalKey<_AppShellState> shellKey =
      GlobalKey<_AppShellState>();

  static void openMapTab() {
    shellKey.currentState?.openMapTab();
  }

  static void openMyTab() {
    shellKey.currentState?.openMyTab();
  }

  static void openDashboardTab() {
    shellKey.currentState?.openDashboardTab();
  }

  static void openDonationTab() {
    shellKey.currentState?.openDonationTab();
  }

  static void openSettingsTab() {
    shellKey.currentState?.openSettingsTab();
  }

  static void openPpsBookingTab() {
    shellKey.currentState?.openPpsBookingTab();
  }
}

class AppShell extends ConsumerStatefulWidget {
  final int? initialIndex;

  AppShell({
    Key? key,
    this.initialIndex,
  }) : super(key: key ?? AppTabController.shellKey);

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  String? _lastRole;
  bool _guestCheckInProgress = false;
  late final ProviderSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();

    if (widget.initialIndex != null) {
      _index = widget.initialIndex!;
    }

    _authSubscription = ref.listenManual(
      authControllerProvider,
      (previous, next) {
        final email = next.user?.email;

        if (email == null || email.isEmpty) {
          _guestCheckInProgress = false;
          return;
        }

        if (_guestCheckInProgress) return;

        _guestCheckInProgress = true;
        _checkGuestRequest(email);
      },
    );
  }

  @override
  void dispose() {
    _authSubscription.close();
    super.dispose();
  }

  void openMapTab() {
    if (!mounted) return;

    final auth = ref.read(authControllerProvider);
    final role = auth.user?.role ?? '';
    final isNgo = role == 'NGO_STAFF' || role == 'ADMIN';

    setState(() {
      _index = isNgo ? 1 : 0;
    });
  }

  void openDashboardTab() {
    if (!mounted) return;

    final auth = ref.read(authControllerProvider);
    final role = auth.user?.role ?? '';
    final isNgo = role == 'NGO_STAFF' || role == 'ADMIN';

    setState(() {
      _index = isNgo ? 0 : 1;
    });
  }

  void openDonationTab() {
    if (!mounted) return;

    final auth = ref.read(authControllerProvider);
    final role = auth.user?.role ?? '';
    final isNgo = role == 'NGO_STAFF' || role == 'ADMIN';

    setState(() {
      _index = isNgo ? 3 : 2;
    });
  }

  void openMyTab() {
    if (!mounted) return;

    setState(() {
      _index = 4;
    });
  }

  void openSettingsTab() {
    if (!mounted) return;

    setState(() {
      _index = 4;
    });
  }

  void openPpsBookingTab() {
    if (!mounted) return;

    final auth = ref.read(authControllerProvider);
    final role = auth.user?.role ?? '';
    final isNgo = role == 'NGO_STAFF' || role == 'ADMIN';

    // PUBLIC menu:
    // 0 Map, 1 Dashboard, 2 Donation, 3 PPS Booking, 4 My
    if (!isNgo) {
      setState(() {
        _index = 3;
      });
    }
  }

  int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();

    final parsed = int.tryParse(v.toString());
    return parsed;
  }

  Future<void> _checkGuestRequest(String email) async {
    try {
      final data = await GuestRequestStorage.load();
      if (data == null) return;

      final storedEmail =
          (data['email'] ?? '').toString().trim().toLowerCase();

      if (storedEmail.isEmpty || storedEmail != email.toLowerCase()) return;

      if (!mounted) return;

      final shelterName = (data['shelter_name'] ?? 'Shelter').toString();
      final totalPeople = (data['total_people'] ?? '').toString();

      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) {
          return AlertDialog(
            title: const Text('Confirm Guest Request'),
            content: Text(
              'We found a guest PPS request for $shelterName'
              '${totalPeople.isNotEmpty ? ' (Total: $totalPeople)' : ''}.\n'
              'Is this your request?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Not mine'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Confirm'),
              ),
            ],
          );
        },
      );

      if (confirmed != true) {
        await GuestRequestStorage.clear();
        return;
      }

      final requestId = _toInt(data['request_id']);

      final res = await GuestShelterRequestApi().claimGuestRequest(
        requestId: requestId,
        email: email,
      );

      if (res['ok'] == true) {
        await GuestRequestStorage.clear();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Guest request confirmed and linked to your account.'),
          ),
        );
      } else {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              res['error']?.toString() ?? 'Failed to confirm request',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Guest request check failed: $e')),
      );
    } finally {
      _guestCheckInProgress = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final role = auth.user?.role ?? '';
    final isNgo = role == 'NGO_STAFF' || role == 'ADMIN';

    if (_lastRole != role) {
      _lastRole = role;

      if (widget.initialIndex == null) {
        if (isNgo) {
          _index = 2; // NGO default: Delivery
        } else {
          _index = 0; // Public / guest default: Map
        }
      }
    }

    final ngoPages = <Widget>[
      const DashboardPage(),
      const AidMapPage(),
      const DeliveriesPage(),
      const NgoDonationsPage(),
      const SettingsPage(),
    ];

    final ngoItems = const <BottomNavigationBarItem>[
      BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
      BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
      BottomNavigationBarItem(
        icon: Icon(Icons.local_shipping),
        label: 'Delivery',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.volunteer_activism),
        label: 'Donations',
      ),
      BottomNavigationBarItem(icon: Icon(Icons.person), label: 'My'),
    ];

    final ngoTitles = <String>[
      'Dashboard',
      'Map',
      'Deliveries',
      'Donations',
      'My',
    ];

    final publicPages = <Widget>[
      const AidMapPage(),
      const DashboardPage(),
      const DonationHubPage(),
      const PpsMyBookingsPage(),
      const PublicHomePage(),
    ];

    final publicItems = const <BottomNavigationBarItem>[
      BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
      BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
      BottomNavigationBarItem(
        icon: Icon(Icons.volunteer_activism),
        label: 'Donation',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.meeting_room_outlined),
        label: 'PPS Booking',
      ),
      BottomNavigationBarItem(icon: Icon(Icons.person), label: 'My'),
    ];

    final publicTitles = <String>[
      'Map',
      'Dashboard',
      'Donation',
      'PPS Booking',
      'My',
    ];

    final pages = isNgo ? ngoPages : publicPages;
    final items = isNgo ? ngoItems : publicItems;
    final titles = isNgo ? ngoTitles : publicTitles;

    if (_index < 0 || _index >= pages.length) {
      _index = 0;
    }

    final title = titles[_index];

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFC),
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(authControllerProvider.notifier).logout();
            },
          ),
        ],
      ),
      body: pages[_index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) {
          setState(() {
            _index = i;
          });
        },
        items: items,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
