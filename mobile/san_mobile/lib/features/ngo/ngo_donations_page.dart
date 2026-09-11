import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/dio_client.dart';
import 'ngo_donation_detail_page.dart';

class NgoDonationsPage extends StatefulWidget {
  const NgoDonationsPage({super.key});

  @override
  State<NgoDonationsPage> createState() => _NgoDonationsPageState();
}

class _NgoDonationsPageState extends State<NgoDonationsPage> {
  final Dio _dio = DioClient.create();

  String _filter = '';

  final Map<String, int> _counts = {
    '': 0,
    'PENDING': 0,
    'CONFIRMED': 0,
    'COMPLETED': 0,
    'CANCELLED': 0,
  };

  static const List<String> _statusOrder = [
    'PENDING',
    'CONFIRMED',
    'COMPLETED',
    'CANCELLED',
  ];

  late Future<List<Map<String, dynamic>>> _futureAll;

  @override
  void initState() {
    super.initState();
    _futureAll = _loadAll();
  }

  Future<List<Map<String, dynamic>>> _loadAll() async {
    final res = await _dio.get('/ngo/donations');
    final data = (res.data as Map).cast<String, dynamic>();

    if (data['ok'] != true) {
      throw Exception(data['error'] ?? 'Failed to load NGO donations');
    }

    final list = (data['donations'] as List).cast<dynamic>();
    final donations =
        list.map((e) => (e as Map).cast<String, dynamic>()).toList();

    _recomputeCounts(donations);
    return donations;
  }

  Future<void> _refresh() async {
    setState(() => _futureAll = _loadAll());
    await _futureAll;
  }

  void _setFilter(String status) {
    setState(() => _filter = status);
  }

  String _statusOf(Map<String, dynamic> d) {
    final s = (d['status'] ?? '').toString().toUpperCase().trim();
    if (_statusOrder.contains(s)) return s;
    return s.isEmpty ? 'PENDING' : s;
  }

  String _typeOf(Map<String, dynamic> d) {
    return (d['donation_type'] ?? '').toString().toUpperCase().trim();
  }

  bool _hasProof(Map<String, dynamic> d) {
    final url = d['proof_photo_url']?.toString().trim() ?? '';
    return url.isNotEmpty;
  }

  bool _dropoffPending(Map<String, dynamic> d) {
    final type = _typeOf(d);
    final dropReq = (d['dropoff_required'] as num?)?.toInt() == 1;
    final dropConf = (d['dropoff_confirmed'] as num?)?.toInt() == 1;
    return type == 'ITEM' && dropReq && !dropConf;
  }

  void _recomputeCounts(List<Map<String, dynamic>> all) {
    for (final k in _counts.keys) {
      _counts[k] = 0;
    }

    for (final d in all) {
      final st = _statusOf(d);
      if (_counts.containsKey(st)) {
        _counts[st] = (_counts[st] ?? 0) + 1;
      } else {
        _counts['PENDING'] = (_counts['PENDING'] ?? 0) + 1;
      }
    }

    _counts[''] = all.length;

    if (mounted) setState(() {});
  }

  List<Map<String, dynamic>> _applyFilter(List<Map<String, dynamic>> all) {
    if (_filter.isEmpty) return all;
    return all.where((d) => _statusOf(d) == _filter).toList();
  }

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

