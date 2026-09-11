import 'package:flutter/material.dart';

import '../pps/dependent_registration_sheet.dart';
import '../pps/pps_slot_booking_api.dart';
import '../pps/shelter_request_models.dart';
import 'dependent_detail_page.dart';

class MyDependentsPage extends StatefulWidget {
  const MyDependentsPage({super.key});

  @override
  State<MyDependentsPage> createState() => _MyDependentsPageState();
}

class _MyDependentsPageState extends State<MyDependentsPage> {
  static const Color _primary = Color(0xFF03466E);
  static const Color _accent = Color(0xFF54AFE6);
  static const Color _bg = Color(0xFFF4FAFD);

  final _api = PpsSlotBookingApi();

  bool _loading = false;
  bool _saving = false;
  String? _error;
  List<AccountDependent> _dependents = const [];
  AccountAddressProfile? _ownerAddress;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _api.getMyDependents(),
        _api.getAccountAddressProfile(),
      ]);

      if (!mounted) return;

      setState(() {
        _dependents = results[0] as List<AccountDependent>;
        _ownerAddress = results[1] as AccountAddressProfile?;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Error: ${_cleanError(e)}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addDependents() async {
    final payloads = await showDependentRegistrationSheet(
      context: context,
      ownerAddress: _ownerAddress,
      title: 'Add Dependents to My Account',
      submitLabel: 'Save to My Account',
    );

    if (payloads == null || payloads.isEmpty) return;

    setState(() => _saving = true);

    try {
      final res = await _api.registerMyDependents(dependents: payloads);

      if (!mounted) return;

      if (res['ok'] == true || res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dependents saved under your account.')),
        );
        await _load();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['error']?.toString() ?? 'Unable to save dependents.')),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${_cleanError(e)}')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openDependentDetail(AccountDependent dependent) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DependentDetailPage(
          dependent: dependent,
          ownerAddress: _ownerAddress,
        ),
      ),
    );

    if (changed == true) {
      await _load();
    } else {
      await _load();
    }
  }

  bool _isSelfDependent(AccountDependent dependent) {
    return dependent.relationshipType.trim().toUpperCase().replaceAll(' ', '_') == 'SELF';
  }

  String _formatLabel(String value) {
    if (value.trim().isEmpty) return 'N/A';

    return value
        .replaceAll('_', ' ')
        .toLowerCase()
        .split(' ')
        .map((word) => word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'My Dependents',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorView()
              : _dependents.isEmpty
                  ? _emptyView()
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _dependents.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _dependentCard(_dependents[i]),
                      ),
                    ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        onPressed: _saving ? null : _addDependents,
        icon: _saving
            ? const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.person_add_alt_1_rounded),
        label: Text(
          _saving ? 'Saving...' : 'Add Dependent',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.red.shade100),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.red.shade700, size: 34),
              const SizedBox(height: 10),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red.shade800),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: _primary.withOpacity(0.08),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: const Icon(Icons.family_restroom_rounded, color: _primary, size: 38),
              ),
              const SizedBox(height: 16),
              const Text(
                'No dependents saved yet',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: _primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your account owner profile and added family members will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700, height: 1.4),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: _saving ? null : _addDependents,
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Add Dependent'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dependentCard(AccountDependent d) {
    final name = d.fullName.isEmpty ? 'Unnamed dependent' : d.fullName;
    final relationship = _formatLabel(d.relationshipType);
    final gender = _formatLabel(d.gender);
    final isSelf = _isSelfDependent(d);

    return InkWell(
      onTap: () => _openDependentDetail(d),
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelf ? _accent.withOpacity(0.55) : Colors.transparent,
            width: isSelf ? 1.2 : 0,
          ),
          boxShadow: [
            BoxShadow(
              color: _primary.withOpacity(0.07),
              blurRadius: 16,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Row(
          children: [
            Hero(
              tag: 'dependent-avatar-${d.dependentId ?? d.fullName}',
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: isSelf ? _primary.withOpacity(0.10) : _accent.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelf ? _accent.withOpacity(0.65) : Colors.transparent,
                  ),
                ),
                child: Icon(
                  isSelf ? Icons.account_circle_rounded : Icons.person_outline_rounded,
                  color: _primary,
                  size: isSelf ? 34 : 30,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: _primary,
                          ),
                        ),
                      ),
                      if (isSelf)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: _accent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Owner',
                            style: TextStyle(
                              color: _primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '$relationship • $gender',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  if (isSelf) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _primary.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Account Owner Profile',
                        style: TextStyle(
                          color: _primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                  if (d.dateOfBirth.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      'DOB: ${d.dateOfBirth}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: _primary),
          ],
        ),
      ),
    );
  }

  String _cleanError(Object e) => e.toString().replaceFirst('Exception: ', '');
}