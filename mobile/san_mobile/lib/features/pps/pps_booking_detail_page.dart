import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'shelter_request_models.dart';
import 'pps_slot_booking_api.dart';

class PpsBookingDetailPage extends StatefulWidget {
  final ShelterRequest request;

  const PpsBookingDetailPage({
    super.key,
    required this.request,
  });

  @override
  State<PpsBookingDetailPage> createState() => _PpsBookingDetailPageState();
}

class _PpsBookingDetailPageState extends State<PpsBookingDetailPage> {
  final PpsSlotBookingApi _api = PpsSlotBookingApi();

  bool _discharging = false;

  bool _dischargedNow = false;

  ShelterRequest get request => widget.request;

  bool get _isDischarged {
    return _dischargedNow || request.isDischarged;
  }

  bool get _canDischarge {
    final status = request.status.toUpperCase().trim();

    return request.requestId != null && status == 'ARRIVED';
  }

  Future<void> _dischargeFromShelter() async {
    final requestId = request.requestId;

    if (requestId == null) {
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Discharge from shelter?'),
          content: const Text(
            'This will mark the received beneficiaries for this booking as discharged from the shelter.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes, Discharge'),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    setState(() {
      _discharging = true;
    });

    try {
      final result = await _api.dischargeRequest(requestId);

      if (result['ok'] != true) {
        throw Exception(result['error'] ?? 'Unable to discharge from shelter.');
      }

      if (!mounted) return;

      final count = result['discharged_count']?.toString() ?? '0';

      setState(() {
        _dischargedNow = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Discharged successfully. $count beneficiary record(s) updated.'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
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
          _discharging = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusStyle = _statusStyle(request.status, colorScheme);
    final requestId = request.requestId;
    final formattedDate = _formatDate(request.createdAtRaw);

    return Scaffold(
      appBar: AppBar(
        title: Text(requestId == null ? 'PPS Booking Details' : 'PPS Booking #$requestId'),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.primary,
                  statusStyle.foreground.withValues(alpha:0.75),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha:0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.meeting_room_outlined,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            requestId == null ? 'PPS Booking' : 'PPS Booking #$requestId',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            request.shelterName.isEmpty ? 'PPS Booking' : request.shelterName,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha:0.85),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha:0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusStyle.icon, color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        statusStyle.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
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
                  title: 'Booking Information',
                  icon: Icons.info_outline,
                  children: [
                    _InfoRow(
                      icon: Icons.home_outlined,
                      label: 'Shelter',
                      value: request.shelterName.isEmpty ? '-' : request.shelterName,
                    ),
                    _InfoRow(
                      icon: Icons.confirmation_number_outlined,
                      label: 'Request ID',
                      value: requestId?.toString() ?? '-',
                    ),
                    _InfoRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Requested On',
                      value: formattedDate.isEmpty ? '-' : formattedDate,
                    ),
                    _InfoRow(
                      icon: statusStyle.icon,
                      label: 'Status',
                      value: statusStyle.label,
                      valueColor: statusStyle.foreground,
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                _DetailCard(
                  title: 'Registrant Details',
                  icon: Icons.person_outline,
                  children: [
                    _InfoRow(
                      icon: Icons.badge_outlined,
                      label: 'Full Name',
                      value: request.fullName.isEmpty ? '-' : request.fullName,
                    ),
                    _InfoRow(
                      icon: Icons.email_outlined,
                      label: 'Email',
                      value: request.email.isEmpty ? '-' : request.email,
                    ),
                    _InfoRow(
                      icon: Icons.phone_outlined,
                      label: 'Phone',
                      value: request.phone.isEmpty ? '-' : request.phone,
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                _DetailCard(
                  title: 'People Count',
                  icon: Icons.groups_2_outlined,
                  children: [
                    _PeopleGrid(request: request),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha:0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.groups, color: colorScheme.primary, size: 18),
                              const SizedBox(width: 7),
                              Text(
                                'Total People',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '${request.totalPeople}',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                _DetailCard(
                  title: 'Assigned Dependents',
                  icon: Icons.family_restroom_outlined,
                  children: [
                    if (request.dependents.isEmpty)
                      Text(
                        'No dependents assigned yet.',
                        style: TextStyle(
                          color: colorScheme.onSurface.withValues(alpha:0.6),
                        ),
                      )
                    else
                      ...request.dependents.map(
                        (dependent) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: colorScheme.secondary.withValues(alpha:0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.person, color: colorScheme.primary, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      dependent.fullName.isEmpty ? 'Unnamed dependent' : dependent.fullName,
                                      style: const TextStyle(fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${dependent.relationshipType} • ${dependent.gender.isEmpty ? "Gender N/A" : dependent.gender}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colorScheme.onSurface.withValues(alpha:0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                if (_isDischarged)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.green.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 18,
                          backgroundColor: Color(0xFF15803D),
                          child: Icon(
                            Icons.check_circle_outline,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Discharged',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                  color: Color(0xFF15803D),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                request.dischargedCount > 0
                                    ? '${request.dischargedCount} beneficiary record(s) have been discharged from this shelter.'
                                    : 'The beneficiary record(s) for this booking have been discharged from the shelter.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onSurface.withValues(alpha: 0.65),
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                else if (_canDischarge)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _discharging ? null : _dischargeFromShelter,
                      icon: _discharging
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.logout_outlined),
                      label: Text(
                        _discharging ? 'Discharging...' : 'Discharge from Shelter',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  )
                else
                _DetailCard(
                  title: 'Discharge Status',
                  icon: _isDischarged ? Icons.logout_outlined : Icons.info_outline,
                  children: [
                    Text(
                      _isDischarged
                          ? 'Discharged'
                          : request.status.toUpperCase() == 'CANCELLED'
                              ? 'This booking has been cancelled.'
                              : 'Discharge is only available after the booking status becomes ARRIVED, because only arrived requestors are registered as beneficiaries.',
                      style: TextStyle(
                        color: _isDischarged
                            ? const Color(0xFF475569)
                            : colorScheme.onSurface.withValues(alpha: 0.65),
                        fontWeight: _isDischarged ? FontWeight.w800 : FontWeight.normal,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      return DateFormat('d MMM yyyy, h:mm a').format(dt);
    } catch (_) {
      return raw;
    }
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
                Icon(icon, color: colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
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
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 17,
            color: colorScheme.onSurface.withValues(alpha: 0.45),
          ),
          const SizedBox(width: 10),

          SizedBox(
            width: 115,
            child: Text(
              label,
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.58),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: valueColor ?? colorScheme.onSurface,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeopleGrid extends StatelessWidget {
  final ShelterRequest request;

  const _PeopleGrid({required this.request});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final items = [
      _PeopleItem('Babies\nMale', request.babiesMale, Icons.baby_changing_station),
      _PeopleItem('Babies\nFemale', request.babiesFemale, Icons.baby_changing_station),
      _PeopleItem('Kids\nMale', request.kidsMale, Icons.child_care),
      _PeopleItem('Kids\nFemale', request.kidsFemale, Icons.child_care),
      _PeopleItem('Adult\nMale', request.adultMale, Icons.person),
      _PeopleItem('Adult\nFemale', request.adultFemale, Icons.person),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.4,
      children: items.map((item) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha:0.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.icon, size: 16, color: colorScheme.onSurface.withValues(alpha:0.5)),
              const SizedBox(height: 4),
              Text(
                '${item.count}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: item.count > 0
                      ? colorScheme.primary
                      : colorScheme.onSurface.withValues(alpha:0.4),
                ),
              ),
              Text(
                item.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9.5,
                  color: colorScheme.onSurface.withValues(alpha:0.5),
                  height: 1.2,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _PeopleItem {
  final String label;
  final int count;
  final IconData icon;

  const _PeopleItem(this.label, this.count, this.icon);
}

class _RequestStatusStyle {
  final String label;
  final IconData icon;
  final Color foreground;

  const _RequestStatusStyle({
    required this.label,
    required this.icon,
    required this.foreground,
  });
}

_RequestStatusStyle _statusStyle(String status, ColorScheme colorScheme) {
  final lower = status.toLowerCase();

  if (lower == 'confirmed' || lower == 'approved') {
    return const _RequestStatusStyle(
      label: 'Confirmed',
      icon: Icons.check_circle,
      foreground: Color(0xFF15803D),
    );
  }

  if (lower == 'pending') {
    return const _RequestStatusStyle(
      label: 'Pending',
      icon: Icons.hourglass_empty,
      foreground: Color(0xFF92400E),
    );
  }

  if (lower == 'rejected' || lower == 'cancelled') {
    return _RequestStatusStyle(
      label: _capitalize(status),
      icon: Icons.cancel,
      foreground: colorScheme.error,
    );
  }

  if (lower == 'arrived' || lower == 'checked_in' || lower == 'checked in') {
    return const _RequestStatusStyle(
      label: 'Arrived',
      icon: Icons.verified,
      foreground: Color(0xFF1D4ED8),
    );
  }

  if (lower == 'discharged') {
    return const _RequestStatusStyle(
      label: 'Discharged',
      icon: Icons.logout_outlined,
      foreground: Color(0xFF475569),
    );
  }

  if (lower == 'discharged') {
    return const _RequestStatusStyle(
      label: 'Discharged',
      icon: Icons.check_circle_outline,
      foreground: Color(0xFF15803D),
    );
  }

  return _RequestStatusStyle(
    label: _capitalize(status),
    icon: Icons.info_outline,
    foreground: colorScheme.primary,
  );
}

String _capitalize(String value) {
  if (value.isEmpty) return value;
  return value[0].toUpperCase() + value.substring(1).toLowerCase().replaceAll('_', ' ');
}