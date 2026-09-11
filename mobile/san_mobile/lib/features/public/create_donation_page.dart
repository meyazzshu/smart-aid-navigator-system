import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/app_theme.dart';
import '../../core/dio_client.dart';
import 'payment_page.dart';


class CreateDonationPage extends StatefulWidget {
  final String initialType;
  const CreateDonationPage({super.key, this.initialType = 'ITEM'});

  @override
  State<CreateDonationPage> createState() => _CreateDonationPageState();
}

class _CreateDonationPageState extends State<CreateDonationPage>
    with SingleTickerProviderStateMixin {
  final Dio _dio = DioClient.create();

  late String _donationType;

  String _recipientType = 'NGO';
  int? _selectedNgoId;
  int? _selectedShelterId;

  Position? _currentPosition;

  String _remarks = '';

  final _amountCtrl = TextEditingController(text: '10.00');
  final _remarksCtrl = TextEditingController();

  List<Map<String, dynamic>> _ngos = [];
  List<Map<String, dynamic>> _shelters = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _needs = [];

  int? _selectedCategoryId;
  int? _selectedItemId;
  final _qtyCtrl = TextEditingController(text: '1');

  final List<_CartItem> _cart = [];

  bool _loading = true;
  bool _submitting = false;
  bool _dropoffRequired = true;
  bool _loadingNeeds = false;

  late TabController _tabController;

  static const _quickAmounts = [10.0, 20.0, 50.0, 100.0, 200.0, 500.0];

  @override
  void initState() {
    super.initState();
    _donationType = widget.initialType;
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: _donationType == 'MONEY' ? 1 : 0,
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _donationType = _tabController.index == 0 ? 'ITEM' : 'MONEY');
      }
    });
    _initLoad();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _qtyCtrl.dispose();
    _remarksCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initLoad() async {
    setState(() => _loading = true);

    try {
      // 1. Load NGO list
      final ngosRes = await _dio.get('/map/ngos');
      final ngosData = (ngosRes.data as Map).cast<String, dynamic>();
      _ngos = (ngosData['ngos'] as List)
          .cast<dynamic>()
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();

      // 2. Load Shelter list
      final sheltersRes = await _dio.get('/map/shelters');
      final sheltersData = (sheltersRes.data as Map).cast<String, dynamic>();
      _shelters = (sheltersData['shelters'] as List)
          .cast<dynamic>()
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();

      // 3. Try get user's current location for distance display
      try {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();

        if (serviceEnabled) {
          var permission = await Geolocator.checkPermission();

          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }

          if (permission == LocationPermission.always ||
              permission == LocationPermission.whileInUse) {
            _currentPosition = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high,
            );
          }
        }
      } catch (_) {
        _currentPosition = null;
      }

      if (_currentPosition != null) {
        _ngos.sort(
          (a, b) => _distanceKm(a).compareTo(_distanceKm(b)),
        );

        _shelters.sort(
          (a, b) => _distanceKm(a).compareTo(_distanceKm(b)),
        );
      }

      // 4. Load categories
      final catRes = await _dio.get('/categories');
      final catData = (catRes.data as Map).cast<String, dynamic>();
      _categories = (catData['categories'] as List)
          .cast<dynamic>()
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();

      // 5. Load items
      await _loadItems();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Load error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadItems() async {
    final q = <String, dynamic>{};
    if (_selectedCategoryId != null) q['category_id'] = _selectedCategoryId;

    final res = await _dio.get('/items', queryParameters: q);
    final data = (res.data as Map).cast<String, dynamic>();
    _items = (data['items'] as List)
        .cast<dynamic>()
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();

    if (_selectedItemId != null &&
        !_items.any(
            (x) => (x['item_id'] as num).toInt() == _selectedItemId)) {
      _selectedItemId = null;
    }
    setState(() {});
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  String _distanceLabel(Map<String, dynamic> place) {
    final current = _currentPosition;
    final lat = _toDouble(place['latitude']);
    final lng = _toDouble(place['longitude']);

    if (current == null || lat == null || lng == null) {
      return 'distance unavailable';
    }

    final meters = Geolocator.distanceBetween(
      current.latitude,
      current.longitude,
      lat,
      lng,
    );

    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  double _distanceKm(Map<String, dynamic> place) {
    final current = _currentPosition;

    final lat = _toDouble(place['latitude']);
    final lng = _toDouble(place['longitude']);

    if (current == null || lat == null || lng == null) {
      return 999999;
    }

    final meters = Geolocator.distanceBetween(
      current.latitude,
      current.longitude,
      lat,
      lng,
    );

    return meters / 1000;
  }

  Future<void> _loadNeeds() async {
    final ownerId = _recipientType == 'NGO'
        ? _selectedNgoId
        : _selectedShelterId;

    if (ownerId == null || _donationType != 'ITEM') {
      setState(() => _needs = []);
      return;
    }

    setState(() => _loadingNeeds = true);

    try {
      final res = await _dio.get(
        '/map/inventory-needs',
        queryParameters: {
          'owner_type': _recipientType,
          'owner_id': ownerId,
        },
      );

      final data = (res.data as Map).cast<String, dynamic>();

      if (data['ok'] == true) {
        _needs = (data['needs'] as List)
            .cast<dynamic>()
            .map((e) => (e as Map).cast<String, dynamic>())
            .toList();
      }
    } catch (e) {
      _needs = [];
    } finally {
      if (mounted) {
        setState(() => _loadingNeeds = false);
      }
    }
  }

  void _addToCart() {
    final itemId = _selectedItemId;
    final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 0;
    if (itemId == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select item and quantity')));
      return;
    }

    final item = _items.firstWhere(
        (x) => (x['item_id'] as num).toInt() == itemId);
    final name = item['item_name']?.toString() ?? '';
    final unit = item['unit']?.toString() ?? 'unit';

    final idx = _cart.indexWhere((c) => c.itemId == itemId);
    if (idx >= 0) {
      _cart[idx] = _cart[idx].copyWith(quantity: _cart[idx].quantity + qty);
    } else {
      _cart.add(_CartItem(
          itemId: itemId, itemName: name, unit: unit, quantity: qty));
    }
    setState(() {});
  }

  void _removeFromCart(int itemId) {
    _cart.removeWhere((c) => c.itemId == itemId);
    setState(() {});
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final selectedRecipientId =
      _recipientType == 'NGO' ? _selectedNgoId : _selectedShelterId;

      if (selectedRecipientId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select NGO or shelter recipient')),
        );
        return;
      }

      if (_donationType == 'ITEM' && _cart.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Add at least 1 item')));
        return;
      }

      if (_donationType == 'MONEY') {
        final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
        if (amount <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Enter a valid amount')));
          return;
        }
      }

      final createRes = await _dio.post('/donations', data: {
        'ngo_id': _recipientType == 'NGO' ? _selectedNgoId : null,
        'shelter_id': _recipientType == 'SHELTER' ? _selectedShelterId : null,
        'donation_type': _donationType,
        'dropoff_required':
            (_donationType == 'ITEM' && _dropoffRequired) ? 1 : 0,
        'remarks': _remarks.trim(),
      });
      final createData = (createRes.data as Map).cast<String, dynamic>();
      if (createData['ok'] != true) {
        throw Exception(createData['error'] ?? 'Create donation failed');
      }

      final donationId = (createData['donation_id'] as num).toInt();

      if (_donationType == 'ITEM') {
        for (final c in _cart) {
          final res = await _dio.post('/donations/$donationId/items', data: {
            'item_id': c.itemId,
            'quantity': c.quantity,
          });
          final data = (res.data as Map).cast<String, dynamic>();
          if (data['ok'] != true) {
            throw Exception(data['error'] ?? 'Add item failed');
          }
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Donation #$donationId created!')));
        Navigator.of(context).pop();
        return;
      }

      if (_donationType == 'MONEY') {
        final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
        if (!mounted) return;
        final paid = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => PaymentPage(
              donationId: donationId,
              amount: amount,
              currency: 'MYR',
            ),
          ),
        );

        if (!mounted) return;

        if (paid == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Donation #$donationId completed. Thank you!')),
          );
        }

        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Submit error: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Create Donation')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Create Donation')),
      body: Column(
        children: [
          // Type selector tabs
          Container(
            color: AppColors.darkAzure,
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              tabs: const [
                Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Donate Items'),
                Tab(icon: Icon(Icons.account_balance_wallet_outlined), text: 'Donate Money'),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // NGO picker
                _buildRecipientPicker(colorScheme),
                const SizedBox(height: 14),
                // Remarks
                _buildRemarksField(),
                const SizedBox(height: 14),
                // Type-specific section
                if (_donationType == 'MONEY') _moneySection(colorScheme),
                if (_donationType == 'ITEM') _itemSection(colorScheme),
                const SizedBox(height: 20),
                // Submit
                _buildSubmitButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipientPicker(ColorScheme colorScheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.place_outlined, color: colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Donate Recipient',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            SegmentedButton<String>(
              segments: const [
                ButtonSegment<String>(
                  value: 'NGO',
                  label: Text('NGO'),
                  icon: Icon(Icons.business_outlined),
                ),
                ButtonSegment<String>(
                  value: 'SHELTER',
                  label: Text('Shelter'),
                  icon: Icon(Icons.home_work_outlined),
                ),
              ],
              selected: {_recipientType},
              onSelectionChanged: (value) {
                setState(() {
                  _recipientType = value.first;
                  _selectedNgoId = null;
                  _selectedShelterId = null;
                  _needs = [];
                });
              },
            ),

            const SizedBox(height: 12),

            if (_recipientType == 'NGO')
              DropdownButtonFormField<int>(
                isExpanded: true,
                value: _selectedNgoId,
                decoration: const InputDecoration(
                  labelText: 'Select NGO',
                  prefixIcon: Icon(Icons.business_outlined),
                ),
                items: _ngos.map((n) {
                  final id = (n['ngo_id'] as num).toInt();
                  final name = n['ngo_name']?.toString() ?? 'NGO';
                  final distance = _distanceLabel(n);

                  return DropdownMenuItem<int>(
                    value: id,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          distance,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (v) async {
                  setState(() => _selectedNgoId = v);
                  await _loadNeeds();
                },
              )
            else
              DropdownButtonFormField<int>(
                isExpanded: true,
                value: _selectedShelterId,
                decoration: const InputDecoration(
                  labelText: 'Select Shelter',
                  prefixIcon: Icon(Icons.home_work_outlined),
                ),
                items: _shelters.map((s) {
                  final id = (s['shelter_id'] as num).toInt();
                  final name = s['shelter_name']?.toString() ?? 'Shelter';
                  final distance = _distanceLabel(s);

                  return DropdownMenuItem<int>(
                    value: id,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          distance,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (v) async {
                  setState(() => _selectedShelterId = v);
                  await _loadNeeds();
                },
              ),

            if (_donationType == 'ITEM') ...[
              const SizedBox(height: 12),
              _buildNeedsCard(colorScheme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNeedsCard(ColorScheme colorScheme) {
    final hasSelectedRecipient =
        _recipientType == 'NGO' ? _selectedNgoId != null : _selectedShelterId != null;

    if (!hasSelectedRecipient) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha:0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.primary.withValues(alpha:0.15)),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 18, color: colorScheme.primary),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Select a recipient to view their most needed items.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    if (_loadingNeeds) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha:0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Checking inventory needs...',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            LinearProgressIndicator(),
          ],
        ),
      );
    }

    final outOfStock = _needs
        .where((n) => n['stock_status']?.toString() == 'OUT_OF_STOCK')
        .toList();

    final critical = _needs
        .where((n) => n['stock_status']?.toString() == 'CRITICAL')
        .toList();

    final beneficiaryNeeds = _needs
        .where((n) =>
            n['stock_status']?.toString() == 'BENEFICIARY_AWAITING_DONATION')
        .toList();

    if (outOfStock.isEmpty && critical.isEmpty && beneficiaryNeeds.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha:0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withValues(alpha:0.35)),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_outline, size: 20, color: Colors.green),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Inventory looks stable. No urgent item needs found.',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );
    }

    Widget stockSection({
      required String title,
      required String subtitle,
      required IconData icon,
      required Color color,
      required List<Map<String, dynamic>> items,
    }) {
      if (items.isEmpty) return const SizedBox.shrink();

      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha:0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha:0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: color.withValues(alpha:0.15),
                  child: Icon(icon, color: color, size: 17),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$title (${items.length})',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: color,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(fontSize: 11, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            ...items.take(5).map((n) {
              final name = n['item_name']?.toString() ?? 'Item';
              final unit = n['unit']?.toString() ?? 'unit';
              final needType = n['need_type']?.toString() ?? '';
              final beneficiaryName = n['beneficiary_name']?.toString() ?? '';
              final requiredQty = n['required_quantity']?.toString() ?? '';
              final priority = n['priority']?.toString() ?? '';

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha:0.85),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: color.withValues(alpha:0.18),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 18,
                      color: color,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        needType == 'BENEFICIARY_NEED'
                            ? '$name • Qty: $requiredQty $unit • $priority • $beneficiaryName'
                            : '$name ($unit)',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),

            if (items.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '+${items.length - 5} more items',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recipient Inventory Notice',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const Text(
          'These items are currently needed by the selected recipient.',
          style: TextStyle(fontSize: 11, color: Colors.black54),
        ),
        const SizedBox(height: 10),

        stockSection(
          title: 'Beneficiary Requests',
          subtitle: 'Aid requests from beneficiaries awaiting donation.',
          icon: Icons.volunteer_activism,
          color: Colors.deepPurple,
          items: beneficiaryNeeds,
        ),

        stockSection(
          title: 'Out of Stock',
          subtitle: 'No available stock. Highest priority for donation.',
          icon: Icons.error_outline,
          color: Colors.red,
          items: outOfStock,
        ),

        stockSection(
          title: 'Critical Stock',
          subtitle: 'Current stock is at or below minimum level.',
          icon: Icons.warning_amber_rounded,
          color: Colors.amber.shade800,
          items: critical,
        ),
      ],
    );
  }

  Widget _buildRemarksField() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.comment_outlined,
                    color: Theme.of(context).colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Remarks (optional)',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _remarksCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Any notes for the recipient…',
                prefixIcon: Icon(Icons.edit_note_outlined),
              ),
              onChanged: (v) => _remarks = v,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton.icon(
      onPressed: _submitting ? null : _submit,
      icon: _submitting
          ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Icon(_donationType == 'MONEY' ? Icons.payment : Icons.send_outlined),
      label: Text(_submitting
          ? 'Submitting…'
          : _donationType == 'MONEY'
              ? 'Proceed to Payment'
              : 'Submit Donation'),
    );
  }

  Widget _moneySection(ColorScheme colorScheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.payments_outlined, color: colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Donation Amount',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Quick amount chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _quickAmounts.map((amt) {
                final current = double.tryParse(_amountCtrl.text) ?? 0;
                final isSelected = current == amt;
                return ChoiceChip(
                  selected: isSelected,
                  label: Text('RM ${amt.toInt()}'),
                  avatar: isSelected
                      ? const Icon(Icons.check, size: 16)
                      : null,
                  onSelected: (_) {
                    _amountCtrl.text = amt.toStringAsFixed(2);
                    setState(() {});
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Custom Amount (MYR)',
                prefixIcon: Icon(Icons.attach_money),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colorScheme.secondary.withValues(alpha:0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 16, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Funds go directly to relief NGOs for purchasing essential supplies.',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.primary.withValues(alpha:0.8),
                      ),
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

  Widget _itemSection(ColorScheme colorScheme) {
    return Column(
      children: [
        // Item picker card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.add_shopping_cart_outlined,
                        color: colorScheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Add Items',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  value: _selectedCategoryId,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('(All Categories)')),
                    ..._categories.map((c) {
                      final id = (c['category_id'] as num).toInt();
                      final name =
                          c['category_name']?.toString() ?? 'Category';
                      return DropdownMenuItem(value: id, child: Text(name));
                    }),
                  ],
                  onChanged: (v) async {
                    _selectedCategoryId = v;
                    await _loadItems();
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int?>(
                  value: _selectedItemId,
                  decoration: const InputDecoration(
                    labelText: 'Item',
                    prefixIcon: Icon(Icons.inventory_outlined),
                  ),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('(Select an item)')),
                    ..._items.map((it) {
                      final id = (it['item_id'] as num).toInt();
                      final name = it['item_name']?.toString() ?? 'Item';
                      final unit = it['unit']?.toString() ?? 'unit';
                      return DropdownMenuItem(
                          value: id, child: Text('$name ($unit)'));
                    }),
                  ],
                  onChanged: (v) => setState(() => _selectedItemId = v),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _qtyCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Quantity',
                          prefixIcon: Icon(Icons.numbers),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: _addToCart,
                      icon: const Icon(Icons.add_shopping_cart),
                      label: const Text('Add'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(100, 48),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Cart
        if (_cart.isNotEmpty)
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.shopping_cart_outlined,
                      color: colorScheme.primary),
                  title: Text(
                    'Cart (${_cart.length} ${_cart.length == 1 ? 'item' : 'items'})',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const Divider(height: 1),
                ..._cart.map((c) => ListTile(
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: colorScheme.secondary.withValues(alpha:0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.inventory_2_outlined,
                            size: 18, color: colorScheme.primary),
                      ),
                      title: Text(c.itemName,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${c.quantity} ${c.unit}'),
                      trailing: IconButton(
                        icon: Icon(Icons.delete_outline,
                            color: colorScheme.error),
                        onPressed: () => _removeFromCart(c.itemId),
                      ),
                    )),
              ],
            ),
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.shopping_cart_outlined,
                      color: colorScheme.onSurface.withValues(alpha:0.4)),
                  const SizedBox(width: 12),
                  Text(
                    'No items added yet.',
                    style: TextStyle(
                        color: colorScheme.onSurface.withValues(alpha:0.5)),
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 10),

        Card(
          child: SwitchListTile(
            value: _dropoffRequired,
            onChanged: (v) => setState(() => _dropoffRequired = v),
            secondary: Icon(Icons.local_shipping_outlined,
                color: colorScheme.primary),
            title: const Text('Drop-off Required',
                style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text(
                'You will navigate to the NGO location and confirm drop-off'),
          ),
        ),
      ],
    );
  }
}

class _CartItem {
  final int itemId;
  final String itemName;
  final String unit;
  final int quantity;

  const _CartItem({
    required this.itemId,
    required this.itemName,
    required this.unit,
    required this.quantity,
  });

  _CartItem copyWith({int? quantity}) => _CartItem(
        itemId: itemId,
        itemName: itemName,
        unit: unit,
        quantity: quantity ?? this.quantity,
      );
}
