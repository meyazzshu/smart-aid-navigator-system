import 'package:flutter/material.dart';
import 'delivery_group_api.dart';
import 'delivery_group_detail_page.dart';

class DeliveryGroupsPage extends StatefulWidget {
  const DeliveryGroupsPage({super.key});

  @override
  State<DeliveryGroupsPage> createState() => _DeliveryGroupsPageState();
}

class _DeliveryGroupsPageState extends State<DeliveryGroupsPage> {
  final DeliveryGroupApi _api = DeliveryGroupApi();

  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.getGroups();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _api.getGroups();
    });
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Deliveries'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return ListView(
                children: [
                  const SizedBox(height: 80),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        snapshot.error.toString(),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              );
            }

            final groups = snapshot.data ?? [];

            if (groups.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 80),
                  Center(child: Text('No group deliveries yet.')),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: groups.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final group = groups[index];
                final status = group['status']?.toString() ?? 'PLANNED';

                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () async {
                      final groupId = int.parse(group['delivery_group_id'].toString());

                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DeliveryGroupDetailPage(groupId: groupId),
                        ),
                      );

                      _refresh();
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: _statusColor(status).withValues(alpha:0.12),
                                child: Icon(
                                  _statusIcon(status),
                                  color: _statusColor(status),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  group['group_name']?.toString() ?? 'Group Delivery',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              Chip(
                                label: Text(status),
                                labelStyle: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                                backgroundColor: _statusColor(status),
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),

                          Row(
                            children: [
                              Expanded(
                                child: _GroupMiniStat(
                                  icon: Icons.pin_drop_outlined,
                                  label: 'Stops',
                                  value: '${group['stop_count'] ?? 0}',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _GroupMiniStat(
                                  icon: Icons.timer_outlined,
                                  label: 'ETA',
                                  value: group['total_eta_minutes'] == null
                                      ? '-'
                                      : '${group['total_eta_minutes']} min',
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          Row(
                            children: [
                              Expanded(
                                child: _GroupMiniStat(
                                  icon: Icons.social_distance_outlined,
                                  label: 'Distance',
                                  value: group['total_distance_km'] == null
                                      ? '-'
                                      : '${group['total_distance_km']} km',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _GroupMiniStat(
                                  icon: Icons.calendar_today_outlined,
                                  label: 'Scheduled',
                                  value: group['scheduled_date']?.toString() ?? '-',
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final groupId = int.parse(group['delivery_group_id'].toString());

                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => DeliveryGroupDetailPage(groupId: groupId),
                                  ),
                                );

                                _refresh();
                              },
                              icon: const Icon(Icons.route_outlined),
                              label: const Text('View Route'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _GroupMiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _GroupMiniStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha:0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: colorScheme.primary),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}