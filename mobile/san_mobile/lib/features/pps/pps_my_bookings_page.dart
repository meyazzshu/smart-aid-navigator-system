import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../auth/auth_controller.dart';
import 'pps_slot_booking_api.dart';
import 'shelter_request_models.dart';
import 'pps_booking_detail_page.dart';

class PpsMyBookingsPage extends ConsumerStatefulWidget {
  const PpsMyBookingsPage({super.key});

  @override
  ConsumerState<PpsMyBookingsPage> createState() => _PpsMyBookingsPageState();
}

class _PpsMyBookingsPageState extends ConsumerState<PpsMyBookingsPage> {
  final _api = PpsSlotBookingApi();

  bool _loading = false;
  String? _error;
  List<ShelterRequest>? _requests;
  List<AccountDependent> _accountDependents = const [];

  final Set<int> _locallyDischargedRequestIds = <int>{};

  @override
  void initState() {
    super.initState();
    _loadMyBookings();
    _loadOwnerData();
  }

  Future<void> _loadOwnerData() async {
    try {
      final dependents = await _api.getMyDependents();
      if (!mounted) return;
      setState(() => _accountDependents = dependents);
    } catch (_) {
      // Keep bookings flow usable even if dependent list fails.
    }
  }

  Future<void> _loadMyBookings() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _api.getMyBookings();
      if (!res.ok) {
        setState(() => _error = res.error ?? res.message ?? 'Unable to load your bookings.');
        return;
      }
      setState(() => _requests = res.requests);
    } catch (e) {
      setState(() => _error = 'Error: ${_cleanError(e)}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cancelBooking(int requestId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: const Text(
            'Are you sure you want to cancel this PPS slot booking?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final res = await _api.cancelRequest(requestId);
      if (!mounted) return;
      if (res['ok'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking cancelled successfully.')),
        );
        _loadMyBookings();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                res['error']?.toString() ?? 'Failed to cancel booking.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${_cleanError(e)}')),
      );
    }
  }

  Future<void> _selectDependentsForRequest(ShelterRequest req) async {
    final requestId = req.requestId;
    if (requestId == null) return;
    if (_accountDependents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No account dependents found. Add dependents first in My tab.'),
        ),
      );
      return;
    }

    final selectedIds = await showDialog<List<int>>(
      context: context,
      builder: (_) => _DependentSelectionDialog(
        dependents: _accountDependents,
        preselectedDependents: req.dependents,
      ),
    );
    if (selectedIds == null) return;

    final selected = _accountDependents.where((d) => selectedIds.contains(d.dependentId)).toList();
    final bookedMale = req.babiesMale + req.kidsMale + req.adultMale;
    final bookedFemale = req.babiesFemale + req.kidsFemale + req.adultFemale;
    final selectedMale = selected.where((d) => _normalizeGender(d.gender) == 'male').length;
    final selectedFemale = selected.where((d) => _normalizeGender(d.gender) == 'female').length;
    final unknownGender = selected.where((d) => _normalizeGender(d.gender) == null).length;

    if (unknownGender > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$unknownGender selected dependent(s) have unknown gender. Please update them to Male or Female first.',
          ),
        ),
      );
      return;
    }
    if (selectedMale != bookedMale || selectedFemale != bookedFemale) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Selected dependents do not tally with booking gender counts. '
            'Booking M/F: $bookedMale/$bookedFemale, Selected M/F: $selectedMale/$selectedFemale.',
          ),
        ),
      );
      return;
    }

    try {
      final res = await _api.assignDependentsToRequest(
        requestId: requestId,
        dependentIds: selectedIds,
      );
      if (!mounted) return;
      if (res['ok'] == true || res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dependents assigned to booking successfully.')),
        );
        await _loadOwnerData();
        await _loadMyBookings();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['error']?.toString() ?? 'Failed to assign dependents.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${_cleanError(e)}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final user = ref.watch(authControllerProvider).user;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildHeader(colorScheme, user?.fullName)),
        if (_loading)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        if (_error != null && !_loading)
          SliverToBoxAdapter(child: _buildError(colorScheme)),
        if (_requests != null && !_loading)
          _requests!.isEmpty
              ? SliverToBoxAdapter(child: _buildEmpty(colorScheme))
              : SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildRequestCard(
                          context, _requests![index], colorScheme, index),
                      childCount: _requests!.length,
                    ),
                  ),
                ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  Widget _buildHeader(ColorScheme colorScheme, String? fullName) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary,
            colorScheme.primary.withValues(alpha:0.75),
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
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha:0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.meeting_room_outlined,
                    color: Colors.white, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'My PPS Bookings',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Pusat Pemindahan Sementara',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha:0.85),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: _loading ? null : _loadMyBookings,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            fullName != null && fullName.isNotEmpty
                ? 'Showing all PPS slot bookings for $fullName.'
                : 'Showing all your PPS slot bookings.',
            style: TextStyle(
              color: Colors.white.withValues(alpha:0.9),
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
    
  }

  Widget _buildError(ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colorScheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error!,
              style: TextStyle(
                  color: colorScheme.onErrorContainer, fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
      child: Column(
        children: [
          Icon(Icons.event_busy, size: 64, color: colorScheme.outlineVariant),
          const SizedBox(height: 16),
          Text(
            'No Bookings Yet',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You have no PPS slot bookings linked to your account.\n\nIf you booked as a guest using this email or phone number, it will appear here automatically.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurface.withValues(alpha:0.6),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  String _displayStatusFor(ShelterRequest req) {
    final requestId = req.requestId;

    if (requestId != null && _locallyDischargedRequestIds.contains(requestId)) {
      return 'DISCHARGED';
    }

    return req.status;
  }

  Widget _buildRequestCard(
    BuildContext context,
    ShelterRequest req,
    ColorScheme colorScheme,
    int index,
  ) {
      final String status = _displayStatusFor(req);
      final statusStyle = _statusStyle(status, colorScheme);

      final String shelterName = req.shelterName.isNotEmpty ? req.shelterName : '—';
      final String fullName = req.fullName.isNotEmpty ? req.fullName : '—';
      final String email = req.email.isNotEmpty ? req.email : '—';
      final String phone = req.phone.isNotEmpty ? req.phone : '—';
      final int totalPeople = req.totalPeople;
      final int? requestId = req.requestId;
      final String formattedDate = _formatDate(req.createdAtRaw);
      final int dependentCount = req.dependents.length;

      final String statusLower = status.toLowerCase();
      final bool canCancel = statusLower == 'pending' ||
          statusLower == 'confirmed' ||
          statusLower == 'approved';

      return InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          final changed = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => PpsBookingDetailPage(request: req),
            ),
          );

          if (changed == true && req.requestId != null) {
            setState(() {
              _locallyDischargedRequestIds.add(req.requestId!);
            });

            await _loadMyBookings();
          }
        },
        child: Card(
          margin: const EdgeInsets.only(
            top: 10,
            bottom: 16,
          ),
          elevation: 0,
          
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha:0.5)),
          ),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card header - shelter name + status badge
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha:0.35),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha:0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.home,
                        color: colorScheme.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shelterName,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        if (requestId != null)
                          Text(
                            'Booking #$requestId',
                            style: TextStyle(
                              fontSize: 11.5,
                              color:
                                  colorScheme.onSurface.withValues(alpha:0.55),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusStyle.background,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: statusStyle.border),
                    ),
                    child: Text(
                      statusStyle.label,
                      style: TextStyle(
                        color: statusStyle.foreground,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('Registrant Details', colorScheme),
                  const SizedBox(height: 8),
                  _infoRow(
                      Icons.person_outline, 'Full Name', fullName, colorScheme),
                  _infoRow(
                      Icons.email_outlined, 'Email', email, colorScheme),
                  _infoRow(
                      Icons.phone_outlined, 'Phone', phone, colorScheme),
                  if (formattedDate.isNotEmpty)
                    _infoRow(Icons.calendar_today_outlined, 'Requested On',
                        formattedDate, colorScheme),
                    _infoRow(
                      Icons.visibility_outlined,
                      'Details',
                      'Tap card to view full request',
                      colorScheme,
                    ),

                  const SizedBox(height: 14),
                  _sectionLabel('People Count', colorScheme),
                  const SizedBox(height: 8),
                  _buildPeopleGrid(req, colorScheme, totalPeople),
                  const SizedBox(height: 8),
                  _infoRow(
                    Icons.groups_2_outlined,
                    'Dependents',
                    dependentCount > 0 ? '$dependentCount registered' : 'Not registered yet',
                    colorScheme,
                  ),

                  if (requestId != null) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _selectDependentsForRequest(req),
                        icon: const Icon(Icons.group_add_outlined),
                        label: Text(
                          dependentCount > 0
                              ? 'Update Assigned Dependents'
                              : 'Select Dependents from My Account',
                        ),
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],

                  if (canCancel && requestId != null) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _cancelBooking(requestId),
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Cancel Booking'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colorScheme.error,
                          side: BorderSide(color: colorScheme.error),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
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
    );
  }

  Widget _sectionLabel(String text, ColorScheme colorScheme) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: colorScheme.primary,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 7),
        Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: colorScheme.primary,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _infoRow(
      IconData icon, String label, String value, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon,
              size: 16, color: colorScheme.onSurface.withValues(alpha:0.45)),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurface.withValues(alpha:0.55),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeopleGrid(
      ShelterRequest req, ColorScheme colorScheme, int totalPeople) {
    final categories = <_PersonCategory>[
      _PersonCategory(
        label: 'Babies\nMale',
        count: req.babiesMale,
        icon: Icons.baby_changing_station,
      ),
      _PersonCategory(
        label: 'Babies\nFemale',
        count: req.babiesFemale,
        icon: Icons.baby_changing_station,
      ),
      _PersonCategory(
        label: 'Kids\nMale',
        count: req.kidsMale,
        icon: Icons.child_care,
      ),
      _PersonCategory(
        label: 'Kids\nFemale',
        count: req.kidsFemale,
        icon: Icons.child_care,
      ),
      _PersonCategory(
        label: 'Adult\nMale',
        count: req.adultMale,
        icon: Icons.person,
      ),
      _PersonCategory(
        label: 'Adult\nFemale',
        count: req.adultFemale,
        icon: Icons.person,
      ),
    ];

    final total = totalPeople;

    return Column(
      children: [
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.4,
          children:
              categories.map((c) => _personCell(c, colorScheme)).toList(),
        ),
        const SizedBox(height: 10),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha:0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.groups,
                      color: colorScheme.primary, size: 18),
                  const SizedBox(width: 7),
                  Text(
                    'Total People',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
              Text(
                '$total',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _personCell(_PersonCategory cat, ColorScheme colorScheme) {
    final count = cat.count ?? 0;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha:0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(cat.icon,
              size: 16, color: colorScheme.onSurface.withValues(alpha:0.5)),
          const SizedBox(height: 4),
          Text(
            '$count',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: count > 0
                  ? colorScheme.primary
                  : colorScheme.onSurface.withValues(alpha:0.4),
            ),
          ),
          Text(
            cat.label,
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

  _StatusStyle _statusStyle(String status, ColorScheme colorScheme) {
    final lower = status.toLowerCase();
    if (lower == 'confirmed' || lower == 'approved') {
      return _StatusStyle(
        label: 'Confirmed',
        foreground: const Color(0xFF15803D),
        background: const Color(0xFFDCFCE7),
        border: const Color(0xFF86EFAC),
      );
    } else if (lower == 'pending') {
      return _StatusStyle(
        label: 'Pending',
        foreground: const Color(0xFF92400E),
        background: const Color(0xFFFEF3C7),
        border: const Color(0xFFFCD34D),
      );
    } else if (lower == 'rejected' || lower == 'cancelled') {
      return _StatusStyle(
        label: _capitalize(status),
        foreground: colorScheme.error,
        background: colorScheme.errorContainer,
        border: colorScheme.error.withValues(alpha:0.4),
      );
    } else if (lower == 'arrived' || lower == 'checked_in' || lower == 'checked in') {
      return _StatusStyle(
        label: 'Arrived',
        foreground: const Color(0xFF1D4ED8),
        background: const Color(0xFFDBEAFE),
        border: const Color(0xFF93C5FD),
      );
    } else if (lower == 'discharged') {
      return _StatusStyle(
        label: 'Discharged',
        foreground: const Color(0xFF475569),
        background: const Color(0xFFE2E8F0),
        border: const Color(0xFFCBD5E1),
      );
    } else { if (lower == 'discharged') {
      return _StatusStyle(
        label: 'Discharged',
        foreground: const Color(0xFF475569),
        background: const Color(0xFFE2E8F0),
        border: const Color(0xFFCBD5E1),
      );
    } else {
      return _StatusStyle(
        label: _capitalize(status),
        foreground: colorScheme.onSurface.withValues(alpha:0.7),
        background: colorScheme.surfaceContainerHighest,
        border: colorScheme.outlineVariant,
      );
    }
  }
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() +
        s.substring(1).toLowerCase().replaceAll('_', ' ');
  }

  String _cleanError(Object e) => e.toString().replaceFirst('Exception: ', '');

  String? _normalizeGender(String raw) {
    final value = raw.trim().toLowerCase();
    switch (value) {
      case 'male':
      case 'm':
      case 'lelaki':
        return 'male';
      case 'female':
      case 'f':
      case 'perempuan':
        return 'female';
      default:
        return null;
    }
  }
}

class _StatusStyle {
  final String label;
  final Color foreground;
  final Color background;
  final Color border;

  const _StatusStyle({
    required this.label,
    required this.foreground,
    required this.background,
    required this.border,
  });
}

class _PersonCategory {
  final String label;
  final int? count;
  final IconData icon;

  const _PersonCategory({
    required this.label,
    required this.count,
    required this.icon,
  });
}

class _DependentSelectionDialog extends StatefulWidget {
  final List<AccountDependent> dependents;
  final List<DependentRecord> preselectedDependents;

  const _DependentSelectionDialog({
    required this.dependents,
    required this.preselectedDependents,
  });

  @override
  State<_DependentSelectionDialog> createState() => _DependentSelectionDialogState();
}

class _DependentSelectionDialogState extends State<_DependentSelectionDialog> {
  late final Set<int> _selectedIds = {
    for (final d in widget.preselectedDependents)
      if (d.dependentId != null) d.dependentId!,
  };

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Dependents'),
      content: SizedBox(
        width: 420,
        child: widget.dependents.isEmpty
            ? const Text('No account dependents found.')
            : ListView.builder(
                shrinkWrap: true,
                itemCount: widget.dependents.length,
                itemBuilder: (_, index) {
                  final dep = widget.dependents[index];
                  final id = dep.dependentId;
                  final checked = id != null && _selectedIds.contains(id);
                  return CheckboxListTile(
                    value: checked,
                    onChanged: id == null
                        ? null
                        : (v) {
                            setState(() {
                              if (v == true) {
                                _selectedIds.add(id);
                              } else {
                                _selectedIds.remove(id);
                              }
                            });
                          },
                    title: Text(dep.fullName.isEmpty ? 'Unnamed dependent' : dep.fullName),
                    subtitle: Text(
                      '${dep.relationshipType} • ${dep.gender.isEmpty ? "Gender N/A" : dep.gender}',
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_selectedIds.toList()),
          child: const Text('Save Selection'),
        ),
      ],
    );
  }
}
