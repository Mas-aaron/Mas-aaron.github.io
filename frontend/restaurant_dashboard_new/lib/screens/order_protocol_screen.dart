import 'package:flutter/material.dart';
import '../services/onboarding_service.dart';

class OrderProtocolScreen extends StatefulWidget {
  static const routeName = '/order-protocol';

  const OrderProtocolScreen({super.key});

  @override
  _OrderProtocolScreenState createState() => _OrderProtocolScreenState();
}

class _OrderProtocolScreenState extends State<OrderProtocolScreen> {
  final OnboardingService _onboardingService = OnboardingService();
  String? _selectedProtocol;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchOrderProtocol();
  }

  Future<void> _fetchOrderProtocol() async {
    try {
      final protocol = await _onboardingService.getOrderProtocol();
      setState(() {
        _selectedProtocol = protocol;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      // Handle error, e.g., show a snackbar
    }
  }

  Future<void> _updateOrderProtocol(String protocol) async {
    setState(() {
      _selectedProtocol = protocol;
    });
    try {
      await _onboardingService.updateOrderProtocol(protocol);
      // Show success message
    } catch (e) {
      // Handle error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Order Protocol'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                RadioListTile<String>(
                  title: const Text('Tablet'),
                  value: 'Tablet',
                  groupValue: _selectedProtocol,
                  onChanged: (value) => _updateOrderProtocol(value!),
                ),
                RadioListTile<String>(
                  title: const Text('Email'),
                  value: 'Email',
                  groupValue: _selectedProtocol,
                  onChanged: (value) => _updateOrderProtocol(value!),
                ),
                RadioListTile<String>(
                  title: const Text('Phone'),
                  value: 'Phone',
                  groupValue: _selectedProtocol,
                  onChanged: (value) => _updateOrderProtocol(value!),
                ),
              ],
            ),
    );
  }
}