  Map<String, int> _summary(List<Map<String, dynamic>> all) {
    final total = all.length;
    final money = all.where((d) => _typeOf(d) == 'MONEY').length;
    final items = all.where((d) => _typeOf(d) == 'ITEM').length;
    final proof = all.where(_hasProof).length;
    final dropPending = all.where(_dropoffPending).length;
    final pending = all.where((d) => _statusOf(d) == 'PENDING').length;
    final completed = all.where((d) => _statusOf(d) == 'COMPLETED').length;

    return {
      'total': total,
      'money': money,
      'items': items,
      'proof': proof,
      'dropPending': dropPending,
      'pending': pending,
      'completed': completed,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _futureAll,
        builder: (context, snapshot) {
          final loading = snapshot.connectionState != ConnectionState.done;
          final all = snapshot.data ?? [];
          final filtered = _applyFilter(all);
          final summary = _summary(all);

          if (snapshot.hasError) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                children: [
                  _buildHeroHeader(colorScheme, summary, loading: false),
                  const SizedBox(height: 80),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 56,
                            color: colorScheme.error,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            snapshot.error.toString(),
                            style: TextStyle(color: colorScheme.error),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _refresh,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _buildHeroHeader(colorScheme, summary,
                      loading: loading),
                ),
                SliverToBoxAdapter(
                  child: _NgoDonationFilterBar(
                    selected: _filter,
                    counts: _counts,
                    labelFor: _labelForStatus,
                    onSelected: _setFilter,
                    statusColor: _statusColor,
                  ),
                ),
                if (loading)
                  const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (filtered.isEmpty)
                  SliverFillRemaining(
                    child: _EmptyNgoDonations(
                      filter: _filter,
                      labelFor: _labelForStatus,
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index == 0) {
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                            child: _SectionTitle(
                              title: _filter.isEmpty
                                  ? 'Incoming Donations'
                                  : '${_labelForStatus(_filter)} Donations',
                              subtitle:
                                  '${filtered.length} donation${filtered.length == 1 ? '' : 's'} shown',
                              colorScheme: colorScheme,
                            ),
                          );
                        }

                        final donation = filtered[index - 1];

                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                          child: _DonationCard(
                            donation: donation,
                            statusColor: _statusColor,
                            statusIcon: _statusIcon,
                            onOpen: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => NgoDonationDetailPage(
                                    donation: donation,
                                  ),
                                ),
                              );
                              await _refresh();
                            },
                          ),
                        );
                      },
                      childCount: filtered.length + 1,
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeroHeader(
    ColorScheme colorScheme,
    Map<String, int> summary, {
    required bool loading,
  }) {
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
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.inbox_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Donation Control Center',
            style: TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            loading
                ? 'Loading incoming donation records...'
                : 'Monitor donor contributions, verify drop-offs, and complete received donations.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _HeroStat(
                icon: Icons.volunteer_activism,
                label: 'Total',
                value: loading ? '-' : '${summary['total']}',
              ),
              const SizedBox(width: 10),
              _HeroStat(
                icon: Icons.hourglass_empty,
                label: 'Pending',
                value: loading ? '-' : '${summary['pending']}',
              ),
              const SizedBox(width: 10),
              _HeroStat(
                icon: Icons.check_circle_outline,
                label: 'Completed',
                value: loading ? '-' : '${summary['completed']}',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _MiniHeroPill(
                icon: Icons.inventory_2_outlined,
                label: '${summary['items'] ?? 0} Item',
              ),
              const SizedBox(width: 8),
              _MiniHeroPill(
                icon: Icons.account_balance_wallet_outlined,
                label: '${summary['money'] ?? 0} Money',
              ),
              const SizedBox(width: 8),
              _MiniHeroPill(
                icon: Icons.photo_camera_outlined,
                label: '${summary['proof'] ?? 0} Proof',
              ),
            ],
          ),
          if ((summary['dropPending'] ?? 0) > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${summary['dropPending']} item donation${summary['dropPending'] == 1 ? '' : 's'} still waiting for donor drop-off confirmation.',
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

class _HeroStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _HeroStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniHeroPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MiniHeroPill({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.13),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 14),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
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
      ),
    );
  }
}

class _NgoDonationFilterBar extends StatelessWidget {
  final String selected;
  final Map<String, int> counts;
  final String Function(String status) labelFor;
  final void Function(String status) onSelected;
  final Color Function(String status) statusColor;

