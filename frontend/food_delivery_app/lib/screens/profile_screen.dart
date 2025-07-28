import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Account'),
        backgroundColor: Colors.orange,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.orange[100],
              child: const Icon(Icons.person, size: 50, color: Colors.orange),
            ),
            const SizedBox(height: 16),
            const Text(
              'User Name',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'user@email.com',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            Card(
              child: ListTile(
                leading: Icon(Icons.history, color: Colors.orange),
                title: const Text('Order History'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // Navigate to order history
                },
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: Icon(Icons.location_on, color: Colors.orange),
                title: const Text('Saved Addresses'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // Navigate to addresses
                },
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: Icon(Icons.payment, color: Colors.orange),
                title: const Text('Payment Methods'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // Navigate to payment methods
                },
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: Icon(Icons.settings, color: Colors.orange),
                title: const Text('Settings'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // Navigate to settings
                },
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: Icon(Icons.developer_mode, color: Colors.orange),
                title: const Text('WebSocket Test'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // Navigate to WebSocket test screen
                  Navigator.pushNamed(context, '/ws-test');
                },
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Provider.of<AuthProvider>(context, listen: false).logout();
              },
              child: const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }
}
