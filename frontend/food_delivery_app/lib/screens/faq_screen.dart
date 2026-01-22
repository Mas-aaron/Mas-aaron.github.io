import 'package:flutter/material.dart';

class FAQScreen extends StatelessWidget {
  const FAQScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <({String q, String a})>[
      (
        q: 'How do I place an order?',
        a: 'Browse restaurants, add items to your cart, then proceed to checkout to place your order.'
      ),
      (
        q: 'How can I track my order?',
        a: 'Open My Orders from your profile and select an active order to track it.'
      ),
      (
        q: 'Can I cancel an order?',
        a: 'If the restaurant has not started preparing your order, cancellation may be possible. Contact support if needed.'
      ),
      (
        q: 'How do promo codes work?',
        a: 'Enter your promo code at checkout to apply discounts when available.'
      ),
      (
        q: 'How do I update my address?',
        a: 'Go to your Profile and manage your addresses from the address section.'
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('F.A.Q.'),
        backgroundColor: const Color(0xFFfe5722),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF8F9FA),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = items[index];
          return Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              title: Text(
                item.q,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    item.a,
                    style: TextStyle(color: Colors.grey.shade700, height: 1.4),
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
