import 'package:flutter/material.dart';
import 'deliveries_page.dart';
import 'ngo_donations_page.dart';
import 'delivery_groups_page.dart';
import 'unmet_beneficiary_needs_page.dart';


//tak pakai page ni

class NgoHomePage extends StatelessWidget {
  const NgoHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.local_shipping),
              label: const Text('Manage Deliveries'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DeliveriesPage()),
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.inbox),
              label: const Text('Incoming Donations'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NgoDonationsPage()),
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          Card(
            child: ListTile(
              leading: const Icon(Icons.route),
              title: const Text('Group Deliveries'),
              subtitle: const Text('Optimize multi-stop delivery route'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const DeliveryGroupsPage(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}