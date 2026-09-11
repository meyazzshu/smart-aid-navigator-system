import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_theme.dart';
import '../../core/dio_client.dart';

class PaymentPage extends StatefulWidget {
  final int donationId;
  final double amount;
  final String currency;

  const PaymentPage({
    super.key,
    required this.donationId,
    required this.amount,
    required this.currency,
  });

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  final Dio _dio = DioClient.create();

  bool _processing = false;
  bool _checking = false;

  String? _lastPaymentUrl;
  String? _lastBillCode;

  Future<void> _payWithToyyibPay() async {
    setState(() => _processing = true);

    try {
      final res = await _dio.post(
        '/donations/${widget.donationId}/toyyibpay/create-bill',
        data: {
          'amount': widget.amount,
        },
      );

      final data = (res.data as Map).cast<String, dynamic>();

      if (data['ok'] != true) {
        throw Exception(data['error'] ?? 'Failed to create ToyyibPay bill');
      }

      final paymentUrl = data['payment_url']?.toString() ?? '';
      final billCode = data['bill_code']?.toString() ?? '';

      if (paymentUrl.isEmpty) {
        throw Exception('ToyyibPay payment URL missing');
      }

      setState(() {
        _lastPaymentUrl = paymentUrl;
        _lastBillCode = billCode;
      });

      final opened = await launchUrl(
        Uri.parse(paymentUrl),
        mode: LaunchMode.externalApplication,
      );

      if (!opened) {
        throw Exception('Could not open ToyyibPay payment page');
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'ToyyibPay opened. After payment, return here and tap "Check Payment Status".',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment error: $e')),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _checkPaymentStatus() async {
    setState(() => _checking = true);

    try {
      final res = await _dio.get(
        '/donations/${widget.donationId}/payment-status',
      );

      final data = (res.data as Map).cast<String, dynamic>();

      if (data['ok'] != true) {
        throw Exception(data['error'] ?? 'Failed to check payment status');
      }

      final payment = (data['payment'] as Map?)?.cast<String, dynamic>();

      final donationStatus =
          payment?['donation_status']?.toString().toUpperCase() ?? '';
      final paymentStatus =
          payment?['payment_status']?.toString().toUpperCase() ?? '';

      if (donationStatus == 'COMPLETED' || paymentStatus == 'PAID') {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment completed. Thank you for your donation! 💙'),
          ),
        );

        Navigator.of(context).pop(true);
        return;
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            paymentStatus.isEmpty
                ? 'Payment is not confirmed yet.'
                : 'Current payment status: $paymentStatus',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status check error: $e')),
      );
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _reopenPaymentPage() async {
    final url = _lastPaymentUrl;
    if (url == null || url.isEmpty) return;

    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );

    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not reopen ToyyibPay page')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final amountText =
        '${widget.currency} ${widget.amount.toStringAsFixed(2)}';

    return Scaffold(
      appBar: AppBar(
        title: Text('Payment · Donation #${widget.donationId}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(0),
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
                    Icons.favorite,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'You are donating',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 6),
                Text(
                  amountText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'for Donation #${widget.donationId}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 13,
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
                Row(
                  children: [
                    Icon(Icons.payment, color: colorScheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'ToyyibPay Online Payment',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                _ToyyibPayCard(
                  colorScheme: colorScheme,
                  billCode: _lastBillCode,
                ),

                const SizedBox(height: 12),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.secondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'You will be redirected to ToyyibPay sandbox payment page. After payment is confirmed by ToyyibPay callback, this donation will be marked as COMPLETED automatically.',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.primary.withOpacity(0.8),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                ElevatedButton.icon(
                  onPressed: _processing ? null : _payWithToyyibPay,
                  icon: _processing
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.open_in_new),
                  label: Text(
                    _processing
                        ? 'Opening ToyyibPay…'
                        : 'Pay with ToyyibPay $amountText',
                  ),
                ),

                const SizedBox(height: 10),

                OutlinedButton.icon(
                  onPressed: _checking ? null : _checkPaymentStatus,
                  icon: _checking
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(
                    _checking
                        ? 'Checking…'
                        : 'Check Payment Status',
                  ),
                ),

                if (_lastPaymentUrl != null) ...[
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: _reopenPaymentPage,
                    icon: const Icon(Icons.replay),
                    label: const Text('Reopen ToyyibPay Page'),
                  ),
                ],

                const SizedBox(height: 12),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 14,
                      color: colorScheme.onSurface.withOpacity(0.4),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Payment handled by ToyyibPay',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface.withOpacity(0.4),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToyyibPayCard extends StatelessWidget {
  final ColorScheme colorScheme;
  final String? billCode;

  const _ToyyibPayCard({
    required this.colorScheme,
    required this.billCode,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.primary.withOpacity(0.06),
        border: Border.all(
          color: colorScheme.primary,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.account_balance,
              color: colorScheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ToyyibPay Sandbox',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                  ),
                ),
                Text(
                  billCode == null || billCode!.isEmpty
                      ? 'Online banking payment simulation'
                      : 'Bill Code: $billCode',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withOpacity(0.55),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.check_circle,
            color: colorScheme.primary,
            size: 22,
          ),
        ],
      ),
    );
  }
}