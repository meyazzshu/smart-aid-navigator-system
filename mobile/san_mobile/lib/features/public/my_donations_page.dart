import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../../core/app_theme.dart';
import '../../core/dio_client.dart';
import 'create_donation_page.dart';
import 'donation_detail_page.dart';

class MyDonationsPage extends StatefulWidget {
  const MyDonationsPage({super.key});

  @override
  State<MyDonationsPage> createState() => _MyDonationsPageState();
}

class _MyDonationsPageState extends State<MyDonationsPage> {
  final Dio _dio = DioClient.create();
  late Future<List<Map<String, dynamic>>> _future;

  String _filter = '';

  static const List<String> _statusOrder = [
    'PENDING',
    'CONFIRMED',
    'COMPLETED',
    'CANCELLED',
  ];

  final Map<String, int> _counts = {
    '': 0,
    'PENDING': 0,
    'CONFIRMED': 0,
    'COMPLETED': 0,
    'CANCELLED': 0,
  };

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final res = await _dio.get('/donations/my');
    final data = (res.data as Map).cast<String, dynamic>();
    if (data['ok'] != true) throw Exception(data['error'] ?? 'Failed to load donations');

    final list = (data['donations'] as List).cast<dynamic>();
    final donations = list.map((e) => (e as Map).cast<String, dynamic>()).toList();

    _recomputeCounts(donations);

