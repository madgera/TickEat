import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/sale.dart';

class PaymentDialog extends StatefulWidget {
  final double totalAmount;
  final Function(PaymentMethod, double?) onPaymentCompleted;

  const PaymentDialog({
    super.key,
    required this.totalAmount,
    required this.onPaymentCompleted,
  });

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  PaymentMethod _selectedPaymentMethod = PaymentMethod.cash;
  final TextEditingController _amountController = TextEditingController();
  double? _amountPaid;
  double? _change;

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.totalAmount.toStringAsFixed(2);
    _calculateChange();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _calculateChange() {
    if (_selectedPaymentMethod == PaymentMethod.cash) {
      final amount = double.tryParse(_amountController.text) ?? 0;
      setState(() {
        _amountPaid = amount;
        _change = amount - widget.totalAmount;
      });
    } else {
      setState(() {
        _amountPaid = null;
        _change = null;
      });
    }
  }

  bool get _canComplete {
    if (_selectedPaymentMethod == PaymentMethod.electronic) {
      return true;
    }
    return _amountPaid != null && _amountPaid! >= widget.totalAmount;
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    
    // Responsive sizing
    final dialogWidth = screenWidth < 600 ? screenWidth * 0.9 : 400.0;
    final dialogMaxHeight = screenHeight * 0.8;
    final isSmallScreen = screenWidth < 600;
    
    return Dialog(
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(maxHeight: dialogMaxHeight),
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(
              children: [
                const Icon(Icons.payment, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Pagamento',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Riepilogo totale
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Totale da pagare:',
                    style: TextStyle(fontSize: 16),
                  ),
                  Text(
                    '€${widget.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Selezione metodo di pagamento
            Text(
              'Metodo di pagamento:',
              style: TextStyle(
                fontSize: isSmallScreen ? 14 : 16, 
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: isSmallScreen ? 8 : 12),
            
            // Layout responsive per i radio button
            isSmallScreen 
                ? Column(
                    children: [
                      _buildPaymentMethodTile(
                        PaymentMethod.cash,
                        Icons.payments,
                        'Contanti',
                        isSmallScreen,
                      ),
                      _buildPaymentMethodTile(
                        PaymentMethod.electronic,
                        Icons.credit_card,
                        'Elettronico',
                        isSmallScreen,
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: _buildPaymentMethodTile(
                          PaymentMethod.cash,
                          Icons.payments,
                          'Contanti',
                          isSmallScreen,
                        ),
                      ),
                      Expanded(
                        child: _buildPaymentMethodTile(
                          PaymentMethod.electronic,
                          Icons.credit_card,
                          'Elettronico',
                          isSmallScreen,
                        ),
                      ),
                    ],
                  ),
            
            const SizedBox(height: 24),
            
            // Campo importo per contanti
            if (_selectedPaymentMethod == PaymentMethod.cash) ...[
              Text(
                'Importo ricevuto:',
                style: TextStyle(
                  fontSize: isSmallScreen ? 14 : 16, 
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: isSmallScreen ? 6 : 8),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                decoration: const InputDecoration(
                  prefixText: '€ ',
                  border: OutlineInputBorder(),
                  hintText: '0.00',
                ),
                onChanged: (value) => _calculateChange(),
              ),
              
              const SizedBox(height: 16),
              
              // Pulsanti rapidi per contanti - layout responsive
              Wrap(
                spacing: isSmallScreen ? 6 : 8,
                runSpacing: isSmallScreen ? 6 : 8,
                children: [
                  _QuickAmountButton(
                    amount: widget.totalAmount,
                    label: 'Importo esatto',
                    isSmallScreen: isSmallScreen,
                    onPressed: () {
                      _amountController.text = widget.totalAmount.toStringAsFixed(2);
                      _calculateChange();
                    },
                  ),
                  _QuickAmountButton(
                    amount: (widget.totalAmount / 5).ceil() * 5,
                    label: '€${(widget.totalAmount / 5).ceil() * 5}',
                    isSmallScreen: isSmallScreen,
                    onPressed: () {
                      final roundedAmount = (widget.totalAmount / 5).ceil() * 5;
                      _amountController.text = roundedAmount.toStringAsFixed(2);
                      _calculateChange();
                    },
                  ),
                  _QuickAmountButton(
                    amount: (widget.totalAmount / 10).ceil() * 10,
                    label: '€${(widget.totalAmount / 10).ceil() * 10}',
                    isSmallScreen: isSmallScreen,
                    onPressed: () {
                      final roundedAmount = (widget.totalAmount / 10).ceil() * 10;
                      _amountController.text = roundedAmount.toStringAsFixed(2);
                      _calculateChange();
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Resto
              if (_change != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _change! >= 0 ? Colors.green[50] : Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _change! >= 0 ? Colors.green : Colors.red,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _change! >= 0 ? 'Resto:' : 'Mancante:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _change! >= 0 ? Colors.green[700] : Colors.red[700],
                        ),
                      ),
                      Text(
                        '€${_change!.abs().toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _change! >= 0 ? Colors.green[700] : Colors.red[700],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ],
            
            // Pulsanti azione - responsive
            isSmallScreen
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton(
                        onPressed: _canComplete ? () {
                          widget.onPaymentCompleted(_selectedPaymentMethod, _amountPaid);
                          Navigator.pop(context);
                        } : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 14 : 12),
                        ),
                        child: Text(
                          'Completa Pagamento',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 14 : 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 14 : 12),
                        ),
                        child: Text(
                          'Annulla',
                          style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Annulla'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _canComplete ? () {
                            widget.onPaymentCompleted(_selectedPaymentMethod, _amountPaid);
                            Navigator.pop(context);
                          } : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text(
                            'Completa Pagamento',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Widget helper per i radio button dei metodi di pagamento
  Widget _buildPaymentMethodTile(
    PaymentMethod paymentMethod,
    IconData icon,
    String label,
    bool isSmallScreen,
  ) {
    final isSelected = _selectedPaymentMethod == paymentMethod;
    
    return InkWell(
      onTap: () {
        setState(() {
          _selectedPaymentMethod = paymentMethod;
          _calculateChange();
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
        margin: EdgeInsets.only(bottom: isSmallScreen ? 8 : 0),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected ? Colors.blue.shade50 : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Radio<PaymentMethod>(
              value: paymentMethod,
              groupValue: _selectedPaymentMethod,
              onChanged: (value) {
                setState(() {
                  _selectedPaymentMethod = value!;
                  _calculateChange();
                });
              },
            ),
            SizedBox(width: isSmallScreen ? 8 : 12),
            Icon(
              icon,
              size: isSmallScreen ? 20 : 24,
              color: isSelected ? Colors.blue : Colors.grey.shade600,
            ),
            SizedBox(width: isSmallScreen ? 6 : 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: isSmallScreen ? 14 : 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.blue : Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAmountButton extends StatelessWidget {
  final double amount;
  final String label;
  final bool isSmallScreen;
  final VoidCallback onPressed;

  const _QuickAmountButton({
    required this.amount,
    required this.label,
    required this.isSmallScreen,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 8 : 12, 
          vertical: isSmallScreen ? 6 : 8,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
      ),
    );
  }
}
