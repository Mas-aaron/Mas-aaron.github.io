import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/payment_models.dart';
import '../services/payment_service.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> with SingleTickerProviderStateMixin {
  final PaymentService _paymentService = PaymentService();
  late TabController _tabController;
  
  List<PaymentPeriod> _paymentPeriods = [];
  List<OrderPayment> _orderPayments = [];
  List<BankAccount> _bankAccounts = [];
  List<PaymentDispute> _disputes = [];
  
  bool _isLoading = true;
  String? _error;
  PaymentPeriod? _selectedPeriod;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final periods = await _paymentService.getPaymentPeriods();
      final bankAccounts = await _paymentService.getBankAccounts();
      final disputes = await _paymentService.getPaymentDisputes();
      
      List<OrderPayment> orderPayments = [];
      if (periods.isNotEmpty) {
        orderPayments = await _paymentService.getOrderPayments(periodId: periods.first.id);
      }

      setState(() {
        _paymentPeriods = periods;
        _orderPayments = orderPayments;
        _bankAccounts = bankAccounts;
        _disputes = disputes;
        _selectedPeriod = periods.isNotEmpty ? periods.first : null;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadOrderPayments(PaymentPeriod period) async {
    try {
      final orderPayments = await _paymentService.getOrderPayments(periodId: period.id);
      setState(() {
        _orderPayments = orderPayments;
        _selectedPeriod = period;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load order payments: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text('Error: $_error', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildTabBar(),
          const SizedBox(height: 24),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPaymentPeriodsTab(),
                _buildOrderPaymentsTab(),
                _buildBankAccountsTab(),
                _buildDisputesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment Manager',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildSummaryCard(
                'Current Week',
                _selectedPeriod?.netPayoutUgx ?? 'UGX 0',
                Icons.account_balance_wallet,
                Colors.green,
              ),
              const SizedBox(width: 16),
              _buildSummaryCard(
                'Total Orders',
                _selectedPeriod?.totalOrders.toString() ?? '0',
                Icons.receipt_long,
                Colors.blue,
              ),
              const SizedBox(width: 16),
              _buildSummaryCard(
                'Status',
                _selectedPeriod?.status.toUpperCase() ?? 'N/A',
                Icons.info,
                _selectedPeriod?.status == 'paid' ? Colors.green : Colors.orange,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 5,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey[600],
        indicator: BoxDecoration(
          color: Colors.orange,
          borderRadius: BorderRadius.circular(12),
        ),
        tabs: const [
          Tab(text: 'Payment Periods'),
          Tab(text: 'Order Details'),
          Tab(text: 'Bank Accounts'),
          Tab(text: 'Disputes'),
        ],
      ),
    );
  }

  Widget _buildPaymentPeriodsTab() {
    if (_paymentPeriods.isEmpty) {
      return _buildEmptyState(
        'No Payment Periods',
        'Payment periods will appear here once you start receiving orders.',
        Icons.payment,
      );
    }

    return ListView.builder(
      itemCount: _paymentPeriods.length,
      itemBuilder: (context, index) {
        final period = _paymentPeriods[index];
        return _buildPaymentPeriodCard(period);
      },
    );
  }

  Widget _buildPaymentPeriodCard(PaymentPeriod period) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final isSelected = _selectedPeriod?.id == period.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: isSelected ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected ? const BorderSide(color: Colors.orange, width: 2) : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => _loadOrderPayments(period),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${period.periodType.toUpperCase()} PAYMENT',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${dateFormat.format(period.startDate)} - ${dateFormat.format(period.endDate)}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: period.status == 'paid' ? Colors.green[100] : Colors.orange[100],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      period.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: period.status == 'paid' ? Colors.green[700] : Colors.orange[700],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildPeriodStat('Orders', period.totalOrders.toString()),
                  ),
                  Expanded(
                    child: _buildPeriodStat('Gross Revenue', period.grossRevenueUgx),
                  ),
                  Expanded(
                    child: _buildPeriodStat('Platform Fee', period.platformFeeUgx),
                  ),
                  Expanded(
                    child: _buildPeriodStat('Net Payout', period.netPayoutUgx),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildOrderPaymentsTab() {
    if (_orderPayments.isEmpty) {
      return _buildEmptyState(
        'No Order Payments',
        _selectedPeriod == null 
          ? 'Select a payment period to view order details.'
          : 'No orders found for the selected payment period.',
        Icons.receipt,
      );
    }

    return Column(
      children: [
        if (_selectedPeriod != null)
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info, color: Colors.blue[600]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Showing ${_orderPayments.length} orders for ${DateFormat('MMM dd, yyyy').format(_selectedPeriod!.startDate)} - ${DateFormat('MMM dd, yyyy').format(_selectedPeriod!.endDate)}',
                    style: TextStyle(color: Colors.blue[700], fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: _orderPayments.length,
            itemBuilder: (context, index) {
              final payment = _orderPayments[index];
              return _buildOrderPaymentCard(payment);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOrderPaymentCard(OrderPayment payment) {
    final dateFormat = DateFormat('MMM dd, yyyy HH:mm');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order #${payment.orderNumber}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        payment.customerName,
                        style: TextStyle(color: Colors.grey[600]),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        dateFormat.format(payment.orderDate),
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      payment.netPayoutUgx,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: payment.paymentStatus == 'paid' ? Colors.green[100] : Colors.orange[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        payment.paymentStatus.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: payment.paymentStatus == 'paid' ? Colors.green[700] : Colors.orange[700],
                        ),
                      ),
                    ),
                  ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildPaymentDetail('Subtotal', payment.subtotalUgx)),
                Expanded(child: _buildPaymentDetail('Delivery Fee', payment.deliveryFeeUgx)),
                Expanded(child: _buildPaymentDetail('Platform Fee', payment.platformCommissionUgx)),
                Expanded(child: _buildPaymentDetail('Net Payout', payment.netPayoutUgx)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentDetail(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildBankAccountsTab() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Bank Accounts',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            ElevatedButton.icon(
              onPressed: _showAddBankAccountDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add Account'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _bankAccounts.isEmpty
              ? _buildEmptyState(
                  'No Bank Accounts',
                  'Add a bank account to receive payments.',
                  Icons.account_balance,
                )
              : ListView.builder(
                  itemCount: _bankAccounts.length,
                  itemBuilder: (context, index) {
                    final account = _bankAccounts[index];
                    return _buildBankAccountCard(account);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildBankAccountCard(BankAccount account) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.account_balance, color: Colors.blue[600], size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.accountHolderName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    account.bankName,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  Text(
                    account.accountType.toUpperCase(),
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: account.isVerified ? Colors.green[100] : Colors.orange[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    account.isVerified ? 'VERIFIED' : 'PENDING',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: account.isVerified ? Colors.green[700] : Colors.orange[700],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Added ${DateFormat('MMM dd, yyyy').format(account.createdAt)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisputesTab() {
    if (_disputes.isEmpty) {
      return _buildEmptyState(
        'No Disputes',
        'Payment disputes will appear here when customers request refunds.',
        Icons.gavel,
      );
    }

    return ListView.builder(
      itemCount: _disputes.length,
      itemBuilder: (context, index) {
        final dispute = _disputes[index];
        return _buildDisputeCard(dispute);
      },
    );
  }

  Widget _buildDisputeCard(PaymentDispute dispute) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #${dispute.orderNumber}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dispute.disputeType.replaceAll('_', ' ').toUpperCase(),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      dispute.amountDisputedUgx,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getDisputeStatusColor(dispute.status)[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        dispute.status.replaceAll('_', ' ').toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _getDisputeStatusColor(dispute.status)[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              dispute.reason,
              style: TextStyle(color: Colors.grey[700]),
            ),
            if (dispute.restaurantResponse != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Response:',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[700]),
                    ),
                    const SizedBox(height: 4),
                    Text(dispute.restaurantResponse!),
                  ],
                ),
              ),
            ],
            if (dispute.status == 'open') ...[
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => _showRespondToDisputeDialog(dispute),
                child: const Text('Respond to Dispute'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  MaterialColor _getDisputeStatusColor(String status) {
    switch (status) {
      case 'resolved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'under_review':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showAddBankAccountDialog() {
    // Implementation for adding bank account dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Bank Account'),
        content: const Text('Bank account management dialog will be implemented here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showRespondToDisputeDialog(PaymentDispute dispute) {
    // Implementation for responding to dispute dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Respond to Dispute'),
        content: const Text('Dispute response dialog will be implemented here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
