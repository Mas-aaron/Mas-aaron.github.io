import 'package:flutter/material.dart';
import '../services/loyalty_service.dart';
import '../models/loyalty/loyalty_profile.dart';
import '../models/loyalty/reward.dart';
import '../models/loyalty/points_transaction.dart';

class LoyaltyDashboardScreen extends StatefulWidget {
  @override
  _LoyaltyDashboardScreenState createState() => _LoyaltyDashboardScreenState();
}

class _LoyaltyDashboardScreenState extends State<LoyaltyDashboardScreen> {
  final LoyaltyService _loyaltyService = LoyaltyService();
  late Future<LoyaltyProfile> _loyaltyProfileFuture;
  late Future<List<Reward>> _rewardsFuture;
  late Future<List<PointsTransaction>> _transactionsFuture;

  @override
  void initState() {
    super.initState();
    _loyaltyProfileFuture = _loyaltyService.getLoyaltyProfile();
    _rewardsFuture = _loyaltyService.getAvailableRewards();
    _transactionsFuture = _loyaltyService.getTransactionHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Loyalty Dashboard'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileSection(),
            SizedBox(height: 24),
            _buildRewardsSection(),
            SizedBox(height: 24),
            _buildHistorySection(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSection() {
    return FutureBuilder<LoyaltyProfile>(
      future: _loyaltyProfileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }
        final profile = snapshot.data!;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text('Current Tier: ${profile.tier}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('Points: ${profile.points}'),
                SizedBox(height: 8),
                if (profile.nextTier != null) ...[
                  Text('Next Tier: ${profile.nextTier}'),
                  SizedBox(height: 8),
                  LinearProgressIndicator(value: profile.progress / 100),
                ],
                SizedBox(height: 8),
                Text('Benefits: ${profile.benefits}'),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRewardsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Available Rewards', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        FutureBuilder<List<Reward>>(
          future: _rewardsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            }
            final rewards = snapshot.data!;
            return ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: rewards.length,
              itemBuilder: (context, index) {
                final reward = rewards[index];
                return Card(
                  child: ListTile(
                    title: Text(reward.name),
                    subtitle: Text('${reward.pointsRequired} points'),
                    trailing: ElevatedButton(
                      onPressed: () async {
                        try {
                          await _loyaltyService.redeemReward(reward.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Reward redeemed successfully!')),
                          );
                          setState(() {
                            _loyaltyProfileFuture = _loyaltyService.getLoyaltyProfile();
                            _rewardsFuture = _loyaltyService.getAvailableRewards();
                          });
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to redeem reward')),
                          );
                        }
                      },
                      child: Text('Redeem'),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Transaction History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        FutureBuilder<List<PointsTransaction>>(
          future: _transactionsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            }
            final transactions = snapshot.data!;
            return ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: transactions.length,
              itemBuilder: (context, index) {
                final transaction = transactions[index];
                return Card(
                  child: ListTile(
                    title: Text(transaction.description),
                    subtitle: Text('${transaction.createdAt}'),
                    trailing: Text(
                      '${transaction.points > 0 ? '+' : ''}${transaction.points}',
                      style: TextStyle(
                        color: transaction.points > 0 ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
