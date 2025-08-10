import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:restaurant_dashboard_new/models/bill.dart';
import 'package:restaurant_dashboard_new/services/bill_service.dart';

class BillsScreen extends StatefulWidget {
  @override
  _BillsScreenState createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen> {
  final BillService _billService = BillService();
  late Future<List<Bill>> _billsFuture;

  @override
  void initState() {
    super.initState();
    _billsFuture = _billService.fetchBills();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bills & Payouts'),
      ),
      body: FutureBuilder<List<Bill>>(
        future: _billsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No bills found.'));
          } else {
            return ListView.builder(
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final bill = snapshot.data![index];
                return Card(
                  margin: EdgeInsets.all(8.0),
                  child: ListTile(
                    leading: Icon(
                      bill.status == 'paid' ? Icons.check_circle : Icons.hourglass_top,
                      color: bill.status == 'paid' ? Colors.green : Colors.orange,
                    ),
                    title: Text('Bill #${bill.id} - \$${bill.amount.toStringAsFixed(2)}'),
                    subtitle: Text('Status: ${bill.status}'),
                    trailing: Text(DateFormat.yMMMd().format(bill.createdAt)),
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}
