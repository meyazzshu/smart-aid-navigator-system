import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/auth_controller.dart';
import '../profile/account_profile_api.dart';
import '../profile/account_profile_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

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

            return _NgoProfileHeader(
              profile: profile,
              loading: snapshot.connectionState != ConnectionState.done,
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
          'Account',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: colorScheme.primary,
            fontSize: 16,
          ),
        ),

        const SizedBox(height: 8),

        Card(
          child: Column(
            children: [
              ListTile(
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: colorScheme.error.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(Icons.logout, color: colorScheme.error),
                ),
                title: const Text(
                  'Logout',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text('Sign out from this device'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => ref.read(authControllerProvider.notifier).logout(),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(Icons.info_outline, color: colorScheme.primary),
                ),
                title: const Text(
                  'About',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text('Smart Aid Navigator (SAN)'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NgoProfileHeader extends StatelessWidget {
  final AccountProfile? profile;
  final bool loading;
  final VoidCallback onView;
  final VoidCallback onEdit;

  const _NgoProfileHeader({
    required this.profile,
    required this.loading,
    required this.onView,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final org = profile?.organization;
    final orgName = org?['ngo_name']?.toString() ??
        org?['shelter_name']?.toString() ??
        'No assigned organisation';
    final staffTitle = org?['staff_title']?.toString() ?? '';

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: loading
          ? const SizedBox(
              height: 130,
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 31,
                      backgroundColor: colorScheme.primary.withOpacity(0.12),
                      child: Text(
                        profile?.initials ?? 'U',
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile?.fullName.trim().isNotEmpty == true
                                ? profile!.fullName
                                : 'My Account',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            profile?.email.trim().isNotEmpty == true
                                ? profile!.email
                                : 'No email available',
                            style: TextStyle(
                              color: colorScheme.onSurface.withOpacity(0.62),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colorScheme.primary.withOpacity(0.12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.business_center_outlined, color: colorScheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              orgName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              staffTitle.isEmpty
                                  ? profile?.displayRole ?? 'Staff'
                                  : staffTitle,
                              style: TextStyle(
                                color: colorScheme.onSurface.withOpacity(0.58),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _MiniMetric(
                        label: 'Profile',
                        value: '${profile?.completionPercent ?? 0}%',
                        icon: Icons.verified_user_outlined,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MiniMetric(
                        label: 'Phone',
                        value: profile?.phone.trim().isNotEmpty == true
                            ? 'Added'
                            : 'Missing',
                        icon: Icons.phone_outlined,
                      ),
                    ),
                  ],
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
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MiniMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.secondary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: colorScheme.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.55),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}