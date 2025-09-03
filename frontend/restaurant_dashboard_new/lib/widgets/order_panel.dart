import 'package:flutter/material.dart';
import 'package:restaurant_dashboard_new/models/order.dart';
import 'package:restaurant_dashboard_new/services/order_service.dart';
import 'package:restaurant_dashboard_new/utils/currency_formatter.dart';

class OrderPanel extends StatefulWidget {
  final VoidCallback? onViewMorePressed;

  const OrderPanel({super.key, this.onViewMorePressed});

  @override
  State<OrderPanel> createState() => _OrderPanelState();
}

class _OrderPanelState extends State<OrderPanel> {
  late Future<List<Order>> _ordersFuture;
  final OrderService _orderService = OrderService();
  String _selectedFilter = 'All';
  List<Order> _allOrders = [];
  List<Order> _filteredOrders = [];
  List<Order> _displayedOrders = [];

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    try {
      final orders = await _orderService.getOrders();
      setState(() {
        _allOrders = orders;
        _applyFilter();
      });
    } catch (e) {
      // Handle error
    }
  }

  void _applyFilter() {
    setState(() {
      if (_selectedFilter == 'All') {
        _filteredOrders = _allOrders;
      } else {
        _filteredOrders = _allOrders.where((order) => order.status == _selectedFilter).toList();
      }
      _displayedOrders = _filteredOrders.take(5).toList();
    });
  }

  void _onFilterChanged(String filter) {
    setState(() {
      _selectedFilter = filter;
      _applyFilter();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final panelBackgroundColor = isDarkMode ? Colors.grey[850] : Colors.white;
    final cardBackgroundColor = isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100;
    final textColor = isDarkMode ? Colors.white : Colors.black;

    return Container(
      width: 350,
      color: panelBackgroundColor,
      padding: const EdgeInsets.all(24.0),
      child: _buildOrderMenuSection(textColor),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFC107),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Balance', style: TextStyle(color: Colors.black54)),
                    SizedBox(height: 4),
                    Text('\$12.000', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildBalanceButton(Icons.arrow_upward, 'Top Up'),
              _buildBalanceButton(Icons.swap_horiz, 'Transfer'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceButton(IconData icon, String label) {
    return Flexible(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.black, size: 18),
          ),
          const SizedBox(height: 4),
          Text(
            label, 
            style: const TextStyle(fontSize: 10, color: Colors.black87),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildOrderMenuSection(Color textColor) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Orders', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
              TextButton(
                onPressed: widget.onViewMorePressed,
                child: const Text('View More', style: TextStyle(color: Colors.orange)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildOrderFilters(),
          const SizedBox(height: 16),
          Expanded(
            child: _displayedOrders.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No ${_selectedFilter.toLowerCase()} orders',
                          style: TextStyle(color: Colors.grey[600], fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _displayedOrders.length,
                    itemBuilder: (context, index) {
                      final order = _displayedOrders[index];
                      return _buildOrderItem(order, textColor);
                    },
                  ),
          ),
        ],
      );
  }

  Widget _buildOrderFilters() {
    final filters = ['All', 'Pending', 'Accepted', 'Preparing', 'Ready', 'Delivered', 'Cancelled'];
    
    return Container(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _selectedFilter == filter;
          final count = filter == 'All' 
              ? _allOrders.length 
              : _allOrders.where((order) => order.status == filter).length;
          
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilterChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    filter,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[700],
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 12,
                    ),
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white.withOpacity(0.3) : Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        count.toString(),
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey[700],
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  _onFilterChanged(filter);
                }
              },
              backgroundColor: Colors.grey[100],
              selectedColor: _getFilterColor(filter),
              checkmarkColor: Colors.white,
              elevation: isSelected ? 2 : 0,
              pressElevation: 4,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          );
        },
      ),
    );
  }

  Color _getFilterColor(String filter) {
    switch (filter) {
      case 'Pending':
        return Colors.orange;
      case 'Accepted':
        return Colors.blue;
      case 'Preparing':
        return Colors.purple;
      case 'Ready':
        return Colors.green;
      case 'Delivered':
        return Colors.teal;
      case 'Cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildOrderItem(Order order, Color textColor) {
    // Displaying the first item of the order for simplicity
    final firstItem = order.items.isNotEmpty ? order.items.first : null;

    if (firstItem == null) {
      return const SizedBox.shrink(); // Don't build a row for an order with no items
    }

    // Safely parse the total price
    final double totalPrice = order.totalPrice;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                // Using a placeholder icon since imageUrl is not available in the model
                child: const Icon(Icons.fastfood, size: 60, color: Colors.grey),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(firstItem.menuItemName, style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                    const SizedBox(height: 4),
                    Text('x${firstItem.quantity}', style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
              Text(CurrencyFormatter.formatUGX(totalPrice), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
            ],
          ),
          const SizedBox(height: 10),
          // Show buttons only for 'Pending' orders
          if (order.status == 'Pending')
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => _updateOrderStatus(order.id, 'Accepted'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text('Accept'),
                ),
                ElevatedButton(
                  onPressed: () => _updateOrderStatus(order.id, 'Rejected'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Reject'),
                ),
              ],
            )
          else
            Text('Status: ${order.status}', style: TextStyle(color: textColor.withOpacity(0.7))), // Show current status if not pending
        ],
      ),
    );
  }

  void _updateOrderStatus(int orderId, String status) async {
    try {
      await _orderService.updateOrderStatus(orderId, status);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order has been $status')),
      );
      // Refresh the list of orders
      _loadOrders();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update order: $e')),
      );
    }
  }

  Widget _buildAddressCard(Color cardBackgroundColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBackgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.location_on_outlined, color: Colors.orangeAccent),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Home', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text('2118 Thornridge Cir. Syracuse, Connecticut 35624', overflow: TextOverflow.ellipsis, maxLines: 2, style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
          TextButton(
            onPressed: () {},
            child: const Text('View', style: TextStyle(color: Colors.orange)),
          )
        ],
      ),
    );
  }
}
