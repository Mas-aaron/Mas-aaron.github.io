import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:restaurant_dashboard_new/models/order.dart';
import 'package:restaurant_dashboard_new/services/order_service.dart';
import 'package:restaurant_dashboard_new/services/websocket_service.dart';
import 'package:restaurant_dashboard_new/utils/currency_formatter.dart';

class OrderManagementScreen extends StatefulWidget {
  const OrderManagementScreen({super.key});

  @override
  State<OrderManagementScreen> createState() => _OrderManagementScreenState();
}

class _OrderManagementScreenState extends State<OrderManagementScreen> {
  List<Order> _allOrders = [];
  List<Order> _filteredOrders = [];
  bool _isLoading = true;
  String? _error;
  String _selectedFilter = 'All';
  final OrderService _orderService = OrderService();
  WebSocketService? _webSocketService;
  bool _hasNewNotification = false;
  Set<int> _expandedOrders = {};

  @override
  void initState() {
    super.initState();
    _fetchOrders();
    _initializeWebSocket();
  }

  void _initializeWebSocket() {
    _webSocketService = WebSocketService(
      onMessageReceived: _handleWebSocketMessage,
    );
    // Using a sample token - in production, get this from authentication
    _webSocketService!.connect('1bacbbe29dbf384e7b1b56eff9fe3b66a9e5e562');
  }

