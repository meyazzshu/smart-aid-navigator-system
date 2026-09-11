import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import '../../core/dio_client.dart';
import '../../core/navigation.dart';
import 'delivery_detail_page.dart';
import 'delivery_groups_page.dart';

class DeliveriesPage extends StatefulWidget {
  final String initialFilter; // '', ROUTED, PLANNED, IN_TRANSIT, DELIVERED, CANCELLED

  const DeliveriesPage({
    super.key,
    this.initialFilter = '',
  });


  @override
  State<DeliveriesPage> createState() => _DeliveriesPageState();
}

class _DeliveriesPageState extends State<DeliveriesPage> {
  final Dio _dio = DioClient.create();

  late Future<List<Map<String, dynamic>>> _future;

  String _sortBy = 'operational'; // operational, newest, oldest, scheduled, shelter
  final TextEditingController _searchController = TextEditingController();


  // Counts for chips
  final Map<String, int> _counts = {
    '': 0, // ALL
    'ROUTED': 0,
    'PLANNED': 0,
    'IN_TRANSIT': 0,
    'DELIVERED': 0,
    'CANCELLED': 0,
  };

  // Group order requested
  static const List<String> _statusOrder = [
    'PLANNED',
    'IN_TRANSIT',
    'ROUTED',
    'DELIVERED',
    'CANCELLED',
  ];

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }


  Future<List<Map<String, dynamic>>> _load() async {
    final res = await _dio.get(
      '/deliveries',
      queryParameters: {
        'group_scope': 'SINGLE',
      },
    );

    final data = (res.data as Map).cast<String, dynamic>();

    if (data['ok'] != true) {
      throw Exception(data['error'] ?? 'Failed to load deliveries');
    }

    final list = (data['deliveries'] as List? ?? []).cast<dynamic>();

    final deliveries = list
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();

    _recomputeCounts(deliveries);

    return deliveries;
  }

  void _recomputeCounts(List<Map<String, dynamic>> deliveries) {
    // Reset
    for (final k in _counts.keys) {
      _counts[k] = 0;
    }

    for (final d in deliveries) {
      final st = _statusOf(d);
      if (_counts.containsKey(st)) {
        _counts[st] = (_counts[st] ?? 0) + 1;
      } else {
        // Unknown statuses: put them into PLANNED (or ignore)
        _counts['PLANNED'] = (_counts['PLANNED'] ?? 0) + 1;
      }
    }

    // ALL = total
    _counts[''] = deliveries.length;

    // Force rebuild for chip labels
    if (mounted) setState(() {});
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  void _setSortBy(String value) {
    setState(() {
      _sortBy = value;
    });
  }

  void _applySearch() {
    setState(() {});
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {});
  }

  // Normalize server status to your expected names
  String _statusOf(Map<String, dynamic> d) {
    final s = (d['status'] ?? '').toString().toUpperCase().trim();
    if (_statusOrder.contains(s)) return s;
    return s.isEmpty ? 'PLANNED' : s;
  }

  List<Map<String, dynamic>> _applySearchFilterAndSort(
  List<Map<String, dynamic>> deliveries,
  ) {
    final keyword = _searchController.text.trim().toLowerCase();

    var rows = deliveries.where((d) {
      if (keyword.isEmpty) return true;

      final deliveryId = d['delivery_id']?.toString().toLowerCase() ?? '';
      final shelterName = d['shelter_name']?.toString().toLowerCase() ?? '';
      final city = d['city']?.toString().toLowerCase() ?? '';
      final state = d['state']?.toString().toLowerCase() ?? '';
      final notes = d['notes']?.toString().toLowerCase() ?? '';

      return deliveryId.contains(keyword) ||
          shelterName.contains(keyword) ||
          city.contains(keyword) ||
          state.contains(keyword) ||
          notes.contains(keyword);
    }).toList();

    rows.sort((a, b) {
      final aId = _deliveryIdOf(a);
      final bId = _deliveryIdOf(b);

      if (_sortBy == 'newest') {
        return bId.compareTo(aId);
      }

      if (_sortBy == 'oldest') {
        return aId.compareTo(bId);
      }

      if (_sortBy == 'scheduled') {
        final aDate = _dateValue(a['scheduled_date']);
        final bDate = _dateValue(b['scheduled_date']);

        final dateCompare = aDate.compareTo(bDate);

        if (dateCompare != 0) {
          return dateCompare;
        }

        return bId.compareTo(aId);
      }

      if (_sortBy == 'shelter') {
        final aShelter = a['shelter_name']?.toString().toLowerCase() ?? '';
        final bShelter = b['shelter_name']?.toString().toLowerCase() ?? '';

        final shelterCompare = aShelter.compareTo(bShelter);

        if (shelterCompare != 0) {
          return shelterCompare;
        }

        return bId.compareTo(aId);
      }

      // Default: operational sorting
      // PLANNED, IN_TRANSIT, ROUTED, DELIVERED, CANCELLED
      // Then bigger delivery_id first.
      final aStatusRank = _statusRank(_statusOf(a));
      final bStatusRank = _statusRank(_statusOf(b));

      final statusCompare = aStatusRank.compareTo(bStatusRank);

      if (statusCompare != 0) {
        return statusCompare;
      }

      return bId.compareTo(aId);
    });

    return rows;
  }

  int _deliveryIdOf(Map<String, dynamic> d) {
    return int.tryParse(d['delivery_id']?.toString() ?? '') ?? 0;
  }

  int _dateValue(dynamic raw) {
    final text = raw?.toString() ?? '';

    if (text.trim().isEmpty || text == 'null') {
      return 99999999;
    }

    final cleaned = text.length >= 10 ? text.substring(0, 10) : text;
    final parsed = DateTime.tryParse(cleaned);

    if (parsed == null) {
      return 99999999;
    }

    return int.tryParse(DateFormat('yyyyMMdd').format(parsed)) ?? 99999999;
  }

  int _statusRank(String status) {
    switch (status) {
      case 'PLANNED':
        return 1;
      case 'IN_TRANSIT':
        return 2;
      case 'ROUTED':
        return 3;
      case 'DELIVERED':
        return 4;
      case 'CANCELLED':
        return 5;
      default:
        return 6;
    }
  }

  String _labelForStatus(String s) {
    switch (s) {
      case '':
        return 'ALL';
      case 'IN_TRANSIT':
        return 'IN TRANSIT';
      default:
        return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _ErrorView(
              message: snapshot.error.toString(),
              onRetry: _refresh,
            );
          }

          final rawDeliveries = snapshot.data ?? [];

          final activeCount = rawDeliveries.where((d) {
            final status = _statusOf(d);
            return status == 'PLANNED' ||
                status == 'IN_TRANSIT' ||
                status == 'ROUTED';
          }).length;

          final filteredDeliveries = _applySearchFilterAndSort(rawDeliveries);

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primaryContainer,
                        colorScheme.secondaryContainer,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor:
                            colorScheme.primary.withValues(alpha: 0.14),
                        child: Icon(
                          Icons.local_shipping_rounded,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Delivery Operations',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: colorScheme.onSecondaryContainer,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$activeCount active • ${rawDeliveries.length} single deliveries',
                              style: TextStyle(
                                color: colorScheme.onSecondaryContainer
                                    .withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.route_rounded),
                      label: const Text('Group Deliveries'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const DeliveryGroupsPage(),
                          ),
                        );

                        await _refresh();
                      },
                    ),
                  ),
                ),

                _DeliveryFilterPanel(
                  sortBy: _sortBy,
                  searchController: _searchController,
                  onSortChanged: _setSortBy,
                  onSearchChanged: _applySearch,
                  onClearSearch: _clearSearch,
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.filter_alt_outlined,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${filteredDeliveries.length} result(s) shown',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface.withValues(alpha: 0.65),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (rawDeliveries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 120),
                    child: Center(
                      child: Text(
                        'No single deliveries found.',
                        style: TextStyle(
                          color: colorScheme.onSurface.withValues(alpha: 0.65),
                        ),
                      ),
                    ),
                  )
                else if (filteredDeliveries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 120),
                    child: Center(
                      child: Text(
                        'No deliveries match your search or sort filter.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colorScheme.onSurface.withValues(alpha: 0.65),
                        ),
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                    child: Column(
                      children: filteredDeliveries.map((d) {
                        return _DeliveryCard(
                          delivery: d,
                          onOpen: () async {
                            final deliveryId = d['delivery_id'];

                            if (deliveryId == null) return;

                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => DeliveryDetailPage(
                                  deliveryId: (deliveryId as num).toInt(),
                                ),
                              ),
                            );

                            await _refresh();
                          },
                          status: _statusOf(d),
                          accentColor: colorScheme.primary,
                          secondaryColor: colorScheme.secondary,
                          successColor: Colors.green,
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DeliveryFilterPanel extends StatelessWidget {
  final String sortBy;
  final TextEditingController searchController;
  final void Function(String value) onSortChanged;
  final VoidCallback onSearchChanged;
  final VoidCallback onClearSearch;

  const _DeliveryFilterPanel({
    required this.sortBy,
    required this.searchController,
    required this.onSortChanged,
    required this.onSearchChanged,
    required this.onClearSearch,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.tune_rounded, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Filter & Sort Single Deliveries',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              TextField(
                controller: searchController,
                onChanged: (_) => onSearchChanged(),
                decoration: InputDecoration(
                  labelText: 'Search delivery',
                  hintText: 'Delivery ID, shelter, city, notes...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: searchController.text.trim().isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: onClearSearch,
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  isDense: true,
                ),
              ),

              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                value: sortBy,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Sort By',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'operational',
                    child: Text(
                      'Operational priority',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'newest',
                    child: Text(
                      'Newest delivery ID first',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'oldest',
                    child: Text(
                      'Oldest delivery ID first',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'scheduled',
                    child: Text(
                      'Scheduled date',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'shelter',
                    child: Text(
                      'Shelter A-Z',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    onSortChanged(value);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatEta(dynamic raw, [dynamic etaMinutes]) {
  final s = raw?.toString().trim() ?? '';
  if (s.isEmpty || s == 'null') {
    // Fall back to eta_minutes if available
    if (etaMinutes != null) {
      final mins = int.tryParse(etaMinutes.toString());
      if (mins != null && mins > 0) {
        if (mins < 60) return '$mins min';
        final h = mins ~/ 60;
        final m = mins % 60;
        return m > 0 ? '${h}h ${m}min' : '${h}h';
      }
    }
    return '--';
  }
  final dt = DateTime.tryParse(s);
  if (dt != null) {
    return DateFormat('EEE, MMM d • h:mm a').format(dt.toLocal());
  }
  return s;
}

Color _statusColor(String status, ColorScheme scheme) {
  switch (status) {
    case 'ROUTED':
      return Colors.indigo;
    case 'PLANNED':
      return Colors.blueGrey;
    case 'IN_TRANSIT':
      return Colors.orange;
    case 'DELIVERED':
      return Colors.green;
    case 'CANCELLED':
      return Colors.red;
    default:
      return scheme.primary;
  }
}

IconData _statusIcon(String status) {
  switch (status) {
    case 'ROUTED':
      return Icons.route_rounded;
    case 'PLANNED':
      return Icons.assignment_rounded;
    case 'IN_TRANSIT':
      return Icons.local_shipping_rounded;
    case 'DELIVERED':
      return Icons.check_circle_rounded;
    case 'CANCELLED':
      return Icons.cancel_rounded;
    default:
      return Icons.list_alt_rounded;
  }
}

class _DeliveryCard extends StatelessWidget {
  final Map<String, dynamic> delivery;
  final String status;
  final VoidCallback onOpen;
  final Color accentColor;
  final Color secondaryColor;
  final Color successColor;

  const _DeliveryCard({
    required this.delivery,
    required this.status,
    required this.onOpen,
    required this.accentColor,
    required this.secondaryColor,
    required this.successColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final deliveryId = delivery['delivery_id']?.toString() ?? '';
    final aidCategories = delivery['aid_categories'] as List? ?? [];
    final categoryNames = aidCategories.map((c) => c['category_name']?.toString() ?? '').where((n) => n.isNotEmpty).join(', ');
    final shelterName = (delivery['shelter_name'] ?? '').toString();
    final city = (delivery['city'] ?? '').toString();
    final state = (delivery['state'] ?? '').toString();
    final location = [city, state].where((x) => x.trim().isNotEmpty).join(', ');
    final eta = _formatEta(delivery['eta'], delivery['eta_minutes']);
    final lat = delivery['latitude'] is num ? delivery['latitude'] as num : double.tryParse(delivery['latitude']?.toString() ?? '');
    final lng = delivery['longitude'] is num ? delivery['longitude'] as num : double.tryParse(delivery['longitude']?.toString() ?? '');
    final statusColor = _statusColor(status, colorScheme);

    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 7),
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Delivery #$deliveryId',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha:0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_statusIcon(status), size: 14, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          status == 'IN_TRANSIT' ? 'IN TRANSIT' : status,
                          style: TextStyle(color: statusColor, fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (categoryNames.isNotEmpty)
                Row(
                  children: [
                    Icon(Icons.inventory_2_rounded, size: 16, color: secondaryColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        categoryNames,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 10),
              if (lat != null && lng != null)
                SizedBox(
                  height: 170,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(target: LatLng(lat.toDouble(), lng.toDouble()), zoom: 13),
                      markers: {
                        Marker(
                          markerId: MarkerId('dest'),
                          position: LatLng(lat.toDouble(), lng.toDouble()),
                          infoWindow: InfoWindow(title: shelterName),
                        ),
                      },
                      myLocationEnabled: true,
                      zoomControlsEnabled: false,
                      liteModeEnabled: false,
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.location_on, color: secondaryColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      shelterName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.access_time, color: accentColor.withValues(alpha:0.8)),
                  const SizedBox(width: 6),
                  Text('ETA • $eta', style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 4),
              if (location.isNotEmpty)
                Row(
                  children: [
                    Icon(Icons.map, color: successColor),
                    const SizedBox(width: 6),
                    Expanded(child: Text(location)),
                  ],
                ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 44),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.navigation),
                      label: const Text('Navigate (Google Maps)'),
                      onPressed: () async {
                        if (lat != null && lng != null) {
                          final ok = await NavigationHelper.navigateTo(
                            destLat: lat.toDouble(),
                            destLng: lng.toDouble(),
                          );
                          if (!ok && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Unable to open Google Maps')),
                            );
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('No destination coordinates available')),
                          );
                        }
                      },
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

class _ErrorView extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: colorScheme.error)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => onRetry(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
