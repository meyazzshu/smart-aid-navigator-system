import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_theme.dart';
import '../../core/config.dart';
import '../../core/dio_client.dart';
import '../../core/navigation.dart';
import '../../core/parse.dart';
import 'payment_receipt_page.dart';


class DonationDetailPage extends StatefulWidget {
  final int donationId;
  const DonationDetailPage({super.key, required this.donationId});

  @override
  State<DonationDetailPage> createState() => _DonationDetailPageState();
}

class _DonationDetailPageState extends State<DonationDetailPage> {
  final Dio _dio = DioClient.create();
  late Future<Map<String, dynamic>> _future;
  bool _confirming = false;

  /// XFile of the proof photo chosen by the user (null = not picked yet).
  XFile? _proofImage;

  /// Public URL of the uploaded proof photo (set after a successful upload).
  String? _proofPhotoUrl;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final res = await _dio.get('/donations/${widget.donationId}');
    final data = (res.data as Map).cast<String, dynamic>();
    if (data['ok'] != true) throw Exception(data['error'] ?? 'Failed to load donation');
    return data;
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
      _proofImage = null;
      _proofPhotoUrl = null;
    });
    await _future;
  }

  // ---------- Camera / Gallery ----------

  /// Opens a bottom sheet so the user can choose Camera or Gallery.
  Future<void> _pickProofPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1920,
    );

    if (picked == null) return;

    setState(() {
      _proofImage = picked;
      _proofPhotoUrl = null; // reset previous upload if user picks again
    });
  }

  /// Uploads _proofImage to Supabase Storage and returns the public URL.
  Future<String> _uploadProofToSupabase() async {
    final image = _proofImage!;
    final bytes = await image.readAsBytes();

    // Normalise the extension and validate it is an image format.
    final rawExt = image.name.split('.').last.toLowerCase();
    const allowedExtensions = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'heic'};
    if (!allowedExtensions.contains(rawExt)) {
      throw Exception('Unsupported file type ".$rawExt". Please use a JPG, PNG, or similar image.');
    }
    
    final mimeExt = rawExt == 'jpg' ? 'jpeg' : rawExt;
    final contentType = 'image/$mimeExt';

    final fileName =
        'donations/${widget.donationId}/${DateTime.now().millisecondsSinceEpoch}.$rawExt';

    final supabase = Supabase.instance.client;
    try {
      await supabase.storage
          .from(AppConfig.dropoffProofsBucket)
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: FileOptions(
              contentType: contentType,
              upsert: false,
            ),
          );
    } on StorageException catch (e) {
      throw Exception('Photo upload failed: ${e.message}');
    }

    final publicUrl = supabase.storage
        .from(AppConfig.dropoffProofsBucket)
        .getPublicUrl(fileName);

    return publicUrl;
  }

  // ---------- Confirm drop-off ----------

  Future<void> _confirmDropoff() async {
    // Step 1: require a proof photo
    if (_proofImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please take a photo as proof of drop-off first.'),
        ),
      );
      return;
    }

    setState(() => _confirming = true);
    try {
      // Step 2: upload the photo if not already uploaded
      _proofPhotoUrl ??= await _uploadProofToSupabase();

      // Step 3: call the API with the photo URL
      final res = await _dio.post(
        '/donations/${widget.donationId}/confirm-dropoff',
        data: {'photo_url': _proofPhotoUrl},
      );
      final data = (res.data as Map).cast<String, dynamic>();
      if (data['ok'] != true) throw Exception(data['error'] ?? 'Confirm failed');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Drop-off confirmed! Thank you.')),
      );
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _confirming = false);
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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text('Donation #${widget.donationId}')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 56, color: colorScheme.error),
                    const SizedBox(height: 12),
                    Text(snapshot.error.toString(),
                        style: TextStyle(color: colorScheme.error),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final data = snapshot.data!;
          final donation = (data['donation'] as Map).cast<String, dynamic>();
          final items = (data['items'] as List)
              .cast<dynamic>()
              .map((e) => (e as Map).cast<String, dynamic>())
              .toList();

          final payment = (data['payment'] as Map?)?.cast<String, dynamic>();
          final type = donation['donation_type']?.toString() ?? '';
          final status = donation['status']?.toString() ?? '';
          final remarks = donation['remarks']?.toString() ?? '';

          final dropRequired =
              (donation['dropoff_required'] as num?)?.toInt() == 1;
          final dropConfirmed =
              (donation['dropoff_confirmed'] as num?)?.toInt() == 1;

          final ngoName = donation['ngo_name']?.toString();
          final ngoLat = parseDouble(donation['ngo_lat']);
          final ngoLng = parseDouble(donation['ngo_lng']);

          final ngoAddress = [
            donation['ngo_address']?.toString() ?? '',
            donation['ngo_city']?.toString() ?? '',
            donation['ngo_state']?.toString() ?? '',
            donation['ngo_postal']?.toString() ?? '',
          ].where((x) => x.trim().isNotEmpty).join(', ');

          final statusColor = _statusColor(status);
          final statusIcon = _statusIcon(status);

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(0),
              children: [
                // Hero status banner
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.darkAzure, statusColor.withValues(alpha:0.7)],
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
                            child: Icon(
                              type == 'MONEY'
                                  ? Icons.account_balance_wallet
                                  : Icons.inventory_2,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Donation #${widget.donationId}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                type == 'MONEY' ? 'Money Donation' : 'Item Donation',
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha:0.8),
                                    fontSize: 13),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha:0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, color: Colors.white, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              status,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Remarks
                      if (remarks.isNotEmpty) ...[
                        Card(
                          child: ListTile(
                            leading: Icon(Icons.comment_outlined,
                                color: colorScheme.primary),
                            title: const Text('Remarks',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text(remarks),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // NGO info card
                      if (ngoName != null && ngoName.isNotEmpty) ...[
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.storefront_outlined,
                                        color: colorScheme.primary, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'NGO Recipient',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color:
                                            colorScheme.secondary.withValues(alpha:0.15),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(Icons.business,
                                          color: colorScheme.primary, size: 22),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(ngoName,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w700)),
                                          if (ngoAddress.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              ngoAddress,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: colorScheme.onSurface
                                                    .withValues(alpha:0.6),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: (ngoLat == null || ngoLng == null)
                                      ? null
                                      : () async {
                                          final ok =
                                              await NavigationHelper.navigateTo(
                                            destLat: ngoLat,
                                            destLng: ngoLng,
                                          );
                                          if (!ok && mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(const SnackBar(
                                                    content: Text(
                                                        'Could not open Google Maps')));
                                          }
                                        },
                                  icon: const Icon(Icons.navigation_outlined),
                                  label: const Text('Navigate to NGO'),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Drop-off section (ITEM only)
                      if (type == 'ITEM') ...[
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.local_shipping_outlined,
                                        color: colorScheme.primary, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Drop-off Status',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _InfoRow(
                                  icon: Icons.info_outline,
                                  label: 'Drop-off Required',
                                  value: dropRequired ? 'Yes' : 'No',
                                  valueColor: dropRequired
                                      ? colorScheme.primary
                                      : colorScheme.onSurface.withValues(alpha:0.5),
                                ),
                                const SizedBox(height: 6),
                                _InfoRow(
                                  icon: dropConfirmed
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  label: 'Drop-off Confirmed',
                                  value: dropConfirmed ? 'Confirmed ✓' : 'Pending',
                                  valueColor: dropConfirmed
                                      ? Colors.green
                                      : Colors.orange,
                                ),
                                if (dropRequired && !dropConfirmed) ...[
                                  const SizedBox(height: 14),
                                  // ---- Proof photo picker ----
                                  if (_proofImage == null) ...[
                                    OutlinedButton.icon(
                                      onPressed: _confirming ? null : _pickProofPhoto,
                                      icon: const Icon(Icons.camera_alt_outlined),
                                      label: const Text('Take Proof Photo'),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'A photo is required to confirm your drop-off.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colorScheme.onSurface.withValues(alpha:0.55),
                                      ),
                                    ),
                                  ] else ...[
                                    Stack(
                                      children: [
                                        FutureBuilder<Uint8List>(
                                          future: _proofImage!.readAsBytes(),
                                          builder: (ctx, snap) {
                                            if (!snap.hasData) {
                                              return Container(
                                                height: 160,
                                                decoration: BoxDecoration(
                                                  color: colorScheme.surfaceContainerHighest,
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: const Center(
                                                    child: CircularProgressIndicator()),
                                              );
                                            }
                                            return ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              child: Image.memory(
                                                snap.data!,
                                                height: 160,
                                                width: double.infinity,
                                                fit: BoxFit.cover,
                                              ),
                                            );
                                          },
                                        ),
                                        Positioned(
                                          top: 6,
                                          right: 6,
                                          child: GestureDetector(
                                            onTap: _confirming
                                                ? null
                                                : () => setState(() {
                                                      _proofImage = null;
                                                      _proofPhotoUrl = null;
                                                    }),
                                            child: Container(
                                              decoration: const BoxDecoration(
                                                color: Colors.black54,
                                                shape: BoxShape.circle,
                                              ),
                                              padding: const EdgeInsets.all(4),
                                              child: const Icon(Icons.close,
                                                  color: Colors.white, size: 16),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    TextButton.icon(
                                      onPressed:
                                          _confirming ? null : _pickProofPhoto,
                                      icon: const Icon(Icons.refresh, size: 16),
                                      label: const Text('Retake Photo'),
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  // ---- Confirm button ----
                                  ElevatedButton.icon(
                                    onPressed:
                                        (_confirming || _proofImage == null)
                                            ? null
                                            : _confirmDropoff,
                                    icon: _confirming
                                        ? const SizedBox(
                                            height: 16,
                                            width: 16,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white))
                                        : const Icon(Icons.check_circle_outline),
                                    label: Text(_confirming
                                        ? 'Confirming…'
                                        : 'I Have Dropped Off the Items'),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Items list
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.inventory_2_outlined,
                                      color: colorScheme.primary, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    type == 'MONEY'
                                        ? 'Payment Details'
                                        : 'Donated Items',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (type == 'MONEY') ...[
                                if (payment == null)
                                  Center(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons.inbox_outlined,
                                            size: 40,
                                            color: colorScheme.onSurface.withValues(alpha:0.3),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Payment info not available yet.',
                                            style: TextStyle(
                                              color: colorScheme.onSurface.withValues(alpha:0.5),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                else ...[
                                  _InfoRow(
                                    icon: Icons.payments_outlined,
                                    label: 'Amount',
                                    value: '${payment['currency'] ?? 'MYR'} ${payment['amount'] ?? '-'}',
                                    valueColor: colorScheme.primary,
                                  ),
                                  const SizedBox(height: 8),
                                  _InfoRow(
                                    icon: Icons.account_balance,
                                    label: 'Provider',
                                    value: payment['provider']?.toString() ?? '-',
                                    valueColor: colorScheme.primary,
                                  ),
                                  const SizedBox(height: 8),
                                  _InfoRow(
                                    icon: Icons.verified_outlined,
                                    label: 'Payment Status',
                                    value: payment['payment_status']?.toString() ?? '-',
                                    valueColor:
                                        payment['payment_status']?.toString().toUpperCase() == 'PAID'
                                            ? Colors.green
                                            : Colors.orange,
                                  ),
                                  const SizedBox(height: 8),
                                  _InfoRow(
                                    icon: Icons.receipt_long_outlined,
                                    label: 'Bill Code',
                                    value: payment['provider_bill_code']?.toString() ?? '-',
                                    valueColor: colorScheme.onSurface,
                                  ),
                                  if ((payment['provider_invoice_no']?.toString() ?? '').isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    _InfoRow(
                                      icon: Icons.confirmation_number_outlined,
                                      label: 'Invoice No',
                                      value: payment['provider_invoice_no'].toString(),
                                      valueColor: colorScheme.onSurface,
                                    ),
                                  ],
                                  if ((payment['paid_at']?.toString() ?? '').isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    _InfoRow(
                                      icon: Icons.access_time,
                                      label: 'Paid At',
                                      value: payment['paid_at'].toString(),
                                      valueColor: Colors.green,
                                    ),
                                  ],
                                  const SizedBox(height: 14),
                                  ElevatedButton.icon(
                                    onPressed: payment['payment_status']?.toString().toUpperCase() == 'PAID'
                                        ? () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) => PaymentReceiptPage(
                                                  donationId: widget.donationId,
                                                ),
                                              ),
                                            );
                                          }
                                        : null,
                                    icon: const Icon(Icons.receipt_long_outlined),
                                    label: const Text('View / Download Receipt'),
                                  ),
                                ],
                              ] else ...[
                                if (items.isEmpty)
                                  Center(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons.inbox_outlined,
                                            size: 40,
                                            color: colorScheme.onSurface.withValues(alpha:0.3),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'No items recorded.',
                                            style: TextStyle(
                                              color: colorScheme.onSurface.withValues(alpha:0.5),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                else
                                  ...items.map((it) {
                                    final name = it['item_name']?.toString() ?? '';
                                    final qty = it['quantity']?.toString() ?? '0';
                                    final unit = it['unit']?.toString() ?? 'unit';

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: colorScheme.secondary.withValues(alpha:0.08),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.check_box_outlined,
                                            size: 18,
                                            color: colorScheme.primary,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              name,
                                              style: const TextStyle(fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: colorScheme.primary.withValues(alpha:0.12),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              '$qty $unit',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: colorScheme.primary,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
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
    return Row(
      children: [
        Icon(icon,
            size: 16, color: colorScheme.onSurface.withValues(alpha:0.5)),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha:0.65), fontSize: 13)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: valueColor ?? colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
