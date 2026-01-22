import 'package:flutter/material.dart';
import 'package:food_delivery_app/services/api_service.dart';
import 'package:food_delivery_app/models/order.dart';
import 'package:food_delivery_app/models/order_review.dart';
import 'package:food_delivery_app/screens/submit_review_screen.dart';
import 'package:food_delivery_app/widgets/error_display.dart';
import 'package:food_delivery_app/utils/currency_formatter.dart';
import 'package:intl/intl.dart';

import 'package:food_delivery_app/screens/order_tracking_screen.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  _OrderHistoryScreenState createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  List<Order> _orders = [];
  bool _isLoading = true;
  String? _errorMessage;
  final ApiService apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final orders = await apiService.fetchOrders();
      if (mounted) {
        setState(() {
          _orders = orders;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading order history: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load orders: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Orders', style: TextStyle(color: Colors.white)),
        backgroundColor: Color(0xFFfe5722),
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Container(
        color: Colors.grey[100],
        child: RefreshIndicator(
          onRefresh: _loadOrders,
          color: Colors.orange,
          backgroundColor: Colors.white,
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFfe5722)),
            ),
          ),
        ],
      );
    }

    if (_errorMessage != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          Center(
            child: ErrorDisplayWidget(
              errorMessage: _errorMessage!,
              onRetry: _loadOrders,
            ),
          ),
        ],
      );
    }

    if (_orders.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey[400]),
                SizedBox(height: 16),
                Text('No past orders found', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                SizedBox(height: 8),
                Text('Your orders will appear here', style: TextStyle(color: Colors.grey[500])),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(16.0),
      itemCount: _orders.length,
      separatorBuilder: (context, index) => SizedBox(height: 16),
      itemBuilder: (context, index) {
        return OrderCard(
          order: _orders[index],
          onRefresh: _loadOrders,
        );
      },
    );
  }
}

class OrderCard extends StatelessWidget {
  Widget _buildReviewSection(Order order, BuildContext context) {
    if (order.review == null) {
      return SizedBox.shrink();
    }

    final review = order.review!;

    return Container(
      padding: EdgeInsets.all(12),
      margin: EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Review',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 8),
          Row(
            children: List.generate(5, (index) {
              return Icon(
                index < review.rating ? Icons.star : Icons.star_border,
                color: Colors.amber,
                size: 20,
              );
            }),
          ),
          SizedBox(height: 4),
          Text(
            review.comment,
            style: TextStyle(color: Colors.grey[700]),
          ),
          if (review.replyText != null && review.replyText!.isNotEmpty)
            _buildRestaurantReply(review),
        ],
      ),
    );
  }

  Widget _buildRestaurantReply(OrderReview review) {
    return Container(
      padding: EdgeInsets.all(12),
      margin: EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: Color(0xFFfe5722).withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Color(0xFFfe5722).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Restaurant Reply',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFFfe5722),
            ),
          ),
          SizedBox(height: 8),
          Text(
            review.replyText!,
            style: TextStyle(color: Colors.grey[800]),
          ),
          SizedBox(height: 8),
          if (review.repliedAt != null)
            Text(
              DateFormat.yMMMd().format(review.repliedAt!),
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
        ],
      ),
    );
  }
  final Order order;
  final VoidCallback onRefresh;

  const OrderCard({required this.order, required this.onRefresh});

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return Colors.green;
      case 'pending':
      case 'preparing':
      case 'ready for pickup':
        return Color(0xFFfe5722);
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('MMM dd, yyyy - hh:mm a').format(DateTime.parse(order.createdAt));
    final isDelivered = order.status.toLowerCase() == 'delivered';

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      order.restaurant.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(order.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      order.status,
                      style: TextStyle(
                        color: _getStatusColor(order.status),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Order #${order.id}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  Text(
                    CurrencyFormatter.formatUGX(double.tryParse(order.totalPrice) ?? 0.0),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0).copyWith(bottom: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Divider(height: 1, color: Colors.grey[200]),
                SizedBox(height: 12),
                Text(
                  'Order Items',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 8),
                ...order.items.map((item) => Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        '${item.quantity}x',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.menuItem.name,
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      Text(
                        CurrencyFormatter.formatUGX(double.tryParse(item.price) ?? 0.0),
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )),
                _buildReviewSection(order, context),
                SizedBox(height: 12),
                if (isDelivered && order.review == null)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFfe5722),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () async {
                        final result = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SubmitReviewScreen(
                              orderId: order.id,
                              riderId: order.riderId,
                            ),
                          ),
                        );
                        if (result == true) {
                          onRefresh();
                        }
                      },
                      child: Text('Rate This Order'),
                    ),
                  )
                else if (!isDelivered && order.status.toLowerCase() != 'cancelled')
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Color(0xFFfe5722),
                        side: BorderSide(color: Color(0xFFfe5722)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => OrderTrackingScreen(order: order),
                          ),
                        );
                      },
                      child: Text('Track Order'),
                    ),
                  ),
              ],
            ),
          )
        ],
      ),
    );
  }
}