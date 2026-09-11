import 'dart:typed_data';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config.dart';
import '../../core/parse.dart';

import '../../core/dio_client.dart';
import '../../core/navigation.dart';

import 'delivery_location_helper.dart';

String normalizeNgoDeliveryStatus(Object? rawStatus) {
  if (rawStatus == null) return '';

  final raw = rawStatus.toString().trim();
  if (raw.isEmpty) return '';

  // Canonicalize API variants like "in transit" and "in-transit" to "IN_TRANSIT".
  final normalized = raw
      .toUpperCase()
      .replaceAll(RegExp(r'[\s-]+'), '_');

  if (normalized == 'CANCELED') {
    return 'CANCELLED';
  }

  return normalized;
}

class DeliveryDetailPage extends StatefulWidget {
  final int deliveryId;
  const DeliveryDetailPage({super.key, required this.deliveryId});

  @override
  State<DeliveryDetailPage> createState() => _DeliveryDetailPageState();
}

class _DeliveryDetailPageState extends State<DeliveryDetailPage> {
  static const String _statusRouted = 'ROUTED';
  static const String _statusInTransit = 'IN_TRANSIT';
  static const String _statusDelivered = 'DELIVERED';
  static const String _statusCancelled = 'CANCELLED';
  static const int _pickedImageQuality = 80;
  static const double _pickedImageMaxWidth = 1920;
  static final RegExp _leadingSlashesPattern = RegExp(r'^/+');

  final Dio _dio = DioClient.create();
  late Future<Map<String, dynamic>> _future;

  final _noteCtrl = TextEditingController();
  bool _updating = false;
  XFile? _proofImage;
  Uint8List? _proofImageBytes;
  String? _proofPhotoUrl;

  Color _statusColor(String status, ColorScheme scheme) {
    switch (status) {
      case _statusRouted:
        return Colors.indigo;
      case _statusInTransit:
        return Colors.orange;
      case _statusDelivered:
        return Colors.green;
      case _statusCancelled:
        return Colors.red;
      default:
        return scheme.primary;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case _statusRouted:
        return Icons.route_rounded;
      case _statusInTransit:
        return Icons.local_shipping_rounded;
      case _statusDelivered:
        return Icons.check_circle_rounded;
      case _statusCancelled:
        return Icons.cancel_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  String _statusLabel(String status) => status == _statusInTransit ? 'IN TRANSIT' : status;

  List<String> _allowedUpdateStatuses(String status) {
    switch (status) {
      case 'PLANNED':
        return [_statusInTransit, _statusCancelled];

      case _statusRouted:
        return [_statusInTransit, _statusCancelled];

      case _statusInTransit:
        return [_statusDelivered, _statusCancelled];

      default:
        return const [];
    }
  }

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _load() async {
    final res = await _dio.get('/deliveries/${widget.deliveryId}');
    final data = (res.data as Map).cast<String, dynamic>();
    if (data['ok'] != true) throw Exception(data['error'] ?? 'Failed to load delivery');
    return data;
  }

  Future<void> _refresh() async {
    final newFuture = _load();
    setState(() {
      _future = newFuture;
      _proofImage = null;
      _proofImageBytes = null;
      _proofPhotoUrl = null;
    });
    await newFuture;
  }

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

    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: _pickedImageQuality,
      maxWidth: _pickedImageMaxWidth,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();

    setState(() {
      _proofImage = picked;
      _proofImageBytes = bytes;
      _proofPhotoUrl = null;
    });
  }

  Future<String> _uploadProofToSupabase() async {
    final image = _proofImage!;
    final bytes = _proofImageBytes ?? await image.readAsBytes();

    final rawExt = image.name.split('.').last.toLowerCase();
    const allowedExtensions = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'heic'};
    if (!allowedExtensions.contains(rawExt)) {
      throw Exception(
        'Unsupported file type ".$rawExt". Please use JPG, JPEG, PNG, GIF, WEBP, or HEIC.',
      );
    }
    final mimeExt = rawExt == 'jpg' ? 'jpeg' : rawExt;
    final contentType = 'image/$mimeExt';
    final randomSuffix = Random.secure().nextInt(0x100000000).toRadixString(16);
    final fileName =
        'delivery/${widget.deliveryId}/${DateTime.now().microsecondsSinceEpoch}_$randomSuffix.$rawExt';

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

    return supabase.storage.from(AppConfig.dropoffProofsBucket).getPublicUrl(fileName);
  }

