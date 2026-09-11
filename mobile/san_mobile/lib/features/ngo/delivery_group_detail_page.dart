import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'delivery_group_api.dart';
import 'delivery_detail_page.dart';

class DeliveryGroupDetailPage extends StatefulWidget {
  final int groupId;

  const DeliveryGroupDetailPage({super.key, required this.groupId});

  @override
  State<DeliveryGroupDetailPage> createState() =>
      _DeliveryGroupDetailPageState();
}

class _DeliveryGroupDetailPageState extends State<DeliveryGroupDetailPage> {
  final DeliveryGroupApi _api = DeliveryGroupApi();

  late Future<Map<String, dynamic>> _future;
  bool _optimizing = false;

  Color _statusColor(String status) {
    switch (status) {
      case 'ROUTED':
        return Colors.blue;
      case 'IN_TRANSIT':
        return Colors.orange;
      case 'DELIVERED':
        return Colors.green;
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'ROUTED':
        return Icons.route;
      case 'IN_TRANSIT':
        return Icons.local_shipping;
      case 'DELIVERED':
        return Icons.check_circle;
      case 'CANCELLED':
        return Icons.cancel;
      default:
        return Icons.pending_actions;
    }
  }

  String _statusLabel(String status) {
    return status == 'IN_TRANSIT' ? 'IN TRANSIT' : status;
  }

  @override
  void initState() {
    super.initState();
    _future = _api.getDetail(widget.groupId);
  }

  void _reload() {
    setState(() {
      _future = _api.getDetail(widget.groupId);
    });
  }

