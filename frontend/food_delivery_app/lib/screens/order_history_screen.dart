import 'package:flutter/material.dart';
import 'package:food_delivery_app/models/order.dart';
import 'package:food_delivery_app/services/api_service.dart';
import 'package:food_delivery_app/widgets/rating_dialog.dart';
import 'package:intl/intl.dart';
import 'package:food_delivery_app/models/order_item.dart';
import 'package:food_delivery_app/screens/order_tracking_screen.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  _OrderHistoryScreenState createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  late Future<List<Order>> futureOrders;
  final ApiService apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  void _loadOrders() {
    setState(() {
      futureOrders = apiService.fetchOrders();
    });
  }

  void _showRatingDialog(BuildContext context, OrderItem item) {
    showDialog(
      context: context,
      builder: (context) => RatingDialog(
        mealName: item.menuItem.name,
        onSubmit: (rating, comment) async {
          try {
            await apiService.submitReview(item.menuItem.id, rating, comment);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Review submitted successfully!'), backgroundColor: Colors.green),
            );
            // Optionally, refresh the order or item state to show it's been reviewed
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to submit review: ${e.toString()}'), backgroundColor: Colors.red),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Orders'),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async => _loadOrders(),
        child: FutureBuilder<List<Order>>(
          future: futureOrders,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Error loading orders. Pull to refresh.'));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey[400]),
                    SizedBox(height: 16),
                    Text('No past orders found', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                  ],
                ),
              );
            } else {
              final orders = snapshot.data!;
              return ListView.builder(
                padding: EdgeInsets.all(8.0),
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  return _OrderCard(
                    order: orders[index],
                    onRate: (item) => _showRatingDialog(context, item),
                  );
                },
              );
            }
          },
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;
  final Function(OrderItem) onRate;

  const _OrderCard({required this.order, required this.onRate});

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return Colors.green;
      case 'pending':
      case 'preparing':
      case 'ready for pickup':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat.yMMMd().format(DateTime.parse(order.createdAt));

    return Card(
      margin: EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              order.restaurant.name,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 4),
            Text(
              'Order #${order.id} - $formattedDate',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '\$${order.totalPrice}',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _getStatusColor(order.status),
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 4),
                Text(
                  order.status,
                  style: TextStyle(color: _getStatusColor(order.status), fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
        children: [
          Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                ...order.items.map((item) => _OrderItemRow(item: item, orderStatus: order.status, onRate: () => onRate(item))),
                SizedBox(height: 12),
                Text('Delivery Address:', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text(order.deliveryAddress, style: TextStyle(color: Colors.grey[700])),
                if (order.status.toLowerCase() != 'delivered' && order.status.toLowerCase() != 'cancelled') ...[
                  SizedBox(height: 16),
                  Center(
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.location_on_outlined, size: 18),
                      label: Text('Track Live Location'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => OrderTrackingScreen(order: order),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderItemRow extends StatelessWidget {
  final OrderItem item;
  final String orderStatus;
  final VoidCallback onRate;

  const _OrderItemRow({required this.item, required this.orderStatus, required this.onRate});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${item.quantity} x ${item.menuItem.name}'),
                Text('\$${item.price}', style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          ),
          if (orderStatus.toLowerCase() == 'delivered')
            TextButton(
              onPressed: onRate,
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text('Rate'),
            ),
        ],
      ),
    );
  }
}