  String _deliveryProofErrorMessage(Object error) {
    final message = error.toString().trim();
    if (message.startsWith('Exception: ')) {
      return message.substring('Exception: '.length);
    }
    if (message.isNotEmpty) {
      return message;
    }
    return 'Unable to mark delivery as delivered right now. Please try again.';
  }

  Future<void> _markDeliveredWithProof() async {
    if (_proofImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please take a proof photo first.')),
      );
      return;
    }
    try {
      _proofPhotoUrl ??= await _uploadProofToSupabase();

      await _updateStatus(
        _statusDelivered,
        extraData: {
          // Send both the new database field and legacy aliases so current and
          // older backend/API readers can all resolve the same proof photo.
          'image_link': _proofPhotoUrl,
          'photo_url': _proofPhotoUrl,
          'proof_photo_url': _proofPhotoUrl,
        },
      );
    } catch (e) {
      if (!mounted) return;
      final message = _deliveryProofErrorMessage(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _updateStatus(
    String status, {
    Map<String, dynamic>? extraData,
  }) async {
    setState(() {
      _updating = true;
    });
    try {
      final payload = <String, dynamic>{
        'status': status,
        'note': _noteCtrl.text.trim(),
      };
      if (extraData != null) {
        payload.addAll(extraData);
      }
      final res = await _dio.patch(
        '/deliveries/${widget.deliveryId}/status',
        data: payload,
      );
      final data = (res.data as Map).cast<String, dynamic>();
      if (data['ok'] != true) throw Exception(data['error'] ?? 'Update failed');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Status updated to $status')));
      _noteCtrl.clear();
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _updating = false;
        });
      }
    }
  }

  String? _proofUrlFromRecord(Map<String, dynamic> record) {
    // Accept multiple legacy/current backend keys so persisted proof photos
    // still render even if API field naming differs by endpoint/version.
    const keys = [
      'image_link',
      'photo_url',
      'proof_photo_url',
      'proof_url',
      'delivery_photo_url',
      'proof_image_url',
      'image_url',
      'proof_photo_path',
    ];
    for (final key in keys) {
      // Some API responses may send string "null" instead of null; ignore those values.
      final value = record[key]?.toString().trim() ?? '';
      final normalized = _normalizeProofUrl(value);
      if (normalized != null) return normalized;
    }
    return null;
  }

  String? _normalizeProofUrl(String value) {
    if (value.isEmpty || value == 'null') return null;

    final lower = value.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return value;
    }

    final withoutLeadingSlash = value.replaceFirst(_leadingSlashesPattern, '');
    final bucketPrefix = '${AppConfig.dropoffProofsBucket}/';
    final normalizedPath = withoutLeadingSlash.startsWith(bucketPrefix)
        ? withoutLeadingSlash.substring(bucketPrefix.length)
        : withoutLeadingSlash;
    if (normalizedPath.isEmpty) return null;
    try {
      return Supabase.instance.client.storage
          .from(AppConfig.dropoffProofsBucket)
          .getPublicUrl(normalizedPath);
    } catch (e) {
      debugPrint('Failed to normalize proof URL "$value": $e');
      return null;
    }
  }

  String? _extractProofUrl(
    Map<String, dynamic> delivery,
    List<Map<String, dynamic>> tracking,
  ) {
    final fromDelivery = _proofUrlFromRecord(delivery);
    if (fromDelivery != null) return fromDelivery;
    for (final t in tracking.reversed) {
      final fromTracking = _proofUrlFromRecord(t);
      if (fromTracking != null) return fromTracking;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text('Delivery #${widget.deliveryId}')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(snapshot.error.toString(), style: TextStyle(color: colorScheme.error)),
            ));
          }

          final data = snapshot.data!;
          final delivery = (data['delivery'] as Map).cast<String, dynamic>();
          final shelter = (data['shelter'] as Map).cast<String, dynamic>();
          final items = (data['items'] as List).cast<dynamic>().map((e) => (e as Map).cast<String, dynamic>()).toList();
          final tracking = (data['tracking'] as List).cast<dynamic>().map((e) => (e as Map).cast<String, dynamic>()).toList();
          final lat = parseDouble(shelter['latitude']);
          final lng = parseDouble(shelter['longitude']);

          final normalizedStatus = normalizeNgoDeliveryStatus(delivery['status']);
          final isDelivered = normalizedStatus == _statusDelivered;
          final shelterName = shelter['shelter_name']?.toString() ?? '';
          final proofUrl = _extractProofUrl(delivery, tracking);
          final allowedUpdateStatuses = _allowedUpdateStatuses(normalizedStatus);
          final canSelectDelivered = allowedUpdateStatuses.contains(_statusDelivered);
          final canSubmitDelivered = !_updating && _proofImage != null && canSelectDelivered;
          final statusColor = _statusColor(normalizedStatus, colorScheme);
          final address = [
            shelter['address_line'],
            shelter['city'],
            shelter['state'],
            shelter['postal_code'],
          ].where((x) => x != null && x.toString().trim().isNotEmpty).join(', ');

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Delivery #${widget.deliveryId}',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha:0.14),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(_statusIcon(normalizedStatus), size: 14, color: statusColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    _statusLabel(normalizedStatus),
                                    style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.home_work_outlined, size: 18, color: colorScheme.primary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                shelterName,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.location_on_outlined, size: 18, color: colorScheme.primary),
                            const SizedBox(width: 6),
                            Expanded(child: Text(address)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: (lat == null || lng == null)
                                ? null
                                : () async {
                                    try {
                                      final current = await DeliveryLocationHelper.getCurrentPosition();

                                      final ok = await NavigationHelper.navigateTo(
                                        originLat: current.latitude,
                                        originLng: current.longitude,
                                        destLat: lat,
                                        destLng: lng,
                                      );

                                      if (!ok && context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Unable to open Google Maps')),
                                        );
                                      }
                                    } catch (e) {
                                      final ok = await NavigationHelper.navigateTo(
                                        destLat: lat,
                                        destLng: lng,
                                      );

                                      if (!ok && context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Unable to open Google Maps: $e')),
                                        );
                                      }
                                    }
                                  },
                            icon: const Icon(Icons.navigation_rounded),
                            label: const Text('Navigate with Google Maps'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.inventory_2_outlined, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    const Text(
                      'Delivery Items',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (items.isEmpty)
                  const Text('No delivery items.')
                else
                  Card(
                    child: Column(
                      children: items.map((it) {
                        final name = it['item_name']?.toString() ?? '';
                        final qty = it['quantity']?.toString() ?? '0';
                        final unit = it['unit']?.toString() ?? 'unit';
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: colorScheme.primary.withValues(alpha:0.10),
                            child: Icon(
                              Icons.inventory_2_outlined,
                              color: colorScheme.primary,
                              size: 18,
                            ),
                          ),
                          title: Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(alpha:0.10),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '$qty $unit',
                              style: TextStyle(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                const SizedBox(height: 12),
                const Text('Update Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                TextField(
                  controller: _noteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    border: OutlineInputBorder(),
                  ),
                  minLines: 1,
                  maxLines: 3,
                ),
                const SizedBox(height: 10),

                if (allowedUpdateStatuses.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded, size: 18, color: colorScheme.onSurfaceVariant),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'No status changes available for this delivery.',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: allowedUpdateStatuses
                        .map(
                          (nextStatus) => _StatusButton(
                            label: _statusLabel(nextStatus),
                            busy: _updating,
                            enabled: nextStatus != _statusDelivered || canSubmitDelivered,
                            color: _statusColor(nextStatus, colorScheme),
                            icon: _statusIcon(nextStatus),
                            onTap: nextStatus == _statusDelivered
                                ? _markDeliveredWithProof
                                : () => _updateStatus(nextStatus),
                          ),
                        )
                        .toList(),
                  ),
                const SizedBox(height: 12),
                const Text('Proof of Delivery', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                if (proofUrl != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      proofUrl,
                      height: 190,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 190,
                        alignment: Alignment.center,
                        color: colorScheme.surfaceContainerHighest,
                        child: const Text('Unable to load proof photo'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    proofUrl,
                    style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withValues(alpha:0.7)),
                  ),
                ] else if (isDelivered) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.photo_camera_back_outlined, color: colorScheme.onSurfaceVariant),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'No proof photo was uploaded for this delivery.',
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  if (_proofImage == null) ...[
                    OutlinedButton.icon(
                      onPressed: _updating ? null : _pickProofPhoto,
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Take Proof Photo'),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      canSelectDelivered
                          ? 'Upload proof photo before completing this delivery.'
                          : 'Set status to IN_TRANSIT before marking as DELIVERED.',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface.withValues(alpha:0.7),
                      ),
                    ),
                  ] else ...[
                    if (_proofImageBytes == null)
                      Container(
                        height: 190,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const CircularProgressIndicator(),
                      )
                    else
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(
                              _proofImageBytes!,
                              height: 190,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            right: 8,
                            top: 8,
                            child: InkWell(
                              onTap: _updating
                                  ? null
                                  : () => setState(() {
                                        _proofImage = null;
                                        _proofImageBytes = null;
                                        _proofPhotoUrl = null;
                                      }),
                              child: const CircleAvatar(
                                radius: 14,
                                backgroundColor: Colors.black54,
                                child: Icon(Icons.close, color: Colors.white, size: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 6),
                    TextButton.icon(
                      onPressed: _updating ? null : _pickProofPhoto,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Retake Photo'),
                    ),
                  ],
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: canSubmitDelivered ? _markDeliveredWithProof : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _statusColor(_statusDelivered, colorScheme),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: colorScheme.surfaceContainerHighest,
                        disabledForegroundColor: colorScheme.onSurfaceVariant,
                      ),
                      icon: _updating
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_circle_outline),
                      label: const Text('Submit Proof & Mark Delivered'),
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                const Text('Tracking (latest)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),

                if (tracking.isEmpty)
                  const Text('No tracking updates yet.')
                else
                  Card(
                    child: Column(
                      children: tracking.map((t) {
                        final st = normalizeNgoDeliveryStatus(t['status']);
                        final note = t['note']?.toString() ?? '';
                        final when = t['created_at']?.toString() ?? '';
                        final trackingProofUrl = _proofUrlFromRecord(t);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ListTile(
                              title: Text(_statusLabel(st)),
                              subtitle: Text([if (note.isNotEmpty) note, if (when.isNotEmpty) when].join('\n')),
                            ),
                            if (trackingProofUrl != null)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(
                                    trackingProofUrl,
                                    height: 160,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      height: 160,
                                      alignment: Alignment.center,
                                      color: colorScheme.surfaceContainerHighest,
                                      child: const Text('Unable to load proof photo'),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      }).toList(),
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

class _StatusButton extends StatelessWidget {
  final String label;
  final bool busy;
  final bool enabled;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _StatusButton({
    required this.label,
    required this.busy,
    this.enabled = true,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: (busy || !enabled) ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        disabledForegroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      child: busy
          ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16),
                const SizedBox(width: 6),
                Text(label),
              ],
            ),
    );
  }
}