  const _NgoDonationFilterBar({
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
      padding: const EdgeInsets.fromLTRB(12, 14, 8, 8),
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
                    ? Icon(
                        Icons.check,
                        size: 14,
                        color: color,
                      )
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
          height: 34,
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
                  color: colorScheme.onSurface.withOpacity(0.55),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DonationCard extends StatelessWidget {
  final Map<String, dynamic> donation;
  final Color Function(String status) statusColor;
  final IconData Function(String status) statusIcon;
  final VoidCallback onOpen;

  const _DonationCard({
    required this.donation,
    required this.statusColor,
    required this.statusIcon,
    required this.onOpen,
  });

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map) return value.cast<String, dynamic>();
    return null;
  }

  static String _pickString(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  static String _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final id = (donation['donation_id'] as num).toInt();
    final type = donation['donation_type']?.toString().toUpperCase() ?? '';
    final status = donation['status']?.toString().toUpperCase() ?? '';
    final ngoName = donation['ngo_name']?.toString() ?? '';
    final createdAt = donation['created_at']?.toString() ?? '';
    final remarks = donation['remarks']?.toString() ?? '';

    final donor = _asMap(donation['donor']) ?? const <String, dynamic>{};
    final person = _asMap(donor['person']) ?? const <String, dynamic>{};

    final donorName = _firstNonEmpty([
      _pickString(donation, const ['donor_name', 'full_name']),
      _pickString(person, const ['full_name']),
      _pickString(donor, const ['full_name']),
      '(Unknown donor)',
    ]);

    final dropReq = (donation['dropoff_required'] as num?)?.toInt() == 1;
    final dropConf = (donation['dropoff_confirmed'] as num?)?.toInt() == 1;
    final proofUrl = donation['proof_photo_url']?.toString().trim() ?? '';
    final hasProof = proofUrl.isNotEmpty;

    final icon = type == 'MONEY'
        ? Icons.account_balance_wallet_outlined
        : Icons.inventory_2_outlined;

    final color = statusColor(status);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: colorScheme.primary, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Donation #$id',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _MiniTag(
                          label: type == 'MONEY' ? 'Money' : 'Items',
                          icon: icon,
                          color: colorScheme.primary,
                        ),
                        _MiniTag(
                          label: status,
                          icon: statusIcon(status),
                          color: color,
                        ),
                        if (hasProof)
                          const _MiniTag(
                            label: 'Proof',
                            icon: Icons.photo_camera_outlined,
                            color: Colors.teal,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _SmallInfoLine(
                      icon: Icons.person_outline,
                      text: donorName,
                    ),
                    if (ngoName.isNotEmpty)
                      _SmallInfoLine(
                        icon: Icons.storefront_outlined,
                        text: ngoName,
                      ),
                    _SmallInfoLine(
                      icon: Icons.local_shipping_outlined,
                      text: dropReq
                          ? (dropConf
                              ? 'Drop-off confirmed by donor'
                              : 'Waiting for donor drop-off confirmation')
                          : 'No drop-off required',
                    ),
                    if (createdAt.isNotEmpty)
                      _SmallInfoLine(
                        icon: Icons.access_time,
                        text: createdAt.length > 10
                            ? createdAt.substring(0, 10)
                            : createdAt,
                      ),
                    if (remarks.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        remarks,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface.withOpacity(0.55),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _MiniTag({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallInfoLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SmallInfoLine({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          Icon(
            icon,
            size: 13,
            color: colorScheme.onSurface.withOpacity(0.45),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurface.withOpacity(0.65),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyNgoDonations extends StatelessWidget {
  final String filter;
  final String Function(String status) labelFor;

  const _EmptyNgoDonations({
    required this.filter,
    required this.labelFor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      children: [
        const SizedBox(height: 90),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(
                  Icons.inbox_outlined,
                  size: 72,
                  color: colorScheme.secondary.withOpacity(0.45),
                ),
                const SizedBox(height: 14),
                Text(
                  filter.isEmpty
                      ? 'No donations for your NGO yet'
                      : 'No ${labelFor(filter)} donations',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  filter.isEmpty
                      ? 'Incoming public donations will appear here once donors submit them.'
                      : 'Try another status filter to view other donation records.',
                  style: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.55),
                    fontSize: 13,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}