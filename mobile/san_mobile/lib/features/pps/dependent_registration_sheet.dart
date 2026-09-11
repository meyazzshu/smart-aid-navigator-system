import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'shelter_request_models.dart';

Future<List<DependentRegistrationPayload>?> showDependentRegistrationSheet({
  required BuildContext context,
  required AccountAddressProfile? ownerAddress,
  String title = 'Register Dependents',
  String submitLabel = 'Save Dependents',
  AccountDependent? initialDependent,
}) {
  return showModalBottomSheet<List<DependentRegistrationPayload>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _DependentRegistrationSheet(
      ownerAddress: ownerAddress,
      title: title,
      submitLabel: submitLabel,
      initialDependent: initialDependent,
    ),
  );
}

class _DependentRegistrationSheet extends StatefulWidget {
  final AccountAddressProfile? ownerAddress;
  final String title;
  final String submitLabel;
  final AccountDependent? initialDependent;

  const _DependentRegistrationSheet({
    required this.ownerAddress,
    required this.title,
    required this.submitLabel,
    this.initialDependent,
  });

  @override
  State<_DependentRegistrationSheet> createState() => _DependentRegistrationSheetState();
}

class _DependentRegistrationSheetState extends State<_DependentRegistrationSheet> {
  static const Color _primary = Color(0xFF03466E);
  static const Color _accent = Color(0xFF54AFE6);
  static const Color _bg = Color(0xFFF4FAFD);

  late final List<_DependentDraft> _dependents;
  bool _saving = false;

  static const List<_Option> _relationshipOptions = [
    _Option(value: 'CHILD', label: 'Child'),
    _Option(value: 'SPOUSE', label: 'Spouse'),
    _Option(value: 'PARENT', label: 'Parent'),
    _Option(value: 'SIBLING', label: 'Sibling'),
    _Option(value: 'GRANDCHILD', label: 'Grandchild'),
    _Option(value: 'EXTENDED_FAMILY', label: 'Extended Family'),
    _Option(value: 'OTHER', label: 'Other'),
  ];

  static const List<_Option> _genderOptions = [
    _Option(value: 'MALE', label: 'Male'),
    _Option(value: 'FEMALE', label: 'Female'),
    _Option(value: 'OTHER', label: 'Other'),
  ];

