import 'package:flutter/material.dart';

import '../services/promo_code_service.dart';

class PromoCodesScreen extends StatefulWidget {
  static const routeName = '/promo-codes';

  const PromoCodesScreen({super.key});

  @override
  State<PromoCodesScreen> createState() => _PromoCodesScreenState();
}

class _PromoCodesScreenState extends State<PromoCodesScreen> {
  final PromoCodeService _service = PromoCodeService();
  final TextEditingController _codeController = TextEditingController();

  final TextEditingController _createCodeController = TextEditingController();
  final TextEditingController _createValueController = TextEditingController();
  String _createType = 'PERCENT';

  bool _isLoading = true;
  String? _error;
  List<PromoCodeDto> _codes = const [];

  bool _isMyLoading = true;
  String? _myError;
  List<PromoCodeDto> _myCodes = const [];

  bool _isApplying = false;

  @override
  void initState() {
    super.initState();
    _load();
    _loadMyCodes();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _createCodeController.dispose();
    _createValueController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final codes = await _service.listPromoCodes();
      if (!mounted) return;
      setState(() {
        _codes = codes;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleActive(PromoCodeDto promo) async {
    final promoId = promo.id;
    if (promoId == null) return;

    try {
      await _service.updateMyPromoCode(
        promoId: promoId,
        isActive: !(promo.isActive ?? true),
      );
      await _loadMyCodes();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showCreateDialog() async {
    _createCodeController.clear();
    _createValueController.clear();
    _createType = 'PERCENT';

    final shouldCreate = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create Promo Code'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _createCodeController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Code (e.g. SAVE10)',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _createType,
                items: const [
                  DropdownMenuItem(value: 'PERCENT', child: Text('Percent')),
                  DropdownMenuItem(value: 'FIXED', child: Text('Fixed')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  _createType = v;
                },
                decoration: const InputDecoration(labelText: 'Discount Type'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _createValueController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Discount Value',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    if (shouldCreate != true) return;

    final code = _createCodeController.text.trim();
    final value = _createValueController.text.trim();
    if (code.isEmpty || value.isEmpty) return;

    try {
      await _service.createMyPromoCode(
        code: code,
        discountType: _createType,
        discountValue: value,
      );
      await _loadMyCodes();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadMyCodes() async {
    if (!mounted) return;
    setState(() {
      _isMyLoading = true;
      _myError = null;
    });

    try {
      final codes = await _service.listMyPromoCodes();
      if (!mounted) return;
      setState(() {
        _myCodes = codes;
        _isMyLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _myError = e.toString();
        _isMyLoading = false;
      });
    }
  }

  Future<void> _apply(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return;

    if (!mounted) return;
    setState(() {
      _isApplying = true;
    });

    try {
      final applied = await _service.applyPromoCode(trimmed);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Applied ${applied.code} (${applied.discountType}: ${applied.discountValue})',
          ),
          backgroundColor: Colors.orange,
        ),
      );

      _codeController.clear();
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isApplying = false;
        });
      }
    }
  }

  String _formatDiscount(PromoCodeDto code) {
    if (code.discountType.toUpperCase() == 'PERCENT') {
      return '${code.discountValue}% off';
    }
    return 'UGX ${code.discountValue} off';
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Promo Codes'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Global'),
              Tab(text: 'My Codes'),
            ],
          ),
          actions: [
            IconButton(
              onPressed: _showCreateDialog,
              icon: const Icon(Icons.add),
              tooltip: 'Create promo code',
            ),
          ],
        ),
        body: TabBarView(
          children: [
            RefreshIndicator(
              onRefresh: _load,
              color: Colors.orange,
              backgroundColor: Colors.white,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Apply a code',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _codeController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              hintText: 'Enter promo code',
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: _isApplying ? null : _apply,
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isApplying ? null : () => _apply(_codeController.text),
                              child: _isApplying
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Text('Apply'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: Center(
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    )
                  else if (_codes.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: Center(
                        child: Text(
                          'No promo codes available right now.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    ..._codes.map(
                      (c) => Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListTile(
                          title: Text(
                            c.code,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(_formatDiscount(c)),
                          trailing: OutlinedButton(
                            onPressed: _isApplying ? null : () => _apply(c.code),
                            child: const Text('Apply'),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            RefreshIndicator(
              onRefresh: _loadMyCodes,
              color: Colors.orange,
              backgroundColor: Colors.white,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  if (_isMyLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_myError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: Center(
                        child: Text(
                          _myError!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    )
                  else if (_myCodes.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: Center(
                        child: Text(
                          'You have not created any promo codes yet.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    ..._myCodes.map(
                      (c) => Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListTile(
                          title: Text(
                            c.code,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${_formatDiscount(c)}  •  ${((c.isActive ?? true) ? 'Active' : 'Inactive')}',
                          ),
                          trailing: TextButton(
                            onPressed: () => _toggleActive(c),
                            child: Text(
                              (c.isActive ?? true) ? 'Deactivate' : 'Activate',
                              style: TextStyle(
                                color: (c.isActive ?? true) ? Colors.red : Colors.green,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
