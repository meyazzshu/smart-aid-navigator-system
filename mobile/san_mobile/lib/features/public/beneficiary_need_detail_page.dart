import 'package:flutter/material.dart';

import 'beneficiary_needs_api.dart';

class BeneficiaryNeedDetailPage extends StatelessWidget {
  final BeneficiaryNeedRequest need;

  const BeneficiaryNeedDetailPage({
    super.key,
    required this.need,
  });

  Color _statusColor(String status) {
    switch (status) {
      case 'SUBMITTED':
        return Colors.orange;
      case 'UNDER_REVIEW':
        return Colors.blue;
      case 'APPROVED':
        return Colors.indigo;
      case 'REJECTED':
        return Colors.red;
      case 'AWAITING_DONATION':
        return Colors.deepOrange;
      case 'READY_FOR_PICKUP':
        return Colors.green;
      case 'FULFILLED':
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'SUBMITTED':
        return Icons.send_outlined;
      case 'UNDER_REVIEW':
        return Icons.manage_search;
      case 'APPROVED':
        return Icons.verified_outlined;
      case 'REJECTED':
        return Icons.cancel_outlined;
      case 'AWAITING_DONATION':
        return Icons.volunteer_activism;
      case 'READY_FOR_PICKUP':
        return Icons.inventory_2_outlined;
      case 'FULFILLED':
        return Icons.check_circle_outline;
      default:
        return Icons.info_outline;
    }
  }

  String _label(String value) => value.replaceAll('_', ' ');

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusColor = _statusColor(need.requestStatus);

    return Scaffold(
      appBar: AppBar(
        title: Text('Aid Request #${need.needId}'),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.primary,
                  statusColor,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white.withValues(alpha:0.2),
                      child: const Icon(
                        Icons.handshake_outlined,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            need.itemName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            need.categoryName,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha:0.85),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha:0.18),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white.withValues(alpha:0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_statusIcon(need.requestStatus), color: Colors.white, size: 17),
                      const SizedBox(width: 7),
                      Text(
                        _label(need.requestStatus),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _DetailCard(
                  title: 'Request Summary',
                  icon: Icons.info_outline,
                  children: [
                    _InfoRow(label: 'Request ID', value: '#${need.needId}'),
                    _InfoRow(label: 'Shelter', value: need.shelterName.isEmpty ? '-' : need.shelterName),
                    _InfoRow(label: 'Status', value: _label(need.requestStatus), valueColor: statusColor),
                    _InfoRow(label: 'Priority', value: need.priority),
                    _InfoRow(label: 'Submitted', value: need.createdAt.isEmpty ? '-' : need.createdAt),
                  ],
                ),

                const SizedBox(height: 12),

                _DetailCard(
                  title: 'Aid Item Details',
                  icon: Icons.inventory_2_outlined,
                  children: [
                    _InfoRow(label: 'Item', value: need.itemName),
                    _InfoRow(label: 'Category', value: need.categoryName),
                    _InfoRow(label: 'Quantity Needed', value: '${need.requiredQuantity} ${need.unit}'),
                  ],
                ),

                const SizedBox(height: 12),

                _DetailCard(
                  title: 'Progress Tracking',
                  icon: Icons.timeline_outlined,
                  children: [
                    _TimelineItem(
                      title: 'Submitted',
                      active: true,
                      done: true,
                    ),
                    _TimelineItem(
                      title: 'Under Review',
                      active: need.requestStatus == 'UNDER_REVIEW',
                      done: _passed('UNDER_REVIEW', need.requestStatus),
                    ),
                    _TimelineItem(
                      title: 'Approved / Awaiting Donation',
                      active: need.requestStatus == 'APPROVED' || need.requestStatus == 'AWAITING_DONATION',
                      done: _passed('AWAITING_DONATION', need.requestStatus),
                    ),
                    _TimelineItem(
                      title: 'Ready For Pickup',
                      active: need.requestStatus == 'READY_FOR_PICKUP',
                      done: _passed('READY_FOR_PICKUP', need.requestStatus),
                    ),
                    _TimelineItem(
                      title: 'Fulfilled',
                      active: need.requestStatus == 'FULFILLED',
                      done: need.requestStatus == 'FULFILLED',
                      isLast: true,
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                _DetailCard(
                  title: 'Notes',
                  icon: Icons.note_alt_outlined,
                  children: [
                    Text(
                      need.notes.isEmpty ? 'No notes provided.' : need.notes,
                      style: TextStyle(
                        color: need.notes.isEmpty
                            ? colorScheme.onSurface.withValues(alpha:0.55)
                            : colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (need.rejectionReason.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha:0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.withValues(alpha:0.25)),
                        ),
                        child: Text(
                          'Rejected reason: ${need.rejectionReason}',
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _passed(String step, String status) {
    const order = [
      'SUBMITTED',
      'UNDER_REVIEW',
      'APPROVED',
      'AWAITING_DONATION',
      'READY_FOR_PICKUP',
      'FULFILLED',
    ];

    final stepIndex = order.indexOf(step);
    final statusIndex = order.indexOf(status);

    if (status == 'REJECTED') return false;
    if (stepIndex < 0 || statusIndex < 0) return false;

    return statusIndex >= stepIndex;
  }
}

class _DetailCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _DetailCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha:0.6),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueColor ?? colorScheme.onSurface,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final String title;
  final bool active;
  final bool done;
  final bool isLast;

  const _TimelineItem({
    required this.title,
    required this.active,
    required this.done,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = done || active ? Theme.of(context).colorScheme.primary : Colors.grey;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            CircleAvatar(
              radius: 10,
              backgroundColor: color,
              child: Icon(
                done ? Icons.check : Icons.circle,
                size: 11,
                color: Colors.white,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 28,
                color: color.withValues(alpha:0.35),
              ),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text(
              title,
              style: TextStyle(
                fontWeight: active ? FontWeight.w900 : FontWeight.w600,
                color: active ? color : null,
              ),
            ),
          ),
        ),
      ],
    );
  }
}