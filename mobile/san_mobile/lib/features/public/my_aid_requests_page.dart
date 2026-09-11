import 'package:flutter/material.dart';

import 'beneficiary_needs_api.dart';
import 'beneficiary_need_detail_page.dart';

class MyAidRequestsPage extends StatefulWidget {
  const MyAidRequestsPage({super.key});

  @override
  State<MyAidRequestsPage> createState() => _MyAidRequestsPageState();
}

class _MyAidRequestsPageState extends State<MyAidRequestsPage> {
  final _api = BeneficiaryNeedsApi();

  late Future<_AidRequestPageData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_AidRequestPageData> _load() async {
    final status = await _api.getMyBeneficiaryStatus();

    if (!status.isBeneficiary) {
      return _AidRequestPageData(
        status: status,
        items: const [],
        needs: const [],
      );
    }

    final results = await Future.wait([
      _api.getAidItems(),
      _api.getMyNeeds(),
    ]);

    return _AidRequestPageData(
      status: status,
      items: results[0] as List<AidItemOption>,
      needs: results[1] as List<BeneficiaryNeedRequest>,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'SUBMITTED':
        return Colors.orange;
      case 'UNDER_REVIEW':
        return Colors.blue;
      case 'REJECTED':
        return Colors.red;
      case 'AWAITING_DONATION':
        return Colors.deepOrange;
      case 'READY_FOR_PICKUP':
        return Colors.green;
      case 'FULFILLED':
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }

  String _statusLabel(String status) {
    return status.replaceAll('_', ' ');
  }

  Future<void> _openSubmitSheet(List<AidItemOption> items) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SubmitAidNeedSheet(items: items),
    );

    if (changed == true) {
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Aid Requests'),
      ),
      body: FutureBuilder<_AidRequestPageData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text('Error: ${snapshot.error}'),
              ),
            );
          }

          final data = snapshot.data!;

          if (!data.status.isBeneficiary) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: const [
                Card(
                  child: ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text(
                      'Not available yet',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      'You can submit aid requests only after your PPS booking has been accepted and you are registered as a beneficiary by the shelter.',
                    ),
                  ),
                ),
              ],
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.home_work_outlined),
                    title: Text(
                      data.status.beneficiary?.shelterName ?? 'Shelter',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      'Beneficiary: ${data.status.beneficiary?.fullName ?? '-'}',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => _openSubmitSheet(data.items),
                  icon: const Icon(Icons.add),
                  label: const Text('Submit Aid Request'),
                ),
                const SizedBox(height: 16),
                if (data.needs.isEmpty)
                  const Card(
                    child: ListTile(
                      leading: Icon(Icons.inbox_outlined),
                      title: Text('No aid requests yet'),
                      subtitle: Text('Submit your first aid request above.'),
                    ),
                  )
                else
                  ...data.needs.map((need) {
                    final color = _statusColor(need.requestStatus);

                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => BeneficiaryNeedDetailPage(need: need),
                          ),
                        );
                      },
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    need.itemName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha:0.12),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: color),
                                  ),
                                  child: Text(
                                    _statusLabel(need.requestStatus),
                                    style: TextStyle(
                                      color: color,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text('Quantity: ${need.requiredQuantity} ${need.unit}'),
                            Text('Priority: ${need.priority}'),
                            if (need.notes.isNotEmpty) Text('Notes: ${need.notes}'),
                            if (need.rejectionReason.isNotEmpty)
                              Text(
                                'Rejected reason: ${need.rejectionReason}',
                                style: const TextStyle(color: Colors.red),
                              ),
                            const SizedBox(height: 6),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.visibility_outlined,
                                  size: 16,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Tap to view details',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Submitted: ${need.createdAt}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha:0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SubmitAidNeedSheet extends StatefulWidget {
  final List<AidItemOption> items;

  const _SubmitAidNeedSheet({
    required this.items,
  });

  @override
  State<_SubmitAidNeedSheet> createState() => _SubmitAidNeedSheetState();
}

class _SubmitAidNeedSheetState extends State<_SubmitAidNeedSheet> {
  final _api = BeneficiaryNeedsApi();
  final _notesController = TextEditingController();

  AidItemOption? _selectedItem;
  int _quantity = 1;
  String _priority = 'MEDIUM';
  bool _saving = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedItem == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an aid item.')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final res = await _api.submitNeed(
        itemId: _selectedItem!.itemId,
        requiredQuantity: _quantity,
        priority: _priority,
        notes: _notesController.text.trim(),
      );

      if (res['ok'] != true) {
        throw Exception(res['error'] ?? 'Unable to submit request.');
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aid request submitted.')),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 18,
        bottom: MediaQuery.of(context).viewInsets.bottom + 18,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Submit Aid Request',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<AidItemOption>(
              value: _selectedItem,
              decoration: const InputDecoration(
                labelText: 'Aid Item',
                border: OutlineInputBorder(),
              ),
              items: widget.items
                  .map(
                    (item) => DropdownMenuItem(
                      value: item,
                      child: Text(item.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _selectedItem = value),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: '1',
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Required Quantity',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                final parsed = int.tryParse(value) ?? 1;
                _quantity = parsed < 1 ? 1 : parsed;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _priority,
              decoration: const InputDecoration(
                labelText: 'Priority',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'LOW', child: Text('Low')),
                DropdownMenuItem(value: 'MEDIUM', child: Text('Medium')),
                DropdownMenuItem(value: 'HIGH', child: Text('High')),
                DropdownMenuItem(value: 'CRITICAL', child: Text('Critical')),
              ],
              onChanged: (value) => setState(() => _priority = value ?? 'MEDIUM'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
                hintText: 'Example: Need clean water urgently...',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: Text(_saving ? 'Submitting...' : 'Submit Request'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AidRequestPageData {
  final BeneficiaryStatusResult status;
  final List<AidItemOption> items;
  final List<BeneficiaryNeedRequest> needs;

  const _AidRequestPageData({
    required this.status,
    required this.items,
    required this.needs,
  });
}