  @override
  void dispose() {
    for (final d in _dependents) {
      d.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    final initial = widget.initialDependent;

    _dependents = [
      initial == null ? _DependentDraft() : _DependentDraft.fromAccountDependent(initial),
    ];
  }

  void _addDependent() {
    setState(() => _dependents.add(_DependentDraft()));
  }

  void _removeDependent(int index) {
    if (_dependents.length <= 1) return;
    final removed = _dependents.removeAt(index);
    removed.dispose();
    setState(() {});
  }

  Future<void> _pickDateOfBirth(_DependentDraft draft) async {
    final now = DateTime.now();
    final initialDate = draft.dateOfBirth ?? DateTime(now.year - 10, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Select Date of Birth',
      fieldLabelText: 'Date of Birth',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: _primary,
                  secondary: _accent,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;

    setState(() {
      draft.dateOfBirth = picked;
    });
  }

  Future<void> _pickLocation(_DependentDraft draft) async {
    final selected = await showDialog<LatLng>(
      context: context,
      builder: (_) => _MapLocationPickerDialog(
        initialLocation: draft.latitude != null && draft.longitude != null
            ? LatLng(draft.latitude!, draft.longitude!)
            : (widget.ownerAddress?.latitude != null && widget.ownerAddress?.longitude != null
                ? LatLng(widget.ownerAddress!.latitude!, widget.ownerAddress!.longitude!)
                : const LatLng(3.1390, 101.6869)),
      ),
    );

    if (selected == null) return;

    setState(() {
      draft.latitude = selected.latitude;
      draft.longitude = selected.longitude;
    });
  }

  Future<void> _openGoogleMaps(double lat, double lng) async {
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _applyOwnerAddress(_DependentDraft draft, bool checked) {
    final owner = widget.ownerAddress;

    if (checked && owner == null) {
      _showMessage('Owner address not available in profile.');
      return;
    }

    if (checked && owner?.hasAddress != true) {
      _showMessage('Owner address not available in profile.');
      return;
    }

    setState(() {
      draft.sameAsOwner = checked;

      if (checked) {
        draft.addressLineCtrl.text = owner!.addressLine;
        draft.cityCtrl.text = owner.city;
        draft.stateCtrl.text = owner.state;
        draft.postalCodeCtrl.text = owner.postalCode;

        if (owner.latitude != null && owner.longitude != null) {
          draft.latitude = owner.latitude;
          draft.longitude = owner.longitude;
        }
      } else {
        draft.addressLineCtrl.clear();
        draft.cityCtrl.clear();
        draft.stateCtrl.clear();
        draft.postalCodeCtrl.clear();
        draft.latitude = null;
        draft.longitude = null;
      }
    });
  }

  Future<void> _save() async {
    final list = <DependentRegistrationPayload>[];

    for (int i = 0; i < _dependents.length; i++) {
      final d = _dependents[i];
      final idx = i + 1;

      final fullName = d.fullNameCtrl.text.trim();
      final icOrPassport = d.icCtrl.text.trim();
      final email = d.emailCtrl.text.trim();
      final phone = d.phoneCtrl.text.trim();
      final addressLine = d.addressLineCtrl.text.trim();
      final city = d.cityCtrl.text.trim();
      final state = d.stateCtrl.text.trim();
      final postalCode = d.postalCodeCtrl.text.trim();

      if (fullName.isEmpty) {
        _showMessage('Dependent #$idx: full name is required.');
        return;
      }

      if (d.relationshipType.isEmpty) {
        _showMessage('Dependent #$idx: please select relationship type.');
        return;
      }

      if (d.gender.isEmpty) {
        _showMessage('Dependent #$idx: please select gender.');
        return;
      }

      if (d.dateOfBirth == null) {
        _showMessage('Dependent #$idx: please select date of birth.');
        return;
      }

      if (email.isNotEmpty && !email.contains('@')) {
        _showMessage('Dependent #$idx: please enter a valid email.');
        return;
      }

      list.add(
        DependentRegistrationPayload(
          fullName: fullName,
          relationshipType: d.relationshipType,
          icOrPassport: icOrPassport,
          email: email,
          phone: phone,
          gender: d.gender,
          dateOfBirth: _formatDateForApi(d.dateOfBirth),
          addressLine: addressLine,
          city: city,
          state: state,
          postalCode: postalCode,
          latitude: d.latitude ?? 0,
          longitude: d.longitude ?? 0,
        ),
      );
    }

    setState(() => _saving = true);

    try {
      if (!mounted) return;
      Navigator.of(context).pop(list);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _formatDateForDisplay(DateTime? date) {
    if (date == null) return 'Select date';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _formatDateForApi(DateTime? date) {
    if (date == null) return '';
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: _primary),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _accent, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Colors.redAccent),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _primary.withOpacity(0.08)),
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
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: _primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: _primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 15.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _gap() => const SizedBox(height: 10);

  @override
  Widget build(BuildContext context) {
    final ownerHasAddress = widget.ownerAddress?.hasAddress == true;

    return Container(
      decoration: const BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 10,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 5,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 19,
                      color: _primary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _dependents.length,
                itemBuilder: (_, index) {
                  final d = _dependents[index];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [_primary, _accent],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(Icons.family_restroom_rounded, color: Colors.white),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Dependent #${index + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 17,
                                  ),
                                ),
                              ),
                              if (_dependents.length > 1)
                                IconButton(
                                  onPressed: () => _removeDependent(index),
                                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        _section(
                          title: 'Basic Details',
                          icon: Icons.badge_rounded,
                          children: [
                            _field(
                              d.fullNameCtrl,
                              'Full Name',
                              icon: Icons.person_rounded,
                              hint: 'Enter dependent full name',
                            ),
                            _gap(),
                            DropdownButtonFormField<String>(
                              value: _safeOptionValue(
                                d.relationshipType,
                                _relationshipOptions,
                                fallback: 'OTHER',
                              ),
                              decoration: _inputDecoration(
                                label: 'Relationship Type',
                                icon: Icons.groups_rounded,
                              ),
                              borderRadius: BorderRadius.circular(18),
                              items: _relationshipOptions
                                  .map(
                                    (item) => DropdownMenuItem<String>(
                                      value: item.value,
                                      child: Text(item.label),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => d.relationshipType = value);
                              },
                            ),
                            _gap(),
                            _field(
                              d.icCtrl,
                              'IC / Passport',
                              icon: Icons.credit_card_rounded,
                              hint: 'Optional',
                            ),
                          ],
                        ),

                        _section(
                          title: 'Personal Information',
                          icon: Icons.info_rounded,
                          children: [
                            DropdownButtonFormField<String>(
                              value: _safeOptionValue(d.gender, _genderOptions, fallback: 'OTHER'),
                              decoration: _inputDecoration(
                                label: 'Gender',
                                icon: Icons.wc_rounded,
                              ),
                              borderRadius: BorderRadius.circular(18),
                              items: _genderOptions
                                  .map(
                                    (item) => DropdownMenuItem<String>(
                                      value: item.value,
                                      child: Text(item.label),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => d.gender = value);
                              },
                            ),
                            _gap(),
                            InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () => _pickDateOfBirth(d),
                              child: InputDecorator(
                                decoration: _inputDecoration(
                                  label: 'Date of Birth',
                                  icon: Icons.calendar_month_rounded,
                                  hint: 'Select date',
                                ),
                                child: Text(
                                  _formatDateForDisplay(d.dateOfBirth),
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: d.dateOfBirth == null ? Colors.grey.shade600 : Colors.black87,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        _section(
                          title: 'Contact Details',
                          icon: Icons.call_rounded,
                          children: [
                            _field(
                              d.phoneCtrl,
                              'Phone',
                              icon: Icons.phone_rounded,
                              keyboardType: TextInputType.phone,
                              hint: 'Optional',
                            ),
                            _gap(),
                            _field(
                              d.emailCtrl,
                              'Email',
                              icon: Icons.email_rounded,
                              keyboardType: TextInputType.emailAddress,
                              hint: 'Optional',
                            ),
                          ],
                        ),

                        _section(
                          title: 'Address',
                          icon: Icons.home_rounded,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: ownerHasAddress ? _accent.withOpacity(0.10) : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: ownerHasAddress ? _accent.withOpacity(0.35) : Colors.grey.shade300,
                                ),
                              ),
                              child: CheckboxListTile(
                                value: d.sameAsOwner,
                                onChanged: ownerHasAddress ? (v) => _applyOwnerAddress(d, v == true) : null,
                                activeColor: _primary,
                                controlAffinity: ListTileControlAffinity.leading,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                title: const Text(
                                  'Same as account owner address',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                                subtitle: Text(
                                  ownerHasAddress
                                      ? '${widget.ownerAddress!.addressLine}, ${widget.ownerAddress!.city}, ${widget.ownerAddress!.state}, ${widget.ownerAddress!.postalCode}'
                                      : 'Owner address not available in profile',
                                ),
                              ),
                            ),
                            _gap(),
                            _field(
                              d.addressLineCtrl,
                              'Address Line',
                              icon: Icons.location_on_rounded,
                              maxLines: 2,
                              hint: 'Optional',
                            ),
                            _gap(),
                            _field(
                              d.cityCtrl,
                              'City',
                              icon: Icons.location_city_rounded,
                              hint: 'Optional',
                            ),
                            _gap(),
                            _field(
                              d.stateCtrl,
                              'State',
                              icon: Icons.map_rounded,
                              hint: 'Optional',
                            ),
                            _gap(),
                            _field(
                              d.postalCodeCtrl,
                              'Postal Code',
                              icon: Icons.markunread_mailbox_rounded,
                              keyboardType: TextInputType.number,
                              hint: 'Optional',
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _pickLocation(d),
                                    icon: const Icon(Icons.map_outlined),
                                    label: Text(
                                      d.latitude == null || d.longitude == null
                                          ? 'Pick Location'
                                          : 'Update Location',
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: _primary,
                                      side: const BorderSide(color: _primary),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      padding: const EdgeInsets.symmetric(vertical: 13),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (d.latitude != null && d.longitude != null)
                                  IconButton(
                                    tooltip: 'Open in Google Maps',
                                    onPressed: () => _openGoogleMaps(d.latitude!, d.longitude!),
                                    icon: const Icon(Icons.open_in_new_rounded, color: _primary),
                                  ),
                              ],
                            ),
                            if (d.latitude != null && d.longitude != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'Lat: ${d.latitude!.toStringAsFixed(6)} | Lng: ${d.longitude!.toStringAsFixed(6)}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                if (widget.initialDependent == null) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saving ? null : _addDependent,
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      label: const Text('Add Another'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _primary,
                        side: const BorderSide(color: _primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade400,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _saving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            widget.submitLabel,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    required IconData icon,
    TextInputType? keyboardType,
    String? hint,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: _inputDecoration(
        label: label,
        icon: icon,
        hint: hint,
      ),
    );
  }
}

class _DependentDraft {
  final fullNameCtrl = TextEditingController();
  final icCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final addressLineCtrl = TextEditingController();
  final cityCtrl = TextEditingController();
  final stateCtrl = TextEditingController();
  final postalCodeCtrl = TextEditingController();

  String relationshipType = 'CHILD';
  String gender = 'MALE';
  DateTime? dateOfBirth;

  bool sameAsOwner = false;
  double? latitude;
  double? longitude;

  _DependentDraft();

  factory _DependentDraft.fromAccountDependent(AccountDependent dependent) {
    final draft = _DependentDraft();

    draft.fullNameCtrl.text = dependent.fullName;
    draft.icCtrl.text = dependent.icOrPassport;
    draft.emailCtrl.text = dependent.email;
    draft.phoneCtrl.text = dependent.phone;
    draft.addressLineCtrl.text = dependent.addressLine;
    draft.cityCtrl.text = dependent.city;
    draft.stateCtrl.text = dependent.state;
    draft.postalCodeCtrl.text = dependent.postalCode;

    draft.relationshipType = _normalizeRelationship(dependent.relationshipType);
    draft.gender = _normalizeGender(dependent.gender);
    draft.dateOfBirth = _parseDate(dependent.dateOfBirth);

    draft.latitude = dependent.latitude;
    draft.longitude = dependent.longitude;

    return draft;
  }

  void dispose() {
    fullNameCtrl.dispose();
    icCtrl.dispose();
    emailCtrl.dispose();
    phoneCtrl.dispose();
    addressLineCtrl.dispose();
    cityCtrl.dispose();
    stateCtrl.dispose();
    postalCodeCtrl.dispose();
  }
}

String _normalizeRelationship(String value) {
  var normalized = value.trim().toUpperCase().replaceAll(' ', '_');

  if (normalized == 'DEPENDENT') {
    normalized = 'OTHER';
  }

  if (normalized == 'GUARDIAN') {
    normalized = 'OTHER';
  }

  if (normalized == 'EXTENDED') {
    normalized = 'EXTENDED_FAMILY';
  }

  const allowed = {
    'SELF',
    'CHILD',
    'SPOUSE',
    'PARENT',
    'SIBLING',
    'GRANDCHILD',
    'EXTENDED_FAMILY',
    'OTHER',
  };

  if (allowed.contains(normalized)) return normalized;
  return 'OTHER';
}

String _normalizeGender(String value) {
  final normalized = value.trim().toUpperCase().replaceAll(' ', '_');

  const allowed = {
    'MALE',
    'FEMALE',
    'OTHER',
  };

  if (allowed.contains(normalized)) return normalized;
  return 'OTHER';
}

DateTime? _parseDate(String value) {
  final text = value.trim();
  if (text.isEmpty) return null;
  return DateTime.tryParse(text);
}

class _Option {
  final String value;
  final String label;

  const _Option({
    required this.value,
    required this.label,
  });
}

String _safeOptionValue(
  String value,
  List<_Option> options, {
  required String fallback,
}) {
  final normalized = value.trim().toUpperCase().replaceAll(' ', '_');

  final matches = options.where((item) => item.value == normalized).toList();

  if (matches.length == 1) {
    return normalized;
  }

  return fallback;
}

class _MapLocationPickerDialog extends StatefulWidget {
  final LatLng initialLocation;

  const _MapLocationPickerDialog({required this.initialLocation});

  @override
  State<_MapLocationPickerDialog> createState() => _MapLocationPickerDialogState();
}

class _MapLocationPickerDialogState extends State<_MapLocationPickerDialog> {
  static const Color _primary = Color(0xFF03466E);
  static const Color _accent = Color(0xFF54AFE6);

  late LatLng _picked = widget.initialLocation;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Select Location',
        style: TextStyle(fontWeight: FontWeight.w800, color: _primary),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      content: SizedBox(
        width: 420,
        height: 320,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: GoogleMap(
            initialCameraPosition: CameraPosition(target: _picked, zoom: 15),
            markers: {
              Marker(
                markerId: const MarkerId('picked'),
                position: _picked,
              ),
            },
            onTap: (latLng) => setState(() => _picked = latLng),
            myLocationButtonEnabled: true,
            zoomControlsEnabled: true,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.of(context).pop(_picked),
          child: const Text('Use Location'),
        ),
      ],
    );
  }
}