import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/auth_controller.dart';
import '../../core/app_theme.dart';
import 'account_profile_api.dart';
import 'google_address_picker_page.dart';

class AccountProfilePage extends ConsumerStatefulWidget {
  final bool startInEditMode;

  const AccountProfilePage({
    super.key,
    this.startInEditMode = false,
  });

  @override
  ConsumerState<AccountProfilePage> createState() => _AccountProfilePageState();
}

class _AccountProfilePageState extends ConsumerState<AccountProfilePage> {
  final _api = AccountProfileApi();
  final _formKey = GlobalKey<FormState>();

  final _fullNameCtrl = TextEditingController();
  final _icCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _postalCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _editing = false;
  String? _error;

  AccountProfile? _profile;
  AccountProfileLookups? _lookups;

  String _email = '';
  String _role = '';
  String _gender = '';
  String _state = '';

  bool get _isNgo => _role == 'NGO_STAFF' || _role == 'ADMIN';

  @override
  void initState() {
    super.initState();
    _editing = widget.startInEditMode;
    _load();
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _icCtrl.dispose();
    _phoneCtrl.dispose();
    _dobCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _postalCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _api.getMyProfile(),
        _api.getLookups(),
      ]);

      final profile = results[0] as AccountProfile;
      final lookups = results[1] as AccountProfileLookups;

      if (!mounted) return;

      _applyProfile(profile);

      setState(() {
        _profile = profile;
        _lookups = lookups;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyProfile(AccountProfile profile) {
    _fullNameCtrl.text = profile.fullName;
    _icCtrl.text = profile.icOrPassport;
    _phoneCtrl.text = profile.phone;
    _dobCtrl.text = profile.dateOfBirth;
    _addressCtrl.text = profile.addressLine;
    _cityCtrl.text = profile.city;
    _postalCtrl.text = profile.postalCode;

    _email = profile.email;
    _role = profile.role;
    _gender = profile.gender;
    _state = profile.state;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      await _api.updateMyProfile(
        fullName: _fullNameCtrl.text.trim(),
        icOrPassport: _icCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        gender: _gender.trim(),
        dateOfBirth: _dobCtrl.text.trim(),
        addressLine: _addressCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        state: _state.trim(),
        postalCode: _postalCtrl.text.trim(),
      );

      await _refreshAuthStateAfterProfileSave();

      if (!mounted) return;

      setState(() => _editing = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully.')),
      );

      await _load();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final current = DateTime.tryParse(_dobCtrl.text.trim());

    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
    );

    if (picked == null) return;

    final value =
        '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';

    setState(() => _dobCtrl.text = value);
  }

  Future<void> _pickAddressFromGoogle() async {
    final currentText = [
      _addressCtrl.text.trim(),
      _cityCtrl.text.trim(),
      _state.trim(),
      _postalCtrl.text.trim(),
    ].where((x) => x.isNotEmpty).join(', ');

    final picked = await Navigator.of(context).push<PickedGoogleAddress>(
      MaterialPageRoute(
        builder: (_) => GoogleAddressPickerPage(
          initialQuery: currentText,
        ),
      ),
    );

    if (picked == null) return;

    setState(() {
      _addressCtrl.text = picked.addressLine;
      _cityCtrl.text = picked.city;
      _state = picked.state;
      _postalCtrl.text = picked.postalCode;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Address filled from Google Maps. Please review before saving.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accentColor = _isNgo ? colorScheme.primary : colorScheme.secondary;

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFC),
      appBar: AppBar(
        title: Text(_editing ? 'Edit Profile' : 'Account Profile'),
        actions: [
          if (!_loading && _error == null)
            IconButton(
              icon: Icon(_editing ? Icons.close : Icons.edit_outlined),
              tooltip: _editing ? 'Cancel' : 'Edit',
              onPressed: _saving
                  ? null
                  : () {
                      if (_editing && _profile != null) {
                        _applyProfile(_profile!);
                      }
                      setState(() => _editing = !_editing);
                  },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ProfileErrorView(message: _error!, onRetry: _load)
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    children: [
                      _ProfileHeroCard(
                        profile: _profile,
                        fullName: _fullNameCtrl.text,
                        email: _email,
                        role: _role,
                        accentColor: accentColor,
                        isNgo: _isNgo,
                      ),
                      const SizedBox(height: 14),

                      if (!_editing) ...[
                        _ProfileCompletionCard(profile: _profile),
                        const SizedBox(height: 14),
                        _ReadOnlySection(
                          title: 'Personal Details',
                          icon: Icons.badge_outlined,
                          items: [
                            _InfoRowData('Full Name', _fullNameCtrl.text, Icons.person_outline),
                            _InfoRowData('IC / Passport', _icCtrl.text, Icons.credit_card_outlined),
                            _InfoRowData('Gender', _displayGender(_gender), Icons.wc_outlined),
                            _InfoRowData('Date of Birth', _dobCtrl.text, Icons.cake_outlined),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _ReadOnlySection(
                          title: 'Contact Details',
                          icon: Icons.call_outlined,
                          items: [
                            _InfoRowData('Email', _email, Icons.email_outlined),
                            _InfoRowData('Phone', _phoneCtrl.text, Icons.phone_outlined),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _ReadOnlySection(
                          title: 'Address',
                          icon: Icons.home_outlined,
                          items: [
                            _InfoRowData('Address Line', _addressCtrl.text, Icons.location_on_outlined),
                            _InfoRowData('City', _cityCtrl.text, Icons.location_city_outlined),
                            _InfoRowData('State', _state, Icons.map_outlined),
                            _InfoRowData('Postal Code', _postalCtrl.text, Icons.markunread_mailbox_outlined),
                          ],
                        ),
                      ] else ...[
                        _EditSection(
                          title: 'Personal Details',
                          subtitle: 'Keep your identity details accurate for aid records.',
                          icon: Icons.badge_outlined,
                          children: [
                            _field(
                              'Full Name',
                              _fullNameCtrl,
                              icon: Icons.person_outline,
                              validator: _required,
                            ),
                            _field(
                              'IC / Passport',
                              _icCtrl,
                              icon: Icons.credit_card_outlined,
                              textCapitalization: TextCapitalization.characters,
                            ),
                            _dropdownField(
                              label: 'Gender',
                              icon: Icons.wc_outlined,
                              value: _gender.isEmpty ? null : _gender,
                              items: _lookups?.genders
                                      .map(
                                        (g) => DropdownMenuItem(
                                          value: g.value,
                                          child: Text(g.label),
                                        ),
                                      )
                                      .toList() ??
                                  const [],
                              onChanged: (value) {
                                setState(() => _gender = value ?? '');
                              },
                            ),
                            _dateField(),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _EditSection(
                          title: 'Contact Details',
                          subtitle: 'Used by NGOs and shelter teams for follow-up.',
                          icon: Icons.call_outlined,
                          children: [
                            _readonlyField('Email', _email, Icons.email_outlined),
                            _field(
                              'Phone',
                              _phoneCtrl,
                              icon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        _EditSection(
                          title: 'Address',
                          subtitle: 'Helps emergency teams understand your nearby area.',
                          icon: Icons.home_outlined,
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _saving ? null : _pickAddressFromGoogle,
                                icon: const Icon(Icons.map_outlined),
                                label: const Text('Search Address with Google Maps'),
                              ),
                            ),

                            const SizedBox(height: 12),

                            _field(
                              'Address Line',
                              _addressCtrl,
                              icon: Icons.location_on_outlined,
                              maxLines: 2,
                            ),

                            _cityAutocomplete(),

                            _dropdownField(
                              label: 'State',
                              icon: Icons.map_outlined,
                              value: _state.isEmpty ? null : _state,
                              items: (_lookups?.states ?? const [])
                                  .map(
                                    (s) => DropdownMenuItem(
                                      value: s,
                                      child: Text(s),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setState(() => _state = value ?? '');
                              },
                            ),

                            _field(
                              'Postal Code',
                              _postalCtrl,
                              icon: Icons.markunread_mailbox_outlined,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
                            ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(_saving ? 'Saving...' : 'Save Changes'),
                      ),
                    ),
                ],
          ],
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    IconData? icon,
    bool enabled = true,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.words,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        enabled: enabled && !_saving,
        keyboardType: keyboardType,
        validator: validator,
        inputFormatters: inputFormatters,
        textCapitalization: textCapitalization,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon == null ? null : Icon(icon),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _readonlyField(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
        child: Text(value.isEmpty ? 'N/A' : value),
      ),
    );
  }

  Widget _dropdownField({
    required String label,
    required IconData icon,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: items.any((x) => x.value == value) ? value : null,
        items: items,
        onChanged: _saving ? null : onChanged,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _dateField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: _dobCtrl,
        readOnly: true,
        enabled: !_saving,
        decoration: InputDecoration(
          labelText: 'Date of Birth',
          prefixIcon: const Icon(Icons.cake_outlined),
          suffixIcon: IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: _saving ? null : _pickDateOfBirth,
          ),
          border: const OutlineInputBorder(),
        ),
        onTap: _saving ? null : _pickDateOfBirth,
      ),
    );
  }

  Widget _cityAutocomplete() {
    final cities = _lookups?.cities ?? const <String>[];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Autocomplete<String>(
        initialValue: TextEditingValue(text: _cityCtrl.text),
        optionsBuilder: (textEditingValue) {
          final query = textEditingValue.text.trim().toLowerCase();
          if (query.isEmpty) return cities.take(8);
          return cities
              .where((city) => city.toLowerCase().contains(query))
              .take(8);
        },
        onSelected: (value) {
          _cityCtrl.text = value;
        },
        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
          if (controller.text != _cityCtrl.text) {
            controller.text = _cityCtrl.text;
            controller.selection = TextSelection.fromPosition(
              TextPosition(offset: controller.text.length),
            );
          }

          return TextFormField(
            controller: controller,
            focusNode: focusNode,
            enabled: !_saving,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'City',
              prefixIcon: Icon(Icons.location_city_outlined),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              _cityCtrl.text = value;
            },
          );
        },
      ),
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    return null;
  }

  String _displayGender(String gender) {
    switch (gender.toUpperCase()) {
      case 'MALE':
        return 'Male';
      case 'FEMALE':
        return 'Female';
      case 'OTHER':
        return 'Other';
      default:
        return gender;
    }
  }

  Future<void> _refreshAuthStateAfterProfileSave() {
    return ref.read(authControllerProvider.notifier).restoreSession();
  }
}

class _ProfileHeroCard extends StatelessWidget {
  final AccountProfile? profile;
  final String fullName;
  final String email;
  final String role;
  final Color accentColor;
  final bool isNgo;

  const _ProfileHeroCard({
    required this.profile,
    required this.fullName,
    required this.email,
    required this.role,
    required this.accentColor,
    required this.isNgo,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final organization = profile?.organization;
    final orgName = organization?['ngo_name']?.toString() ??
        organization?['shelter_name']?.toString() ??
        '';
    final displayName = fullName.trim().isEmpty ? 'User' : fullName.trim();

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.darkAzure, AppColors.azure],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: Colors.white.withOpacity(0.2),
                child: Text(
                  profile?.initials ?? 'U',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email.isEmpty ? 'No email available' : email,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.82),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroPill(
                icon: isNgo ? Icons.business_center_outlined : Icons.person_outline,
                text: profile?.displayRole ?? role,
              ),
              if (orgName.isNotEmpty)
                _HeroPill(
                  icon: Icons.apartment_outlined,
                  text: orgName,
                ),
              _HeroPill(
                icon: profile?.isComplete == true
                    ? Icons.verified_outlined
                    : Icons.error_outline,
                text: profile?.isComplete == true ? 'Profile Complete' : 'Profile Incomplete',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Keep your personal details updated so Smart Aid Navigator can contact and verify your aid-related records properly.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.78),
              height: 1.45,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _HeroPill({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 15),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCompletionCard extends StatelessWidget {
  final AccountProfile? profile;

  const _ProfileCompletionCard({
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    final percent = profile?.completionPercent ?? 0;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            SizedBox(
              width: 58,
              height: 58,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: percent / 100,
                    strokeWidth: 6,
                  ),
                  Text(
                    '$percent%',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Profile Completion',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    percent >= 90
                        ? 'Your profile looks complete and ready for aid-related services.'
                        : 'Add missing details to help NGOs and shelter teams verify your records faster.',
                    style: TextStyle(
                      color: colorScheme.onSurface.withOpacity(0.62),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> children;

  const _EditSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(title: title, subtitle: subtitle, icon: icon),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ReadOnlySection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<_InfoRowData> items;

  const _ReadOnlySection({
    required this.title,
    required this.icon,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            _SectionHeader(
              title: title,
              subtitle: 'Stored in your personal profile record',
              icon: icon,
            ),
            const SizedBox(height: 12),
            ...items.map((item) => _InfoRow(item: item)),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: colorScheme.primary, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: colorScheme.onSurface.withOpacity(0.56),
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRowData {
  final String label;
  final String value;
  final IconData icon;

  const _InfoRowData(this.label, this.value, this.icon);
}

class _InfoRow extends StatelessWidget {
  final _InfoRowData item;

  const _InfoRow({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final value = item.value.trim().isEmpty ? 'Not provided' : item.value.trim();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outline.withOpacity(0.08),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            item.icon,
            size: 18,
            color: colorScheme.primary.withOpacity(0.8),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item.label,
              style: TextStyle(
                color: colorScheme.onSurface.withOpacity(0.58),
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: value == 'Not provided'
                    ? FontWeight.w500
                    : FontWeight.w800,
                color: value == 'Not provided'
                    ? colorScheme.onSurface.withOpacity(0.36)
                    : colorScheme.onSurface,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ProfileErrorView({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 46, color: colorScheme.error),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorScheme.error),
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}