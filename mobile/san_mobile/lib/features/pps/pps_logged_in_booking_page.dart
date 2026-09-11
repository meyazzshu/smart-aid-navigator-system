import 'package:flutter/material.dart';

import 'pps_slot_booking_api.dart';

class PpsLoggedInBookingPage extends StatefulWidget {
  final int shelterId;
  final String shelterName;
  final int? capacity;
  final int? currentOccupancy;
  final String availabilityLabel;
  final Color availabilityColor;
  final bool isFull;

  const PpsLoggedInBookingPage({
    super.key,
    required this.shelterId,
    required this.shelterName,
    required this.capacity,
    required this.currentOccupancy,
    required this.availabilityLabel,
    required this.availabilityColor,
    required this.isFull,
  });

  @override
  State<PpsLoggedInBookingPage> createState() => _PpsLoggedInBookingPageState();
}

class _PpsLoggedInBookingPageState extends State<PpsLoggedInBookingPage> {
  final _api = PpsSlotBookingApi();

  int _babiesMale = 0;
  int _babiesFemale = 0;
  int _kidsMale = 0;
  int _kidsFemale = 0;
  int _adultMale = 0;
  int _adultFemale = 0;
  bool _submitting = false;

  int get _totalPeople =>
      _babiesMale + _babiesFemale + _kidsMale + _kidsFemale + _adultMale + _adultFemale;

  void _increment(VoidCallback setter) => setState(setter);

  void _decrement(int value, ValueSetter<int> onChanged) {
    if (value <= 0) return;
    setState(() => onChanged(value - 1));
  }

  Future<void> _submit() async {
    if (widget.isFull) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This PPS is FULL. Please select another shelter.')),
      );
      return;
    }
    if (_totalPeople <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least 1 person')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final res = await _api.submitMyRequest(
        shelterId: widget.shelterId,
        babiesMale: _babiesMale,
        babiesFemale: _babiesFemale,
        kidsMale: _kidsMale,
        kidsFemale: _kidsFemale,
        adultMale: _adultMale,
        adultFemale: _adultFemale,
        totalPeople: _totalPeople,
      );

      if (!res.ok) {
        throw Exception(res.error ?? res.message ?? 'Request failed');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'PPS booking submitted. You can select your account dependents in My PPS Bookings.',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${_cleanError(e)}')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _counterTile({
    required String label,
    required IconData icon,
    required int value,
    required VoidCallback onAdd,
    required VoidCallback onRemove,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: colorScheme.secondary),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
            IconButton(onPressed: onRemove, icon: const Icon(Icons.remove_circle_outline)),
            Text('$value', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            IconButton(onPressed: onAdd, icon: const Icon(Icons.add_circle_outline)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final capacity = widget.capacity;
    final occupancy = widget.currentOccupancy;

    return Scaffold(
      appBar: AppBar(title: const Text('PPS Slot Booking')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(widget.shelterName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: widget.availabilityColor.withValues(alpha:0.15),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: widget.availabilityColor),
                ),
                child: Text(
                  widget.availabilityLabel,
                  style: TextStyle(color: widget.availabilityColor, fontWeight: FontWeight.w700),
                ),
              ),
              const Spacer(),
              Text('Capacity: ${capacity ?? '-'}', style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 8),
              Text('Occupied: ${occupancy ?? '-'}', style: const TextStyle(fontSize: 12)),
            ],
          ),
          const SizedBox(height: 16),
          const Text('People Count', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _counterTile(
            label: 'Babies (Male)',
            icon: Icons.baby_changing_station,
            value: _babiesMale,
            onAdd: () => _increment(() => _babiesMale++),
            onRemove: () => _decrement(_babiesMale, (v) => _babiesMale = v),
          ),
          _counterTile(
            label: 'Babies (Female)',
            icon: Icons.baby_changing_station,
            value: _babiesFemale,
            onAdd: () => _increment(() => _babiesFemale++),
            onRemove: () => _decrement(_babiesFemale, (v) => _babiesFemale = v),
          ),
          _counterTile(
            label: 'Kids (Male)',
            icon: Icons.child_care,
            value: _kidsMale,
            onAdd: () => _increment(() => _kidsMale++),
            onRemove: () => _decrement(_kidsMale, (v) => _kidsMale = v),
          ),
          _counterTile(
            label: 'Kids (Female)',
            icon: Icons.child_care,
            value: _kidsFemale,
            onAdd: () => _increment(() => _kidsFemale++),
            onRemove: () => _decrement(_kidsFemale, (v) => _kidsFemale = v),
          ),
          _counterTile(
            label: 'Adult (Male)',
            icon: Icons.person,
            value: _adultMale,
            onAdd: () => _increment(() => _adultMale++),
            onRemove: () => _decrement(_adultMale, (v) => _adultMale = v),
          ),
          _counterTile(
            label: 'Adult (Female)',
            icon: Icons.person,
            value: _adultFemale,
            onAdd: () => _increment(() => _adultFemale++),
            onRemove: () => _decrement(_adultFemale, (v) => _adultFemale = v),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Total:', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(width: 6),
              Text('$_totalPeople', style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.groups_outlined),
              title: const Text('Dependent Assignment'),
              subtitle: const Text(
                'Save dependents in My tab first, then assign them to this booking from My PPS Bookings.',
              ),
            ),
          ),
          if (widget.isFull)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'This PPS is FULL. You cannot submit a request.',
                style: TextStyle(color: colorScheme.error, fontWeight: FontWeight.w600),
              ),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_submitting || widget.isFull) ? null : _submit,
              child: _submitting
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(widget.isFull ? 'PPS FULL' : 'Submit Booking'),
            ),
          ),
        ],
      ),
    );
  }

  String _cleanError(Object e) => e.toString().replaceFirst('Exception: ', '');
}
