import 'package:flutter/material.dart';

enum OrderType { delivery, pickup, dineIn }

class OrderTypeSelector extends StatefulWidget {
  final OrderType selectedType;
  final Function(OrderType) onTypeChanged;
  final bool showDistance;
  final String? distance;
  final int? estimatedPrepTime;

  const OrderTypeSelector({
    Key? key,
    required this.selectedType,
    required this.onTypeChanged,
    this.showDistance = false,
    this.distance,
    this.estimatedPrepTime,
  }) : super(key: key);

  @override
  State<OrderTypeSelector> createState() => _OrderTypeSelectorState();
}

class _OrderTypeSelectorState extends State<OrderTypeSelector> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Type',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildOrderTypeCard(
                  type: OrderType.delivery,
                  icon: Icons.delivery_dining,
                  title: 'Delivery',
                  subtitle: widget.showDistance && widget.distance != null
                      ? '${widget.distance} • 25-35 min'
                      : '25-35 min',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildOrderTypeCard(
                  type: OrderType.pickup,
                  icon: Icons.store,
                  title: 'Pickup',
                  subtitle: widget.estimatedPrepTime != null
                      ? '${widget.estimatedPrepTime} min'
                      : '15-25 min',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildOrderTypeCard(
                  type: OrderType.dineIn,
                  icon: Icons.restaurant,
                  title: 'Dine-in',
                  subtitle: 'ASAP or schedule',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderTypeCard({
    required OrderType type,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = widget.selectedType == type;
    
    return GestureDetector(
      onTap: () => widget.onTypeChanged(type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.grey.withOpacity(0.05),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected ? Colors.blue : Colors.grey[600],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.blue : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
