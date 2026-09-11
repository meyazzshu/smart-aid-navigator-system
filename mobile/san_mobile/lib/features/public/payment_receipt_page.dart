import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_theme.dart';
import '../../core/dio_client.dart';

class PaymentReceiptPage extends StatefulWidget {
  final int donationId;

  const PaymentReceiptPage({
    super.key,
    required this.donationId,
  });

  @override
  State<PaymentReceiptPage> createState() => _PaymentReceiptPageState();
}

class _PaymentReceiptPageState extends State<PaymentReceiptPage> {
  final Dio _dio = DioClient.create();
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadReceipt();
  }

  Future<Map<String, dynamic>> _loadReceipt() async {
    final res = await _dio.get('/donations/${widget.donationId}/receipt');
    final data = (res.data as Map).cast<String, dynamic>();

    if (data['ok'] != true) {
      throw Exception(data['error'] ?? 'Failed to load receipt');
    }

    return (data['receipt'] as Map).cast<String, dynamic>();
  }

  Future<void> _openUrl(String? url) async {
    if (url == null || url.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Receipt URL not available')),
      );
      return;
    }

    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );

    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open receipt')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Payment Receipt')),
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
                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colorScheme.error),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() => _future = _loadReceipt());
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final r = snapshot.data!;
          final receiptNo = r['receipt_no']?.toString() ?? '-';
          final amount = '${r['currency'] ?? 'MYR'} ${r['amount'] ?? '-'}';
          final isTaxExempt = r['is_tax_exempt'] == true;

          return ListView(
            padding: EdgeInsets.zero,
            children: [
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.darkAzure, AppColors.azure],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Icon(
                        Icons.receipt_long,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Payment Receipt',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      amount,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      receiptNo,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.75),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _ReceiptCard(
                      title: 'Receipt Information',
                      icon: Icons.description_outlined,
                      children: [
                        _ReceiptRow(label: 'Receipt No', value: receiptNo),
                        _ReceiptRow(
                          label: 'Donation ID',
                          value: '#${r['donation_id'] ?? '-'}',
                        ),
                        _ReceiptRow(
                          label: 'Issued At',
                          value: r['receipt_issued_at']?.toString() ?? '-',
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    _ReceiptCard(
                      title: 'Donor',
                      icon: Icons.person_outline,
                      children: [
                        _ReceiptRow(
                          label: 'Name',
                          value: r['donor_name']?.toString() ?? '-',
                        ),
                        _ReceiptRow(
                          label: 'IC / Passport',
                          value: r['donor_ic']?.toString() ?? '-',
                        ),
                        _ReceiptRow(
                          label: 'Email',
                          value: r['donor_email']?.toString() ?? '-',
                        ),
                        _ReceiptRow(
                          label: 'Phone',
                          value: r['donor_phone']?.toString() ?? '-',
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    _ReceiptCard(
                      title: 'Payment Details',
                      icon: Icons.payments_outlined,
                      children: [
                        _ReceiptRow(label: 'Amount', value: amount),
                        _ReceiptRow(
                          label: 'Provider',
                          value: r['provider']?.toString() ?? '-',
                        ),
                        _ReceiptRow(
                          label: 'Method',
                          value: r['method']?.toString() ?? '-',
                        ),
                        _ReceiptRow(
                          label: 'Status',
                          value: r['payment_status']?.toString() ?? '-',
                          valueColor: Colors.green,
                        ),
                        _ReceiptRow(
                          label: 'Bill Code',
                          value: r['provider_bill_code']?.toString() ?? '-',
                        ),
                        _ReceiptRow(
                          label: 'Invoice No',
                          value: r['provider_invoice_no']?.toString() ?? '-',
                        ),
                        _ReceiptRow(
                          label: 'Paid At',
                          value: r['paid_at']?.toString() ?? '-',
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    _ReceiptCard(
                      title: 'Tax Exemption',
                      icon: Icons.verified_user_outlined,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: (isTaxExempt ? Colors.green : Colors.orange)
                                .withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isTaxExempt
                                ? 'This receipt is marked as tax-exemption supporting receipt. LHDN Ref: ${r['tax_exemption_no'] ?? '-'}'
                                : 'This is a payment receipt. Tax exemption depends on whether the recipient organisation is approved by LHDN.',
                            style: TextStyle(
                              color: isTaxExempt ? Colors.green : Colors.orange,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    ElevatedButton.icon(
                      onPressed: () => _openUrl(r['receipt_url']?.toString()),
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text('View Receipt'),
                    ),

                    const SizedBox(height: 10),

                    OutlinedButton.icon(
                      onPressed: () => _openUrl(r['download_url']?.toString()),
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Download Receipt'),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      'For tax filing, keep the official receipt and confirm whether the recipient is LHDN-approved.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface.withOpacity(0.55),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _ReceiptCard({
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
                      fontWeight: FontWeight.w700,
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

class _ReceiptRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _ReceiptRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: TextStyle(
                color: colorScheme.onSurface.withOpacity(0.6),
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueColor ?? colorScheme.primary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}