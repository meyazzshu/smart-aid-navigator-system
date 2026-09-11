import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../../core/app_theme.dart';
import '../../core/dio_client.dart';
import 'create_donation_page.dart';
import 'my_donations_page.dart';
import 'donation_detail_page.dart';

class DonationHubPage extends StatefulWidget {
  const DonationHubPage({super.key});

  @override
  State<DonationHubPage> createState() => _DonationHubPageState();
}

class _DonationHubPageState extends State<DonationHubPage> {
  final Dio _dio = DioClient.create();
  late Future<List<Map<String, dynamic>>> _recentFuture;

  @override
  void initState() {
    super.initState();
    _recentFuture = _loadRecent();
  }

  Future<List<Map<String, dynamic>>> _loadRecent() async {
    try {
      final res = await _dio.get('/donations/my');
      final data = (res.data as Map).cast<String, dynamic>();
      if (data['ok'] != true) return [];
      final list = (data['donations'] as List)
          .cast<dynamic>()
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();
      return list.take(5).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _refresh() async {
    setState(() => _recentFuture = _loadRecent());
    await _recentFuture;
  }

  void _goToCreate({String type = 'ITEM'}) {
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => CreateDonationPage(initialType: type),
        ))
        .then((_) => _refresh());
  }

  void _goToMyDonations() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const MyDonationsPage()))
        .then((_) => _refresh());
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeroHeader(colorScheme)),
          SliverToBoxAdapter(child: _buildActionCards(colorScheme)),
          SliverToBoxAdapter(child: _buildHowItWorks(colorScheme)),
          SliverToBoxAdapter(child: _buildRecentDonations(colorScheme)),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  // ─── Hero Header ─────────────────────────────────────────────────────────────

  Widget _buildHeroHeader(ColorScheme colorScheme) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.darkAzure, AppColors.azure],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon badge
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.volunteer_activism, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 16),
          const Text(
            'Make a Difference',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your generosity brings hope to those in need. Every contribution counts.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          // Stats row
          Row(
            children: [
              _HeroStat(icon: Icons.favorite, label: 'Lives Helped', value: '1,200+'),
              const SizedBox(width: 12),
              _HeroStat(icon: Icons.inventory_2_outlined, label: 'Items Donated', value: '5,400+'),
              const SizedBox(width: 12),
              _HeroStat(icon: Icons.account_balance_wallet_outlined, label: 'Funds Raised', value: 'RM 80K+'),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Action Cards ─────────────────────────────────────────────────────────────

  Widget _buildActionCards(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title: 'How Would You Like to Help?', colorScheme: colorScheme),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _DonateActionCard(
                  icon: Icons.account_balance_wallet,
                  label: 'Donate\nMoney',
                  subtitle: 'Fund relief efforts',
                  gradientColors: const [Color(0xFF1565C0), Color(0xFF42A5F5)],
                  onTap: () => _goToCreate(type: 'MONEY'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DonateActionCard(
                  icon: Icons.inventory_2,
                  label: 'Donate\nItems',
                  subtitle: 'Food, clothes & more',
                  gradientColors: const [Color(0xFF03466E), Color(0xFF54AFE6)],
                  onTap: () => _goToCreate(type: 'ITEM'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ViewMyDonationsCard(onTap: _goToMyDonations, colorScheme: colorScheme),
        ],
      ),
    );
  }

  // ─── How It Works ─────────────────────────────────────────────────────────────

  Widget _buildHowItWorks(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title: 'How It Works', colorScheme: colorScheme),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _HowItWorksStep(
                    step: '1',
                    icon: Icons.add_circle_outline,
                    title: 'Choose Your Donation Type',
                    description: 'Select whether you want to donate money or physical items to help those affected.',
                    colorScheme: colorScheme,
                  ),
                  _StepDivider(colorScheme: colorScheme),
                  _HowItWorksStep(
                    step: '2',
                    icon: Icons.storefront_outlined,
                    title: 'Pick an NGO',
                    description: 'Optionally choose a specific NGO to direct your donation to, or leave it for general use.',
                    colorScheme: colorScheme,
                  ),
                  _StepDivider(colorScheme: colorScheme),
                  _HowItWorksStep(
                    step: '3',
                    icon: Icons.local_shipping_outlined,
                    title: 'Deliver or Transfer',
                    description: 'Drop off items at the NGO location or complete a money transfer via our secure payment system.',
                    colorScheme: colorScheme,
                  ),
                  _StepDivider(colorScheme: colorScheme),
                  _HowItWorksStep(
                    step: '4',
                    icon: Icons.check_circle_outline,
                    title: 'Track Your Impact',
                    description: 'Monitor the status of your donations and see how your contributions are making an impact.',
                    colorScheme: colorScheme,
                    isLast: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Recent Donations ─────────────────────────────────────────────────────────

  Widget _buildRecentDonations(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SectionTitle(title: 'My Recent Donations', colorScheme: colorScheme),
              TextButton.icon(
                onPressed: _goToMyDonations,
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text('See All'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _recentFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              final list = snapshot.data ?? [];
              if (list.isEmpty) {
                return _EmptyDonationsCard(
                  onTap: () => _goToCreate(),
                  colorScheme: colorScheme,
                );
              }
              return Column(
                children: list.map((d) {
                  final id = (d['donation_id'] as num).toInt();
                  final type = d['donation_type']?.toString() ?? '';
                  final status = d['status']?.toString() ?? '';
                  final ngo = d['ngo_name']?.toString() ?? '';
                  return _DonationRecentCard(
                    id: id,
                    type: type,
                    status: status,
                    ngo: ngo,
                    colorScheme: colorScheme,
                    onTap: () {
                      Navigator.of(context)
                          .push(MaterialPageRoute(
                            builder: (_) => DonationDetailPage(donationId: id),
                          ))
                          .then((_) => _refresh());
                    },
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── Supporting Widgets ───────────────────────────────────────────────────────

class _HeroStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _HeroStat({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final ColorScheme colorScheme;

  const _SectionTitle({required this.title, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: colorScheme.primary,
      ),
    );
  }
}

class _DonateActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const _DonateActionCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.gradientColors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 130,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: gradientColors.last.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: 32),
            const Spacer(),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewMyDonationsCard extends StatelessWidget {
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  const _ViewMyDonationsCard({required this.onTap, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.history, color: colorScheme.primary),
        ),
        title: const Text('My Donations', style: TextStyle(fontWeight: FontWeight.w700)),
        subtitle: const Text('View and track all your past donations'),
        trailing: Icon(Icons.chevron_right, color: colorScheme.primary),
      ),
    );
  }
}

class _HowItWorksStep extends StatelessWidget {
  final String step;
  final IconData icon;
  final String title;
  final String description;
  final ColorScheme colorScheme;
  final bool isLast;

  const _HowItWorksStep({
    required this.step,
    required this.icon,
    required this.title,
    required this.description,
    required this.colorScheme,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: colorScheme.secondary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Step $step',
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(title,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 3),
              Text(
                description,
                style: TextStyle(
                  color: colorScheme.onSurface.withOpacity(0.65),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              if (!isLast) const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepDivider extends StatelessWidget {
  final ColorScheme colorScheme;
  const _StepDivider({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 19),
        Container(
          width: 2,
          height: 16,
          color: colorScheme.secondary.withOpacity(0.3),
        ),
        const Spacer(),
      ],
    );
  }
}

class _EmptyDonationsCard extends StatelessWidget {
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  const _EmptyDonationsCard({required this.onTap, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.volunteer_activism, size: 56, color: colorScheme.secondary.withOpacity(0.6)),
            const SizedBox(height: 12),
            Text(
              'No donations yet',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Start making a difference today. Your first donation can change someone\'s life.',
              style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6), fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.add),
              label: const Text('Make My First Donation'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DonationRecentCard extends StatelessWidget {
  final int id;
  final String type;
  final String status;
  final String ngo;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  const _DonationRecentCard({
    required this.id,
    required this.type,
    required this.status,
    required this.ngo,
    required this.colorScheme,
    required this.onTap,
  });

  Color _statusColor() {
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

  IconData _typeIcon() {
    return type == 'MONEY' ? Icons.account_balance_wallet : Icons.inventory_2;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(_typeIcon(), color: colorScheme.primary),
        ),
        title: Text(
          'Donation #$id  •  ${type == 'MONEY' ? 'Money' : 'Items'}',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        subtitle: Text(ngo.isNotEmpty ? ngo : 'General Donation'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _statusColor().withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: _statusColor(),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Icon(Icons.chevron_right, color: colorScheme.primary, size: 16),
          ],
        ),
      ),
    );
  }
}
