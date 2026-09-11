import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/dio_client.dart';

class NgoDonationDetailPage extends StatefulWidget {
  final Map<String, dynamic> donation;

  const NgoDonationDetailPage({
    super.key,
    required this.donation,
  });

  @override
  State<NgoDonationDetailPage> createState() => _NgoDonationDetailPageState();
}

class _NgoDonationDetailPageState extends State<NgoDonationDetailPage> {
  final Dio _dio = DioClient.create();
  final _noteCtrl = TextEditingController();

  final Map<int, TextEditingController> _qtyControllers = {};

  bool _processing = false;
  bool _savingItems = false;
  bool _itemsChanged = false;

  void _ensureQuantityControllers(List<Map<String, dynamic>> items) {
    for (final item in items) {
      final itemId = _toInt(item['item_id']);
      if (itemId == null) continue;

      final quantity = _toInt(item['quantity']) ?? 0;

      if (!_qtyControllers.containsKey(itemId)) {
        final ctrl = TextEditingController(text: quantity.toString());
        ctrl.addListener(() {
          if (mounted) {
            setState(() => _itemsChanged = true);
          }
        });
        _qtyControllers[itemId] = ctrl;
      }
    }
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  Future<void> _saveItemQuantities(List<Map<String, dynamic>> items) async {
    setState(() => _savingItems = true);

    try {
      final donationId = (widget.donation['donation_id'] as num).toInt();

      final payloadItems = <Map<String, dynamic>>[];

      for (final item in items) {
        final itemId = _toInt(item['item_id']);
        if (itemId == null) continue;

        final ctrl = _qtyControllers[itemId];
        final text = ctrl?.text.trim() ?? '';
        final quantity = int.tryParse(text);

        if (quantity == null || quantity < 0) {
          throw Exception('Please enter a valid quantity for ${item['item_name'] ?? 'item'}');
        }

        payloadItems.add({
          'item_id': itemId,
          'quantity': quantity,
        });
      }

      final res = await _dio.patch(
        '/ngo/donations/$donationId/items',
        data: {
          'items': payloadItems,
        },
      );

      final data = (res.data as Map).cast<String, dynamic>();

      if (data['ok'] != true) {
        throw Exception(data['error'] ?? 'Failed to update item quantities');
      }

      /*
        Update local donation map so the current screen immediately reflects
        the corrected quantity without needing to go back and reopen.
      */
      for (final item in items) {
        final itemId = _toInt(item['item_id']);
        if (itemId == null) continue;

        final ctrl = _qtyControllers[itemId];
        final quantity = int.tryParse(ctrl?.text.trim() ?? '') ?? 0;

        item['quantity'] = quantity;
      }

      if (!mounted) return;

      setState(() => _itemsChanged = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item quantities updated')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _savingItems = false);
      }
    }
  }

  @override
  void dispose() {
    _noteCtrl.dispose();

    for (final ctrl in _qtyControllers.values) {
      ctrl.dispose();
    }

    super.dispose();
  }

  Future<void> _markReceived() async {
    if (_itemsChanged) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please save corrected item quantities before marking as received.'),
        ),
      );
      return;
    }

    setState(() => _processing = true);

    try {
      final id = (widget.donation['donation_id'] as num).toInt();

      final res = await _dio.post(
        '/ngo/donations/$id/mark-received',
        data: {
          'note': _noteCtrl.text.trim(),
        },
      );

      final data = (res.data as Map).cast<String, dynamic>();

      if (data['ok'] != true) {
        throw Exception(data['error'] ?? 'Mark received failed');
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Donation marked as COMPLETED')),
      );

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
        return Colors.green;
      case 'CONFIRMED':
        return Colors.blue;
      case 'PENDING':
        return Colors.orange;
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
        return Icons.check_circle;
      case 'CONFIRMED':
        return Icons.thumb_up;
      case 'PENDING':
        return Icons.hourglass_empty;
      case 'CANCELLED':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.donation;
    final colorScheme = Theme.of(context).colorScheme;

    final id = d['donation_id']?.toString() ?? '';
    final type = d['donation_type']?.toString().toUpperCase() ?? '';
    final status = d['status']?.toString().toUpperCase() ?? '';
    final ngoName = d['ngo_name']?.toString() ?? '';
    final remarks = d['remarks']?.toString() ?? '';
    final createdAt = d['created_at']?.toString() ?? '';

    final donor = _asMap(d['donor']) ?? const <String, dynamic>{};
    final person = _asMap(donor['person']) ?? const <String, dynamic>{};

    final donorName = _firstNonEmpty([
      d['donor_name'],
      d['full_name'],
      person['full_name'],
      donor['full_name'],
      '(Unknown donor)',
    ]);

    final donorEmail = _firstNonEmpty([
      d['donor_email'],
      d['email'],
      person['email'],
      donor['email'],
    ]);

    final donorPhone = _firstNonEmpty([
      d['donor_phone'],
      d['phone'],
      person['phone'],
      donor['phone'],
    ]);

    final proofPhotoUrl = d['proof_photo_url']?.toString().trim() ?? '';

    final dropReq = (d['dropoff_required'] as num?)?.toInt() == 1;
    final dropConf = (d['dropoff_confirmed'] as num?)?.toInt() == 1;

    final canReceive = status != 'CANCELLED' &&
        status != 'COMPLETED' &&
        !(type == 'ITEM' && dropReq && !dropConf);

    final canEditItems = type == 'ITEM' &&
        status != 'COMPLETED' &&
        status != 'CANCELLED';

    final statusColor = _statusColor(status);

    final items = _extractItems(d);
    final payment = _asMap(d['payment']);

    _ensureQuantityControllers(items);

    return Scaffold(
      appBar: AppBar(title: Text('Donation #$id')),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildHeroHeader(
            context: context,
            id: id,
            type: type,
            status: status,
            ngoName: ngoName,
            createdAt: createdAt,
            statusColor: statusColor,
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _StatusExplanationCard(
                  type: type,
                  status: status,
                  dropReq: dropReq,
                  dropConf: dropConf,
                  canReceive: canReceive,
                ),

                const SizedBox(height: 12),

                _InfoCard(
                  title: 'Donor Details',
                  icon: Icons.person_outline,
                  children: [
                    _InfoRow(
                      icon: Icons.badge_outlined,
                      label: 'Name',
                      value: donorName,
                    ),
                    if (donorEmail.isNotEmpty)
                      _InfoRow(
                        icon: Icons.email_outlined,
                        label: 'Email',
                        value: donorEmail,
                      ),
                    if (donorPhone.isNotEmpty)
                      _InfoRow(
                        icon: Icons.phone_outlined,
                        label: 'Phone',
                        value: donorPhone,
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                _InfoCard(
                  title: 'Drop-off Details',
                  icon: Icons.local_shipping_outlined,
                  children: [
                    _InfoRow(
                      icon: Icons.info_outline,
                      label: 'Required',
                      value: dropReq ? 'Yes' : 'No',
                      valueColor: dropReq
                          ? colorScheme.primary
                          : colorScheme.onSurface.withOpacity(0.6),
                    ),
                    _InfoRow(
                      icon: dropConf
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      label: 'Confirmed by Donor',
                      value: dropConf ? 'Confirmed' : 'Not Confirmed',
                      valueColor: dropConf ? Colors.green : Colors.orange,
                    ),
                    if (createdAt.isNotEmpty)
                      _InfoRow(
                        icon: Icons.access_time,
                        label: 'Created At',
                        value: createdAt,
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                if (proofPhotoUrl.isNotEmpty) ...[
                  _ProofPhotoCard(imageUrl: proofPhotoUrl),
                  const SizedBox(height: 12),
                ] else if (type == 'ITEM' && dropReq) ...[
                  _NoProofCard(dropConf: dropConf),
                  const SizedBox(height: 12),
                ],

                if (remarks.isNotEmpty) ...[
                  _InfoCard(
                    title: 'Donor Remarks',
                    icon: Icons.comment_outlined,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          remarks,
                          style: TextStyle(
                            color: colorScheme.onSurface.withOpacity(0.75),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                if (type == 'ITEM') ...[
                  _EditableItemsCard(
                    items: items,
                    canEdit: canEditItems,
                    saving: _savingItems,
                    changed: _itemsChanged,
                    controllers: _qtyControllers,
                    onSave: () => _saveItemQuantities(items),
                  ),
                  const SizedBox(height: 12),
                ],

                if (type == 'MONEY') ...[
                  _PaymentCard(payment: payment, donation: d),
                  const SizedBox(height: 12),
                ],

                _InfoCard(
                  title: 'Internal Receiving Note',
                  icon: Icons.edit_note_outlined,
                  children: [
                    TextField(
                      controller: _noteCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Internal note (optional)',
                        hintText: 'Example: Received by NGO staff at warehouse',
                        border: OutlineInputBorder(),
                      ),
                      minLines: 1,
                      maxLines: 3,
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (!canReceive || _processing)
                        ? null
                        : _markReceived,
                    icon: _processing
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: Text(
                      _processing
                          ? 'Processing...'
                          : status == 'COMPLETED'
                              ? 'Already Completed'
                              : 'Mark as Received (COMPLETED)',
                    ),
                  ),
                ),

                if (!canReceive && status != 'COMPLETED') ...[
                  const SizedBox(height: 8),
                  Text(
                    type == 'ITEM' && dropReq && !dropConf
                        ? 'This donation cannot be completed until the donor confirms drop-off.'
                        : 'This donation cannot be completed.',
                    style: TextStyle(
                      color: colorScheme.error,
                      fontSize: 12,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],

                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroHeader({
    required BuildContext context,
    required String id,
    required String type,
    required String status,
    required String ngoName,
    required String createdAt,
    required Color statusColor,
  }) {
    final typeIcon = type == 'MONEY'
        ? Icons.account_balance_wallet
        : Icons.inventory_2;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.darkAzure, statusColor.withOpacity(0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(typeIcon, color: Colors.white, size: 31),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Donation #$id',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      type == 'MONEY'
                          ? 'Money Donation'
                          : 'Item Donation',
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
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroBadge(
                icon: _statusIcon(status),
                label: status,
              ),
              if (ngoName.isNotEmpty)
                _HeroBadge(
                  icon: Icons.storefront_outlined,
                  label: ngoName,
                ),
              if (createdAt.isNotEmpty)
                _HeroBadge(
                  icon: Icons.access_time,
                  label: createdAt.length > 10
                      ? createdAt.substring(0, 10)
                      : createdAt,
                ),
            ],
          ),
        ],
      ),
    );
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map) return value.cast<String, dynamic>();
    return null;
  }

  static String _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  static List<Map<String, dynamic>> _extractItems(Map<String, dynamic> d) {
    final raw = d['items'] ?? d['donation_items'];

    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    }

    return [];
  }
}

class _HeroBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroBadge({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 15),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusExplanationCard extends StatelessWidget {
  final String type;
  final String status;
  final bool dropReq;
  final bool dropConf;
  final bool canReceive;

  const _StatusExplanationCard({
    required this.type,
    required this.status,
    required this.dropReq,
    required this.dropConf,
    required this.canReceive,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    String message;
    IconData icon;
    Color color;

    if (status == 'COMPLETED') {
      message = 'This donation has been completed and recorded by your NGO.';
      icon = Icons.check_circle_outline;
      color = Colors.green;
    } else if (status == 'CANCELLED') {
      message = 'This donation has been cancelled.';
      icon = Icons.cancel_outlined;
      color = Colors.red;
    } else if (type == 'ITEM' && dropReq && !dropConf) {
      message =
          'Waiting for the donor to confirm drop-off before your NGO can complete this donation.';
      icon = Icons.local_shipping_outlined;
      color = Colors.orange;
    } else if (canReceive) {
      message =
          'This donation is ready for NGO verification. Mark it as received once confirmed.';
      icon = Icons.verified_outlined;
      color = colorScheme.primary;
    } else {
      message = 'This donation is currently not ready for completion.';
      icon = Icons.info_outline;
      color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _InfoCard({
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
          children: [
            Row(
              children: [
                Icon(icon, color: colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: colorScheme.primary,
                    ),
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
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: colorScheme.onSurface.withOpacity(0.5),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: TextStyle(
                color: colorScheme.onSurface.withOpacity(0.65),
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(
              value.isEmpty ? '-' : value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: valueColor ?? colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProofPhotoCard extends StatelessWidget {
  final String imageUrl;

  const _ProofPhotoCard({
    required this.imageUrl,
  });

  void _openPreview(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ProofPhotoPreview(imageUrl: imageUrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.photo_camera_outlined,
                    color: colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Drop-off Proof Photo',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _openPreview(context),
                  icon: const Icon(Icons.open_in_full, size: 16),
                  label: const Text('View'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => _openPreview(context),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  imageUrl,
                  height: 190,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) {
                    return Container(
                      height: 160,
                      color: colorScheme.secondary.withOpacity(0.12),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.broken_image_outlined,
                                color: colorScheme.primary),
                            const SizedBox(height: 8),
                            const Text('Could not load proof image'),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap image to view full proof photo.',
              style: TextStyle(
                color: colorScheme.onSurface.withOpacity(0.55),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProofPhotoPreview extends StatelessWidget {
  final String imageUrl;

  const _ProofPhotoPreview({
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Proof Photo'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) {
              return const Text(
                'Could not load image',
                style: TextStyle(color: Colors.white),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NoProofCard extends StatelessWidget {
  final bool dropConf;

  const _NoProofCard({
    required this.dropConf,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.photo_camera_back_outlined, color: Colors.orange),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              dropConf
                  ? 'Drop-off is confirmed, but no proof photo is attached.'
                  : 'Proof photo will appear here after donor confirms drop-off.',
              style: const TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.w700,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditableItemsCard extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final bool canEdit;
  final bool saving;
  final bool changed;
  final Map<int, TextEditingController> controllers;
  final VoidCallback onSave;

  const _EditableItemsCard({
    required this.items,
    required this.canEdit,
    required this.saving,
    required this.changed,
    required this.controllers,
    required this.onSave,
  });

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return _InfoCard(
      title: canEdit ? 'Donated Items / Actual Received' : 'Donated Items',
      icon: Icons.inventory_2_outlined,
      children: [
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                Icon(
                  Icons.inbox_outlined,
                  size: 42,
                  color: colorScheme.onSurface.withOpacity(0.3),
                ),
                const SizedBox(height: 8),
                Text(
                  'No item details available from API.',
                  style: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.55),
                  ),
                ),
              ],
            ),
          )
        else ...[
          if (canEdit)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.22)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.orange,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Edit the quantity based on the actual items received before marking the donation as completed.',
                      style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          ...items.map((it) {
            final itemId = _toInt(it['item_id']);
            final name = it['item_name']?.toString() ??
                it['name']?.toString() ??
                'Item';
            final category = it['category_name']?.toString() ?? '';
            final unit = it['unit']?.toString() ?? 'unit';

            final controller = itemId == null ? null : controllers[itemId];

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.secondary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.secondary.withOpacity(0.12),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.inventory_2_outlined,
                      color: colorScheme.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        if (category.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            category,
                            style: TextStyle(
                              fontSize: 11,
                              color: colorScheme.onSurface.withOpacity(0.55),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(width: 10),

                  if (canEdit && controller != null)
                    SizedBox(
                      width: 84,
                      child: TextField(
                        controller: controller,
                        enabled: !saving,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          isDense: true,
                          labelText: unit,
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 10,
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${it['quantity'] ?? 0} $unit',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: colorScheme.primary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),

          if (canEdit) ...[
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: saving || !changed ? null : onSave,
                icon: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(
                  saving
                      ? 'Saving...'
                      : changed
                          ? 'Save Corrected Quantities'
                          : 'Quantities Saved',
                ),
              ),
            ),
          ],

          if (!canEdit) ...[
            const SizedBox(height: 4),
            Text(
              'Item quantities are locked after donation is completed or cancelled.',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurface.withOpacity(0.5),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ],
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final Map<String, dynamic>? payment;
  final Map<String, dynamic> donation;

  const _PaymentCard({
    required this.payment,
    required this.donation,
  });

  @override
  Widget build(BuildContext context) {
    final amount = payment?['amount']?.toString() ??
    donation['amount']?.toString() ??
    donation['payment_amount']?.toString() ??
    '';

    final currency = payment?['currency']?.toString() ??
        donation['currency']?.toString() ??
        donation['payment_currency']?.toString() ??
        'MYR';

    final provider = payment?['provider']?.toString() ??
        donation['provider']?.toString() ??
        donation['payment_provider']?.toString() ??
        'ToyyibPay';

    final paymentStatus = payment?['payment_status']?.toString() ??
    donation['payment_status']?.toString() ??
    '';

    final billCode = payment?['provider_bill_code']?.toString() ??
        donation['provider_bill_code']?.toString() ??
        '';

    final invoiceNo = payment?['provider_invoice_no']?.toString() ??
        donation['provider_invoice_no']?.toString() ??
        '';

    final paidAt = payment?['paid_at']?.toString() ??
        donation['paid_at']?.toString() ??
        '';

    return _InfoCard(
      title: 'Money Payment Details',
      icon: Icons.payments_outlined,
      children: [
        _InfoRow(
          icon: Icons.attach_money,
          label: 'Amount',
          value: amount.isEmpty ? '-' : '$currency $amount',
        ),
        _InfoRow(
          icon: Icons.account_balance,
          label: 'Provider',
          value: provider,
        ),
        if (paymentStatus.isNotEmpty)
          _InfoRow(
            icon: Icons.verified_outlined,
            label: 'Payment Status',
            value: paymentStatus,
            valueColor:
                paymentStatus.toUpperCase() == 'PAID'
                    ? Colors.green
                    : Colors.orange,
          ),
        if (billCode.isNotEmpty)
          _InfoRow(
            icon: Icons.receipt_long_outlined,
            label: 'Bill Code',
            value: billCode,
          ),
        if (invoiceNo.isNotEmpty)
          _InfoRow(
            icon: Icons.confirmation_number_outlined,
            label: 'Invoice No',
            value: invoiceNo,
          ),
        if (paidAt.isNotEmpty)
          _InfoRow(
            icon: Icons.access_time,
            label: 'Paid At',
            value: paidAt,
            valueColor: Colors.green,
          ),
      ],
    );
  }
}