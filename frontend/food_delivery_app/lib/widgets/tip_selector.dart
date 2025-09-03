import 'package:flutter/material.dart';
import 'package:food_delivery_app/utils/currency_formatter.dart';

class TipSelector extends StatefulWidget {
  final double selectedTip;
  final Function(double) onTipChanged;
  final double subtotal;

  const TipSelector({
    Key? key,
    required this.selectedTip,
    required this.onTipChanged,
    required this.subtotal,
  }) : super(key: key);

  @override
  State<TipSelector> createState() => _TipSelectorState();
}

class _TipSelectorState extends State<TipSelector> {
  final TextEditingController _customTipController = TextEditingController();
  bool _isCustomTip = false;

  @override
  void initState() {
    super.initState();
    _customTipController.text = widget.selectedTip.toString();
  }

  @override
  void dispose() {
    _customTipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.favorite, color: Colors.green[700], size: 20),
              const SizedBox(width: 8),
              Text(
                'Add a tip for great service',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.green[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Preset tip percentages
          Row(
            children: [
              Expanded(child: _buildTipButton('10%', widget.subtotal * 0.10)),
              const SizedBox(width: 8),
              Expanded(child: _buildTipButton('15%', widget.subtotal * 0.15)),
              const SizedBox(width: 8),
              Expanded(child: _buildTipButton('20%', widget.subtotal * 0.20)),
              const SizedBox(width: 8),
              Expanded(child: _buildTipButton('25%', widget.subtotal * 0.25)),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Custom tip option
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _isCustomTip = true;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isCustomTip ? Colors.green : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _isCustomTip ? Colors.green : Colors.grey.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.edit,
                          color: _isCustomTip ? Colors.white : Colors.grey[600],
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Custom',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _isCustomTip ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _isCustomTip = false;
                    });
                    widget.onTipChanged(0.0);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: !_isCustomTip && widget.selectedTip == 0.0 ? Colors.grey[300] : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: !_isCustomTip && widget.selectedTip == 0.0 ? Colors.grey : Colors.grey.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.close,
                          color: Colors.grey[600],
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'No tip',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          // Custom tip input field
          if (_isCustomTip) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green),
              ),
              child: Row(
                children: [
                  Text(
                    'UGX',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.green[700],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _customTipController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: '0',
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (value) {
                        final tipAmount = double.tryParse(value) ?? 0.0;
                        widget.onTipChanged(tipAmount);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          // Tip summary
          if (widget.selectedTip > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green[700], size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tip: ${CurrencyFormatter.formatUGX(widget.selectedTip)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.green[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTipButton(String percentage, double amount) {
    final isSelected = !_isCustomTip && (widget.selectedTip - amount).abs() < 0.01;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _isCustomTip = false;
        });
        widget.onTipChanged(amount);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.green : Colors.grey.withOpacity(0.3),
          ),
        ),
        child: Column(
          children: [
            Text(
              percentage,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              CurrencyFormatter.formatUGX(amount),
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.white70 : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