  void _handleWebSocketMessage(Map<String, dynamic> message) {
    if (message['type'] == 'new_order') {
      setState(() {
        _hasNewNotification = true;
      });
      
      // Show notification
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.notifications_active, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'New order received! Order #${message['order_id'] ?? 'Unknown'}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.orange.shade600,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'View',
              textColor: Colors.white,
              onPressed: () {
                _fetchOrders(); // Refresh orders
                setState(() {
                  _hasNewNotification = false;
                });
              },
            ),
          ),
        );
      }
      
      // Auto-refresh orders after a short delay
      Future.delayed(const Duration(seconds: 1), () {
        _fetchOrders();
      });
    }
  }

  Future<void> _fetchOrders() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      print('🔄 Fetching orders from API...');
      final orders = await _orderService.getOrders();
      print('✅ Fetched ${orders.length} orders successfully');
      
      setState(() {
        _allOrders = orders;
        _applyFilter();
        _isLoading = false;
        _hasNewNotification = false; // Clear notification flag when orders are refreshed
      });
      
      print('📊 After filter: ${_filteredOrders.length} orders displayed');
    } catch (e) {
      print('❌ Error fetching orders: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _applyFilter() {
    setState(() {
      if (_selectedFilter == 'All') {
        _filteredOrders = _allOrders;
      } else {
        _filteredOrders = _allOrders.where((order) => order.status == _selectedFilter).toList();
      }
      print('🔍 Applied filter "$_selectedFilter": ${_filteredOrders.length}/${_allOrders.length} orders');
    });
  }

  void _onFilterChanged(String filter) {
    setState(() {
      _selectedFilter = filter;
      _applyFilter();
    });
  }

  Future<void> _updateOrderStatus(int orderId, String status) async {
    try {
      await _orderService.updateOrderStatus(orderId, status);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order #$orderId has been $status'), backgroundColor: Colors.green),
      );
      _fetchOrders(); // Refresh the list
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update order status: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _exportOrdersToCSV() {
    if (_filteredOrders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No orders to export'), backgroundColor: Colors.orange),
      );
      return;
    }

    final csvData = _generateCSVData();
    Clipboard.setData(ClipboardData(text: csvData));
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('CSV data copied to clipboard! Paste into Excel or Google Sheets.'),
        backgroundColor: Colors.green,
        action: SnackBarAction(
          label: 'View Data',
          textColor: Colors.white,
          onPressed: () => _showDataPreview(csvData),
        ),
      ),
    );
  }

  String _generateCSVData() {
    final headers = [
      'Order ID',
      'Customer',
      'Status',
      'Order Type',
      'Total Price',
      'Items',
      'Created At',
      'Delivery Address',
      'Tip Amount'
    ];

    final rows = _filteredOrders.map((order) {
      final itemsText = order.items.map((item) => '${item.menuItemName} (x${item.quantity})').join('; ');
      return [
        order.id.toString(),
        order.customerName,
        order.status,
        order.orderType ?? 'delivery',
        order.totalPrice.toString(),
        itemsText,
        order.createdAt.toString(),
        order.deliveryAddress ?? '',
        order.tipAmount?.toString() ?? '0'
      ];
    }).toList();

    final csvContent = [headers, ...rows]
        .map((row) => row.map((cell) => '"${cell.toString().replaceAll('"', '""')}"').join(','))
        .join('\n');

    return csvContent;
  }

  void _printOrders() {
    if (_filteredOrders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No orders to print'), backgroundColor: Colors.orange),
      );
      return;
    }

    final printData = _generatePrintData();
    Clipboard.setData(ClipboardData(text: printData));
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Print-ready data copied to clipboard!'),
        backgroundColor: Colors.green,
        action: SnackBarAction(
          label: 'View',
          textColor: Colors.white,
          onPressed: () => _showDataPreview(printData),
        ),
      ),
    );
  }

  void _showDataPreview(String data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Data Preview'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: SelectableText(
              data,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: data));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Data copied to clipboard!')),
              );
            },
            child: const Text('Copy Again'),
          ),
        ],
      ),
    );
  }

  String _generatePrintData() {
    final now = DateTime.now();
    final dateStr = '${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute.toString().padLeft(2, '0')}';
    
    final buffer = StringBuffer();
    buffer.writeln('🍽️ FORTEXPRESS RESTAURANT');
    buffer.writeln('Orders Report - $_selectedFilter Filter');
    buffer.writeln('Generated on: $dateStr');
    buffer.writeln('=' * 60);
    buffer.writeln();
    buffer.writeln('SUMMARY:');
    buffer.writeln('Total Orders: ${_filteredOrders.length}');
    buffer.writeln('Total Revenue: ${CurrencyFormatter.formatUGX(_filteredOrders.fold(0.0, (sum, order) => sum + order.totalPrice))}');
    buffer.writeln();
    buffer.writeln('=' * 60);
    buffer.writeln();

    for (final order in _filteredOrders) {
      buffer.writeln('ORDER #${order.id}');
      buffer.writeln('-' * 40);
      buffer.writeln('Customer: ${order.customerName}');
      buffer.writeln('Status: ${order.status}');
      buffer.writeln('Order Type: ${order.orderType ?? 'delivery'}');
      if (order.deliveryAddress?.isNotEmpty == true) {
        buffer.writeln('Address: ${order.deliveryAddress}');
      }
      if (order.tipAmount != null && order.tipAmount! > 0) {
        buffer.writeln('Tip: ${CurrencyFormatter.formatUGX(order.tipAmount!)}');
      }
      buffer.writeln('Total: ${CurrencyFormatter.formatUGX(order.totalPrice)}');
      buffer.writeln('Created: ${order.createdAt}');
      buffer.writeln();
      buffer.writeln('ITEMS:');
      for (final item in order.items) {
        buffer.writeln('  • ${item.menuItemName} x${item.quantity} - ${CurrencyFormatter.formatUGX(item.price)}');
      }
      buffer.writeln();
      buffer.writeln('=' * 60);
      buffer.writeln();
    }

    return buffer.toString();
  }

  IconData _getOrderTypeIcon(String orderType) {
    switch (orderType.toLowerCase()) {
      case 'delivery':
        return Icons.delivery_dining;
      case 'pickup':
        return Icons.store;
      case 'dine-in':
        return Icons.restaurant;
      default:
        return Icons.shopping_bag;
    }
  }

  Color _getOrderTypeColor(String orderType) {
    switch (orderType.toLowerCase()) {
      case 'delivery':
        return Colors.blue;
      case 'pickup':
        return Colors.green;
      case 'dine-in':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF7F7F7),
      child: Column(
        children: [
          _buildHeader(),
          _buildFilterSection(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: Row(
                    children: [
                      Text(
                        'Order Management',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      if (_hasNewNotification) ...[
                        const SizedBox(width: 12),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.orange.shade600,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                      const Spacer(),
                      IconButton(
                        onPressed: _exportOrdersToCSV,
                        icon: Icon(
                          Icons.download,
                          color: Colors.grey[600],
                        ),
                        tooltip: 'Export to CSV',
                      ),
                      IconButton(
                        onPressed: _printOrders,
                        icon: Icon(
                          Icons.print,
                          color: Colors.grey[600],
                        ),
                        tooltip: 'Print Orders',
                      ),
                      IconButton(
                        onPressed: _fetchOrders,
                        icon: Icon(
                          Icons.refresh,
                          color: Colors.grey[600],
                        ),
                        tooltip: 'Refresh Orders',
                      ),
                    ],
                  ),
                ),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            offset: Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        children: [
          const Spacer(),
          if (_hasNewNotification)
            Flexible(
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_active, 
                         color: Colors.orange.shade700, size: 14),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'New Order!',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          _buildOrderStats(),
        ],
      ),
    );
  }

  Widget _buildOrderStats() {
    if (_allOrders.isEmpty) return const SizedBox();
    
    final pendingCount = _allOrders.where((o) => o.status == 'Pending').length;
    final preparingCount = _allOrders.where((o) => o.status == 'Preparing').length;
    final readyCount = _allOrders.where((o) => o.status == 'Ready for Pickup').length;
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildStatChip('Pending', pendingCount, Colors.orange),
          const SizedBox(width: 6),
          _buildStatChip('Preparing', preparingCount, Colors.blue),
          const SizedBox(width: 6),
          _buildStatChip('Ready', readyCount, Colors.green),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '$label ($count)',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    final filters = ['All', 'Pending', 'Accepted', 'Preparing', 'Ready for Pickup', 'Delivered', 'Cancelled'];
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((filter) {
            final isSelected = _selectedFilter == filter;
            final count = filter == 'All' 
                ? _allOrders.length 
                : _allOrders.where((order) => order.status == filter).length;
            
            return Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: FilterChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      filter,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey[700],
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                    if (count > 0) ...[
                      const SizedBox(width: 6),
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
                            fontSize: 12,
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
              ),
            );
          }).toList(),
        ),
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
      case 'Ready for Pickup':
        return Colors.green;
      case 'Delivered':
        return Colors.teal;
      case 'Cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.orange),
            SizedBox(height: 16),
            Text('Loading orders...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    } else if (_error != null) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade600, size: 48),
              const SizedBox(height: 16),
              Text(
                'Failed to load orders',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please check your connection and ensure the server is running.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red.shade700),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchOrders,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    } else if (_filteredOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _selectedFilter == 'All' ? 'No orders found' : 'No ${_selectedFilter.toLowerCase()} orders',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedFilter == 'All' 
                  ? 'Orders will appear here when customers place them'
                  : 'Try selecting a different filter',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      itemCount: _filteredOrders.length,
      itemBuilder: (context, index) {
        final order = _filteredOrders[index];
        return _buildModernOrderCard(order, _expandedOrders.contains(order.id));
      },
    );
  }

  Widget _buildModernOrderCard(Order order, bool isExpanded) {
    final orderTypeIcon = _getOrderTypeIcon(order.orderType ?? 'delivery');
    final orderTypeColor = _getOrderTypeColor(order.orderType ?? 'delivery');
    
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isExpanded) {
            _expandedOrders.remove(order.id);
          } else {
            _expandedOrders.add(order.id);
          }
        });
      },
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              offset: const Offset(0, 4),
              blurRadius: 12,
              spreadRadius: 0,
            ),
          ],
          border: Border.all(color: Colors.grey.shade100, width: 1),
        ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Enhanced Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _getStatusColor(order.status),
                  _getStatusColor(order.status).withOpacity(0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(orderTypeIcon, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  'Order #${order.id}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: orderTypeColor.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white.withOpacity(0.5)),
                                ),
                                child: Text(
                                  (order.orderType ?? 'delivery').toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            order.customerName,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              'UGX ${order.totalPrice.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                          color: Colors.white.withOpacity(0.8),
                          size: 24,
                        ),
                      ],
                    ),
                  ],
                ),
                if (order.estimatedPrepTime != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timer, color: Colors.white.withOpacity(0.9), size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Est. ${order.estimatedPrepTime} min',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Collapsed Summary
          if (!isExpanded)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(Icons.shopping_bag_outlined, color: Colors.grey[600], size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '${order.items.length} items',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  const Spacer(),
                  Text(
                    'Tap to view details',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ),
            ),
          // Expandable Content
          if (isExpanded) 
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Row(
                  children: [
                    Icon(Icons.attach_money, color: Colors.green.shade600, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Total: ${CurrencyFormatter.formatUGX(order.totalPrice)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.shopping_bag_outlined, color: Colors.grey[600], size: 20),
                    const SizedBox(width: 4),
                    Text(
                      '${order.items.length} items',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Order Items:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                ...order.items.map((item) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.fastfood, color: Colors.orange.shade600, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.menuItemName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '${CurrencyFormatter.formatUGX(item.price)} each',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'x${item.quantity}',
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
                const SizedBox(height: 16),
                _buildActionButtons(order),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildActionButtons(Order order) {
    switch (order.status) {
      case 'Pending':
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _updateOrderStatus(order.id, 'Rejected'),
                icon: const Icon(Icons.close, size: 18),
                label: const Text('Reject'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade600,
                  side: BorderSide(color: Colors.red.shade300),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _updateOrderStatus(order.id, 'Accepted'),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Accept'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 0,
                ),
              ),
            ),
          ],
        );
      case 'Accepted':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _updateOrderStatus(order.id, 'Preparing'),
            icon: const Icon(Icons.restaurant, size: 18),
            label: const Text('Start Preparing'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              elevation: 0,
            ),
          ),
        );
      case 'Preparing':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _updateOrderStatus(order.id, 'Ready for Pickup'),
            icon: const Icon(Icons.done_all, size: 18),
            label: const Text('Mark as Ready'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              elevation: 0,
            ),
          ),
        );
      default:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline, color: Colors.grey.shade600, size: 16),
              const SizedBox(width: 8),
              Text(
                'No actions available',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
            ],
          ),
        );
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.orange.shade700;
      case 'Preparing':
        return Colors.blue.shade700;
      case 'Ready for Pickup':
        return Colors.cyan.shade600;
      case 'Delivered':
        return Colors.green.shade700;
      case 'Cancelled':
        return Colors.red.shade700;
      default:
        return Colors.grey.shade600;
    }
  }

  @override
  void dispose() {
    _webSocketService?.disconnect();
    super.dispose();
  }
}
