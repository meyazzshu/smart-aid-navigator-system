import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../profile/account_profile_api.dart';
import '../profile/account_profile_page.dart';
import '../shell/app_shell.dart';
import 'create_donation_page.dart';
import 'my_dependents_page.dart';
import 'my_donations_page.dart';
import 'my_aid_requests_page.dart';

class PublicHomePage extends ConsumerWidget {
  const PublicHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FutureBuilder<AccountProfile>(
          future: AccountProfileApi().getMyProfile(),
          builder: (context, snapshot) {
            final profile = snapshot.data;

            return _ProfilePreviewCard(
              profile: profile,
              loading: snapshot.connectionState != ConnectionState.done,
              title: 'My Profile',
              subtitle: 'Personal details used for donations and PPS bookings',
              accentIcon: Icons.person_outline,
              onView: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AccountProfilePage(),
                  ),
                );
              },
              onEdit: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AccountProfilePage(startInEditMode: true),
                  ),
                );
              },
            );
          },
        ),

        const SizedBox(height: 18),

        Text(
          'Public Services',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Manage your aid requests, donations, dependents, and nearby support.',
          style: TextStyle(color: colorScheme.onSurface.withValues(alpha:0.65)),
        ),
        const SizedBox(height: 14),

        Card(
          child: Column(
            children: [
              _MenuTile(
                icon: Icons.handshake_outlined,
                title: 'My Aid Requests',
                subtitle: 'Submit and track aid requests as a beneficiary',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MyAidRequestsPage()),
                  );
                },
              ),
              const Divider(height: 1),
              _MenuTile(
                icon: Icons.volunteer_activism,
                title: 'My Donations',
                subtitle: 'Track and confirm your ongoing donations',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MyDonationsPage()),
                  );
                },
              ),
              const Divider(height: 1),
              _MenuTile(
                icon: Icons.add_circle_outline,
                title: 'Create Donation',
                subtitle: 'Donate items or monetary aid to NGOs',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CreateDonationPage()),
                  );
                },
              ),
              const Divider(height: 1),
              _MenuTile(
                icon: Icons.groups_outlined,
                title: 'My Dependents',
                subtitle: 'Save and manage dependents under your account',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MyDependentsPage()),
                  );
                },
              ),
              const Divider(height: 1),
              _MenuTile(
                icon: Icons.map_outlined,
                title: 'View Aid Map',
                subtitle: 'Find nearby shelters and NGOs',
                onTap: () {
                  AppTabController.openMapTab();
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        Card(
          child: ListTile(
            leading: Icon(Icons.info_outline, color: colorScheme.secondary),
            title: const Text(
              'Need assistance?',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: const Text(
              'Use the map tab to request PPS slots or get directions.',
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfilePreviewCard extends StatelessWidget {
  final AccountProfile? profile;
  final bool loading;
  final String title;
  final String subtitle;
  final IconData accentIcon;
  final VoidCallback onView;
  final VoidCallback onEdit;

  const _ProfilePreviewCard({
    required this.profile,
    required this.loading,
    required this.title,
    required this.subtitle,
    required this.accentIcon,
    required this.onView,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final name = profile?.fullName.trim().isNotEmpty == true
        ? profile!.fullName
        : 'My Profile';
    final email = profile?.email.trim().isNotEmpty == true
        ? profile!.email
        : 'No email available';
    final phone = profile?.phone.trim().isNotEmpty == true
        ? profile!.phone
        : 'No phone yet';
    final location = [
      profile?.city ?? '',
      profile?.state ?? '',
    ].where((x) => x.trim().isNotEmpty).join(', ');

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha:0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: loading
            ? const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: colorScheme.primary.withValues(alpha:0.12),
                        child: Text(
                          profile?.initials ?? 'U',
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w900,
                            fontSize: 19,
                          ),
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 17,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              email,
                              style: TextStyle(
                                color: colorScheme.onSurface.withValues(alpha:0.62),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: colorScheme.secondary.withValues(alpha:0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(accentIcon, color: colorScheme.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _MiniInfoPill(
                          icon: Icons.phone_outlined,
                          label: phone,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _MiniInfoPill(
                          icon: Icons.location_on_outlined,
                          label: location.isEmpty ? 'No location' : location,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: (profile?.completionPercent ?? 0) / 100,
                      minHeight: 7,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Profile completion: ${profile?.completionPercent ?? 0}%',
                    style: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha:0.58),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onView,
                          icon: const Icon(Icons.visibility_outlined),
                          label: const Text('View'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: onEdit,
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Update'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

class _MiniInfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MiniInfoPill({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha:0.06),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: colorScheme.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha:0.08),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon, color: colorScheme.primary),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}