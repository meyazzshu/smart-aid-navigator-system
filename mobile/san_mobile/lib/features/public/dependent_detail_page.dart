import 'package:flutter/material.dart';

import '../pps/dependent_registration_sheet.dart';
import '../pps/pps_slot_booking_api.dart';
import '../pps/shelter_request_models.dart';

class DependentDetailPage extends StatefulWidget {
  final AccountDependent dependent;
  final AccountAddressProfile? ownerAddress;

  const DependentDetailPage({
    super.key,
    required this.dependent,
    required this.ownerAddress,
  });

  @override
  State<DependentDetailPage> createState() => _DependentDetailPageState();
}

class _DependentDetailPageState extends State<DependentDetailPage> {
  static const Color _primary = Color(0xFF03466E);
  static const Color _accent = Color(0xFF54AFE6);
  static const Color _bg = Color(0xFFF4FAFD);

  final _api = PpsSlotBookingApi();

  late AccountDependent _dependent;
  bool _loading = false;
  bool _saving = false;

  bool get _isSelfDependent =>
    _dependent.relationshipType.trim().toUpperCase().replaceAll(' ', '_') == 'SELF';

  @override
  void initState() {
    super.initState();
    _dependent = widget.dependent;
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    final id = _dependent.dependentId;
    if (id == null) return;

    setState(() => _loading = true);

    try {
      final detail = await _api.getDependentDetail(id);

      if (!mounted) return;

      setState(() {
        _dependent = detail;
      });
    } catch (_) {
      // Keep list data if detail endpoint fails.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editDependent() async {
    final id = _dependent.dependentId;

    if (id == null) {
      _showMessage('Unable to edit: dependent ID not found.');
      return;
    }

    final payloads = await showDependentRegistrationSheet(
      context: context,
      ownerAddress: widget.ownerAddress,
      title: 'Edit Dependent',
      submitLabel: 'Update Dependent',
      initialDependent: _dependent,
    );

    if (payloads == null || payloads.isEmpty) return;

    setState(() => _saving = true);

    try {
      final res = await _api.updateMyDependent(
        dependentId: id,
        dependent: payloads.first,
      );

      if (!mounted) return;

      if (res['ok'] == true || res['success'] == true) {
        _showMessage('Dependent updated successfully.');

        final raw = res['dependent'];
        if (raw is Map) {
          setState(() {
            _dependent = AccountDependent.fromJson(raw.cast<String, dynamic>());
          });
        } else {
          await _loadDetail();
        }
      } else {
        _showMessage(res['error']?.toString() ?? 'Unable to update dependent.');
      }
    } catch (e) {
      _showMessage(_cleanError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteDependent() async {
    final id = _dependent.dependentId;

    if (id == null) {
      _showMessage('Unable to delete: dependent ID not found.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text(
          'Delete Dependent?',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Text(
          'This will remove ${_dependent.fullName.isEmpty ? "this dependent" : _dependent.fullName} from your account list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _saving = true);

    try {
      final res = await _api.deactivateMyDependent(id);

      if (!mounted) return;

      if (res['ok'] == true || res['success'] == true) {
        _showMessage('Dependent deleted successfully.');
        Navigator.pop(context, true);
      } else {
        _showMessage(res['error']?.toString() ?? 'Unable to delete dependent.');
      }
    } catch (e) {
      _showMessage(_cleanError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _cleanError(Object e) => e.toString().replaceFirst('Exception: ', '');

  @override
  Widget build(BuildContext context) {
    final name = _dependent.fullName.isEmpty ? 'Unnamed Dependent' : _dependent.fullName;
    final relationship = _formatLabel(_dependent.relationshipType);
    final gender = _formatLabel(_dependent.gender);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Dependent Details',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Edit',
            onPressed: _saving ? null : _editDependent,
            icon: const Icon(Icons.edit_rounded),
          ),
          if (!_isSelfDependent)
          IconButton(
            tooltip: 'Delete',
            onPressed: _saving ? null : _deleteDependent,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _loadDetail,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _heroCard(name, relationship, gender),
                const SizedBox(height: 16),
                _section(
                  title: 'Personal Information',
                  icon: Icons.info_rounded,
                  children: [
                    _infoTile(Icons.groups_rounded, 'Relationship', relationship),
                    _infoTile(Icons.wc_rounded, 'Gender', gender),
                    _infoTile(
                      Icons.calendar_month_rounded,
                      'Date of Birth',
                      _dependent.dateOfBirth.isEmpty ? 'N/A' : _dependent.dateOfBirth,
                    ),
                    _infoTile(
                      Icons.credit_card_rounded,
                      'IC / Passport',
                      _dependent.icOrPassport.isEmpty ? 'N/A' : _dependent.icOrPassport,
                    ),
                  ],
                ),
                _section(
                  title: 'Contact Details',
                  icon: Icons.call_rounded,
                  children: [
                    _infoTile(
                      Icons.phone_rounded,
                      'Phone',
                      _dependent.phone.isEmpty ? 'N/A' : _dependent.phone,
                    ),
                    _infoTile(
                      Icons.email_rounded,
                      'Email',
                      _dependent.email.isEmpty ? 'N/A' : _dependent.email,
                    ),
                  ],
                ),
                _section(
                  title: 'Address',
                  icon: Icons.home_rounded,
                  children: [
                    _infoTile(
                      Icons.location_on_rounded,
                      'Address Line',
                      _dependent.addressLine.isEmpty ? 'N/A' : _dependent.addressLine,
                    ),
                    _infoTile(
                      Icons.location_city_rounded,
                      'City',
                      _dependent.city.isEmpty ? 'N/A' : _dependent.city,
                    ),
                    _infoTile(
                      Icons.map_rounded,
                      'State',
                      _dependent.state.isEmpty ? 'N/A' : _dependent.state,
                    ),
                    _infoTile(
                      Icons.markunread_mailbox_rounded,
                      'Postal Code',
                      _dependent.postalCode.isEmpty ? 'N/A' : _dependent.postalCode,
                    ),
                    if (_dependent.latitude != null && _dependent.longitude != null)
                      _infoTile(
                        Icons.pin_drop_rounded,
                        'Coordinates',
                        '${_dependent.latitude!.toStringAsFixed(6)}, ${_dependent.longitude!.toStringAsFixed(6)}',
                      ),
                  ],
                ),
                const SizedBox(height: 90),
              ],
            ),
          ),
          if (_loading || _saving)
            Container(
              color: Colors.black.withOpacity(0.05),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 18,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Row(
            children: [
              if (!_isSelfDependent) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : _deleteDependent,
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Delete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      side: BorderSide(color: Colors.red.shade700),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _editDependent,
                  icon: const Icon(Icons.edit_rounded),
                  label: Text(_isSelfDependent ? 'Edit My Profile' : 'Edit'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heroCard(String name, String relationship, String gender) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_primary, _accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.22),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Hero(
            tag: 'dependent-avatar-${_dependent.dependentId ?? name}',
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: Colors.white.withOpacity(0.35)),
              ),
              child: const Icon(
                Icons.family_restroom_rounded,
                color: Colors.white,
                size: 42,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _chip(Icons.groups_rounded, relationship),
                    _chip(Icons.wc_rounded, gender),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _section({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.07),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: _primary, size: 21),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: _primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _primary.withOpacity(0.06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _primary, size: 21),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
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