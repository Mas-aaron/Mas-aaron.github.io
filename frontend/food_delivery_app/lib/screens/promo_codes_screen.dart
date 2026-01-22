import 'package:flutter/material.dart';
import 'package:food_delivery_app/services/promo_code_service.dart';

class PromoCodesScreen extends StatefulWidget {
  const PromoCodesScreen({super.key});

  @override
  State<PromoCodesScreen> createState() => _PromoCodesScreenState();
}

class _PromoCodesScreenState extends State<PromoCodesScreen> {
  final PromoCodeService _service = PromoCodeService();
  final TextEditingController _codeController = TextEditingController();

  bool _isLoading = true;
  String? _error;
  List<PromoCodeDto> _codes = const [];

  bool _isApplying = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _codeController.dispose();
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
          backgroundColor: const Color(0xFFfe5722),
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Promo Codes'),
        backgroundColor: const Color(0xFFfe5722),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: Colors.orange,
        backgroundColor: Colors.white,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
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
                    decoration: InputDecoration(
                      hintText: 'Enter promo code',
                      filled: true,
                      fillColor: const Color(0xFFF3F4F6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: _isApplying ? null : _apply,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFfe5722),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
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
                          : const Text(
                              'Apply',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                ],
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
                (c) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 12,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.code,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatDiscount(c),
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFfe5722),
                          side: const BorderSide(color: Color(0xFFfe5722)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _isApplying ? null : () => _apply(c.code),
                        child: const Text('Apply'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
