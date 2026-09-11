import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'pps_slot_booking_api.dart';
import 'shelter_request_models.dart';

class PpsSlotBookingPage extends StatefulWidget {
  const PpsSlotBookingPage({super.key});

  @override
  State<PpsSlotBookingPage> createState() => _PpsSlotBookingPageState();
}

class _PpsSlotBookingPageState extends State<PpsSlotBookingPage> {
  final _api = PpsSlotBookingApi();
  final _contactCtrl = TextEditingController();
  final _focusNode = FocusNode();

  bool _loading = false;
  String? _error;
  List<ShelterRequest>? _requests;
  String _lastQuery = '';

  @override
  void dispose() {
    _contactCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    final raw = _contactCtrl.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = 'Please enter your email, phone number, or request ID.');
      return;
    }

    _focusNode.unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _requests = null;
      _lastQuery = raw;
    });

    try {
      final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
      final bool isEmail = emailRegex.hasMatch(raw);
      final digitsOnly = RegExp(r'^\d+$').hasMatch(raw);
      final looksLikePhone = digitsOnly && raw.length >= 8 && raw.length <= 15;
      final int? requestId = digitsOnly && !looksLikePhone ? int.parse(raw) : null;
      final res = await _api.lookupRequests(
        email: isEmail ? raw : null,
        phone: (!isEmail && requestId == null) ? raw : null,
        requestId: requestId,
      );

      if (!res.ok) {
        setState(() => _error = res.error ??
            res.message ??
            'Unable to find bookings. Please verify your email or phone number and try again.');
        return;
      }
      setState(() => _requests = res.requests);
    } catch (e) {
      setState(() => _error = 'Error: ${_cleanError(e)}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _buildHeader(colorScheme),
          ),
          SliverToBoxAdapter(
            child: _buildSearchSection(colorScheme),
          ),
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
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary,
            colorScheme.primary.withOpacity(0.75),
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
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.meeting_room_outlined, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PPS Slot Booking',
                      style: const TextStyle(
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
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Check your PPS slot booking status by entering your email, phone number, or request ID below.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSection(ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Look Up Your Booking',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Enter the email, phone, or request ID used during registration.',
            style: TextStyle(
              fontSize: 12.5,
              color: colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _contactCtrl,
            focusNode: _focusNode,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _lookup(),
            decoration: InputDecoration(
              hintText: 'e.g. user@email.com, +60123456789, or 12345',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.4),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: _loading ? null : _lookup,
              icon: _loading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.arrow_forward),
              label: Text(_loading ? 'Searching…' : 'Check Booking Status'),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
              style: TextStyle(color: colorScheme.onErrorContainer, fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 32),
      child: Column(
        children: [
          Icon(Icons.search_off, size: 64, color: colorScheme.outlineVariant),
          const SizedBox(height: 16),
          Text(
            'No Bookings Found',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No PPS slot requests were found for\n"$_lastQuery".\n\nPlease check your email or phone number and try again.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurface.withOpacity(0.6),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(
    BuildContext context,
    ShelterRequest req,
    ColorScheme colorScheme,
    int index,
  ) {
    final String status = req.status;
    final statusStyle = _statusStyle(status, colorScheme);

    final String shelterName = req.shelterName.isNotEmpty ? req.shelterName : '—';
    final String fullName = req.fullName.isNotEmpty ? req.fullName : '—';
    final String email = req.email.isNotEmpty ? req.email : '—';
    final String phone = req.phone.isNotEmpty ? req.phone : '—';
    final int totalPeople = req.totalPeople;
    final int? requestId = req.requestId;
    final String formattedDate = _formatDate(req.createdAtRaw);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header - shelter name + status badge
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withOpacity(0.35),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.home, color: colorScheme.primary, size: 20),
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
                            color: colorScheme.onSurface.withOpacity(0.55),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                // Registrant info
                _sectionLabel('Registrant Details', colorScheme),
                const SizedBox(height: 8),
                _infoRow(Icons.person_outline, 'Full Name', fullName, colorScheme),
                _infoRow(Icons.email_outlined, 'Email', email, colorScheme),
                _infoRow(Icons.phone_outlined, 'Phone', phone, colorScheme),
                if (formattedDate.isNotEmpty)
                  _infoRow(Icons.calendar_today_outlined, 'Requested On', formattedDate, colorScheme),

                const SizedBox(height: 14),
                _sectionLabel('People Count', colorScheme),
                const SizedBox(height: 8),
                _buildPeopleGrid(req, colorScheme, totalPeople),
              ],
            ),
          ),
        ],
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

  Widget _infoRow(IconData icon, String label, String value, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: colorScheme.onSurface.withOpacity(0.45)),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurface.withOpacity(0.55),
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
          children: categories.map((c) => _personCell(c, colorScheme)).toList(),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: colorScheme.primary.withOpacity(0.08),
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
        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(cat.icon, size: 16, color: colorScheme.onSurface.withOpacity(0.5)),
          const SizedBox(height: 4),
          Text(
            '$count',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: count > 0 ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
          Text(
            cat.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9.5,
              color: colorScheme.onSurface.withOpacity(0.5),
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
        border: colorScheme.error.withOpacity(0.4),
      );
    } else if (lower == 'checked_in' || lower == 'checked in') {
      return _StatusStyle(
        label: 'Checked In',
        foreground: const Color(0xFF1D4ED8),
        background: const Color(0xFFDBEAFE),
        border: const Color(0xFF93C5FD),
      );
    } else {
      return _StatusStyle(
        label: _capitalize(status),
        foreground: colorScheme.onSurface.withOpacity(0.7),
        background: colorScheme.surfaceContainerHighest,
        border: colorScheme.outlineVariant,
      );
    }
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).toLowerCase().replaceAll('_', ' ');
  }

  String _cleanError(Object e) => e.toString().replaceFirst('Exception: ', '');
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