  Future<void> _optimizeAndNavigate() async {
    setState(() {
      _optimizing = true;
    });

    try {
      final result = await _api.optimize(
        groupId: widget.groupId,
        currentLat: 0,
        currentLng: 0,
      );
      
      final url = result['google_maps_url']?.toString();

      debugPrint('GROUP OPTIMIZE RESULT = $result');
      debugPrint('GOOGLE MAPS URL = $url');
      debugPrint('ORIGINAL STOP COUNT = ${result['debug_original_stop_count']}');
      debugPrint('OPTIMIZED STOP COUNT = ${result['debug_optimized_stop_count']}');

      if (url == null || url.isEmpty) {
        throw Exception('Google Maps URL was not returned.');
      }

      final uri = Uri.parse(url);

      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

      if (!opened) {
        throw Exception('Could not open Google Maps.');
      }

      _reload();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _optimizing = false;
        });
      }
    }
  }

  Future<void> _openSavedMapsUrl(String url) async {
    final uri = Uri.parse(url);

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Maps.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Group Delivery Details')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  snapshot.error.toString(),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final data = snapshot.data!;
          final group = data['group'] as Map<String, dynamic>;
          final stops = data['stops'] as List<dynamic>;

          final mapsUrl = group['google_maps_url']?.toString();

          final totalStops = stops.length;
          final completedStops = stops.where((raw) {
            final stop = raw as Map<String, dynamic>;
            return stop['status']?.toString() == 'DELIVERED';
          }).length;

          final progress = totalStops == 0 ? 0.0 : completedStops / totalStops;

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: _statusColor(
                                    group['status']?.toString() ?? '',
                                  ).withValues(alpha:0.12),
                                  child: Icon(
                                    _statusIcon(
                                      group['status']?.toString() ?? '',
                                    ),
                                    color: _statusColor(
                                      group['status']?.toString() ?? '',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    group['group_name']?.toString() ??
                                        'Group Delivery',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(fontWeight: FontWeight.w900),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 14),

                            Text(
                              'Route Status',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Chip(
                              avatar: Icon(
                                _statusIcon(group['status']?.toString() ?? ''),
                                size: 16,
                                color: Colors.white,
                              ),
                              label: Text(
                                _statusLabel(
                                  group['status']?.toString() ?? '-',
                                ),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                              backgroundColor: _statusColor(
                                group['status']?.toString() ?? '',
                              ),
                            ),

                            const SizedBox(height: 14),

                            Row(
                              children: [
                                Expanded(
                                  child: _DetailStatCard(
                                    icon: Icons.pin_drop_outlined,
                                    label: 'Stops',
                                    value: '$totalStops',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _DetailStatCard(
                                    icon: Icons.social_distance_outlined,
                                    label: 'Distance',
                                    value: group['total_distance_km'] == null
                                        ? '-'
                                        : '${group['total_distance_km']} km',
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 8),

                            Row(
                              children: [
                                Expanded(
                                  child: _DetailStatCard(
                                    icon: Icons.timer_outlined,
                                    label: 'ETA',
                                    value: group['total_eta_minutes'] == null
                                        ? '-'
                                        : '${group['total_eta_minutes']} min',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _DetailStatCard(
                                    icon: Icons.calendar_today_outlined,
                                    label: 'Scheduled',
                                    value:
                                        group['scheduled_date']?.toString() ??
                                        '-',
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            Text(
                              'Delivery Progress',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 8),

                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 10,
                              ),
                            ),

                            const SizedBox(height: 8),

                            Text(
                              '$completedStops / $totalStops deliveries completed',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(
                          Icons.route_outlined,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Route Timeline',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap any stop card or use Manage Delivery to update its delivery status.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...stops.map((rawStop) {
                      final stop = rawStop as Map<String, dynamic>;
                      final items = (stop['items'] as List<dynamic>? ?? []);

                      final order =
                          stop['optimized_stop_order'] ??
                          stop['requested_stop_order'] ??
                          '-';

                      final deliveryId = int.tryParse(
                        stop['delivery_id']?.toString() ?? '',
                      );

                      return IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Column(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: _statusColor(
                                    stop['status']?.toString() ?? '',
                                  ).withValues(alpha:0.15),
                                  child: Text(
                                    '$order',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: _statusColor(
                                        stop['status']?.toString() ?? '',
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    width: 3,
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade300,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: deliveryId == null
                                      ? null
                                      : () async {
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  DeliveryDetailPage(
                                                    deliveryId: deliveryId,
                                                  ),
                                            ),
                                          );
                                          _reload();
                                        },
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 18,
                                              backgroundColor: Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withValues(alpha:0.12),
                                              child: Icon(
                                                Icons.home_work_outlined,
                                                size: 18,
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.primary,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                stop['shelter_name']
                                                        ?.toString() ??
                                                    'Shelter',
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                            const Icon(Icons.chevron_right),
                                          ],
                                        ),

                                        const SizedBox(height: 8),

                                        Row(
                                          children: [
                                            Icon(
                                              Icons.inventory_2_outlined,
                                              size: 14,
                                              color: Theme.of(context).colorScheme.primary,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${items.length} item types',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Theme.of(context).colorScheme.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),

                                        Text(
                                          stop['address_line']?.toString() ?? '',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.black54,
                                          ),
                                        ),

                                        const SizedBox(height: 10),

                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Delivery Status',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade700,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: [
                                                Chip(
                                                  avatar: Icon(
                                                    _statusIcon(stop['status']?.toString() ?? ''),
                                                    size: 16,
                                                    color: Colors.white,
                                                  ),
                                                  label: Text(
                                                    _statusLabel(stop['status']?.toString() ?? '-'),
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.w700,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                  backgroundColor: _statusColor(
                                                    stop['status']?.toString() ?? '',
                                                  ),
                                                ),
                                                Chip(
                                                  avatar: Icon(
                                                    Icons.inventory_2_outlined,
                                                    size: 16,
                                                    color: Theme.of(context).colorScheme.primary,
                                                  ),
                                                  label: Text(
                                                    '${items.length} item types',
                                                    style: TextStyle(
                                                      color: Theme.of(context).colorScheme.primary,
                                                      fontWeight: FontWeight.w700,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                  backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha:0.10),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),

                                        const SizedBox(height: 10),

                                        if (items.isEmpty)
                                          const Text(
                                            'No items added yet.',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          )
                                        else
                                          ...items.take(3).map((rawItem) {
                                            final item =
                                                rawItem as Map<String, dynamic>;
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 4,
                                              ),
                                              child: Row(
                                                children: [
                                                  const Icon(
                                                    Icons.circle,
                                                    size: 6,
                                                    color: Colors.grey,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      '${item['item_name']}',
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                                  Text(
                                                    '${item['quantity']} ${item['unit']}',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }),

                                        if (items.length > 3)
                                          Text(
                                            '+${items.length - 3} more items',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),

                                        const SizedBox(height: 10),

                                        SizedBox(
                                          width: double.infinity,
                                          child: OutlinedButton.icon(
                                            onPressed: deliveryId == null
                                                ? null
                                                : () async {
                                                    await Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (_) =>
                                                            DeliveryDetailPage(
                                                              deliveryId:
                                                                  deliveryId,
                                                            ),
                                                      ),
                                                    );
                                                    _reload();
                                                  },
                                            icon: const Icon(
                                              Icons.manage_search,
                                            ),
                                            label: const Text(
                                              'Open Delivery Details',
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _optimizing ? null : _optimizeAndNavigate,
                      icon: _optimizing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.navigation),
                      label: Text(
                        _optimizing ? 'Optimizing...' : 'Optimize & Navigate',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DetailStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailStatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha:0.6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