    return donations;
  }

  void _recomputeCounts(List<Map<String, dynamic>> donations) {
    for (final k in _counts.keys) {
      _counts[k] = 0;
    }
    for (final d in donations) {
      final st = _statusOf(d);
      if (_counts.containsKey(st)) {
        _counts[st] = (_counts[st] ?? 0) + 1;
      } else {
        _counts['PENDING'] = (_counts['PENDING'] ?? 0) + 1;
      }
    }
    _counts[''] = donations.length;
    if (mounted) setState(() {});
  }

  String _statusOf(Map<String, dynamic> d) {
    final s = (d['status'] ?? '').toString().toUpperCase().trim();
    if (_statusOrder.contains(s)) return s;
    return s.isEmpty ? 'PENDING' : s;
  }

  List<Map<String, dynamic>> _applyFilter(List<Map<String, dynamic>> donations) {
    if (_filter.isEmpty) return donations;
    return donations.where((d) => _statusOf(d) == _filter).toList();
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  void _setFilter(String status) => setState(() => _filter = status);

  String _labelForStatus(String s) => s.isEmpty ? 'ALL' : s;

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

  IconData _statusIcon(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
        return Icons.check_circle_outline;
      case 'CONFIRMED':
        return Icons.thumb_up_outlined;
      case 'PENDING':
        return Icons.hourglass_empty;
      case 'CANCELLED':
        return Icons.cancel_outlined;
      default:
        return Icons.help_outline;
    }
  }

  IconData _typeIcon(String type) {
    return type == 'MONEY' ? Icons.account_balance_wallet : Icons.inventory_2;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('My Donations')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const CreateDonationPage()));
          await _refresh();
        },
        icon: const Icon(Icons.add),
        label: const Text('New Donation'),
      ),
      body: Column(
        children: [
          // Summary banner
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const SizedBox.shrink();
              }
              final total = _counts[''] ?? 0;
              final pending = _counts['PENDING'] ?? 0;
              final completed = _counts['COMPLETED'] ?? 0;
              return Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.darkAzure, AppColors.azure],
                  ),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                child: Row(
                  children: [
                    _BannerStat(label: 'Total', value: total.toString()),
                    _BannerDivider(),
                    _BannerStat(label: 'Pending', value: pending.toString()),
                    _BannerDivider(),
                    _BannerStat(label: 'Completed', value: completed.toString()),
                  ],
                ),
              );
            },
          ),
          // Filter bar
          _DonationStatusFilterBar(
            selected: _filter,
            counts: _counts,
            labelFor: _labelForStatus,
            onSelected: _setFilter,
            statusColor: _statusColor,
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: colorScheme.error),
                          const SizedBox(height: 12),
                          Text(snapshot.error.toString(),
                              style: TextStyle(color: colorScheme.error)),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _refresh,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final all = snapshot.data ?? [];
                final list = _applyFilter(all);

                if (list.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      children: [
                        const SizedBox(height: 80),
                        Center(
                          child: Column(
                            children: [
                              Icon(Icons.volunteer_activism,
                                  size: 72,
                                  color: colorScheme.secondary.withOpacity(0.4)),
                              const SizedBox(height: 16),
                              Text(
                                _filter.isEmpty
                                    ? 'No donations yet'
                                    : 'No ${_labelForStatus(_filter)} donations',
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _filter.isEmpty
                                    ? 'Tap the button below to make your first donation.'
                                    : 'Try a different filter.',
                                style: TextStyle(
                                    color: colorScheme.onSurface.withOpacity(0.5)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final d = list[i];
                      final id = (d['donation_id'] as num).toInt();
                      final type = d['donation_type']?.toString() ?? '';
                      final status = d['status']?.toString() ?? '';
                      final ngo = d['ngo_name']?.toString() ?? '';
                      final when = d['created_at']?.toString() ?? '';
                      final remarks = d['remarks']?.toString() ?? '';
                      final statusColor = _statusColor(status);
                      final statusIcon = _statusIcon(status);
                      final typeIcon = _typeIcon(type);

                      return Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () async {
                            await Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => DonationDetailPage(donationId: id),
                            ));
                            await _refresh();
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Type label + icon
                                Container(
                                  width: 54,
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        type == 'MONEY' ? 'MONEY' : 'ITEM',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: colorScheme.primary,
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Icon(
                                        typeIcon,
                                        color: colorScheme.primary,
                                        size: 22,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Donation #$id',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      if (ngo.isNotEmpty)
                                        Row(
                                          children: [
                                            Icon(Icons.storefront_outlined,
                                                size: 13,
                                                color: colorScheme.onSurface
                                                    .withOpacity(0.5)),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                ngo,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: colorScheme.onSurface
                                                      .withOpacity(0.65),
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      if (when.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Icon(Icons.access_time,
                                                size: 12,
                                                color: colorScheme.onSurface
                                                    .withOpacity(0.4)),
                                            const SizedBox(width: 4),
                                            Text(
                                              when.length > 10
                                                  ? when.substring(0, 10)
                                                  : when,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: colorScheme.onSurface
                                                    .withOpacity(0.45),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                      if (remarks.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          remarks,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: colorScheme.onSurface
                                                .withOpacity(0.55),
                                            fontStyle: FontStyle.italic,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Status badge
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      constraints: const BoxConstraints(maxWidth: 82),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: statusColor.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            statusIcon,
                                            size: 11,
                                            color: statusColor,
                                          ),
                                          const SizedBox(width: 3),
                                          Flexible(
                                            child: Text(
                                              status,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: statusColor,
                                                fontSize: 9,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Icon(Icons.chevron_right,
                                        color: colorScheme.primary, size: 18),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerStat extends StatelessWidget {
  final String label;
  final String value;
  const _BannerStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 20)),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.8), fontSize: 11)),
        ],
      ),
    );
  }
}

class _BannerDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 28, color: Colors.white24);
  }
}

class _DonationStatusFilterBar extends StatelessWidget {
  final String selected;
  final Map<String, int> counts;
  final String Function(String status) labelFor;
  final void Function(String status) onSelected;
  final Color Function(String status) statusColor;

  const _DonationStatusFilterBar({
    required this.selected,
    required this.counts,
    required this.labelFor,
    required this.onSelected,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    const order = <String>[
      '',
      'PENDING',
      'CONFIRMED',
      'COMPLETED',
      'CANCELLED',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: order.map((status) {
            final isSelected = selected == status;
            final label = labelFor(status);
            final count = counts[status] ?? 0;
            final color = status.isEmpty
                ? Theme.of(context).colorScheme.primary
                : statusColor(status);

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                selected: isSelected,
                avatar: isSelected
                    ? Icon(Icons.check, size: 14,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : color)
                    : null,
                label: Text(
                  '$label ($count)',
                  style: TextStyle(
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                onSelected: (_) => onSelected(status),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
