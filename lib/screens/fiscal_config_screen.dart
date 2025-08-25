/// Schermata di configurazione fiscale per la conformità RT
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/fiscal_data.dart';
import '../services/fiscal_service.dart';

class FiscalConfigScreen extends StatefulWidget {
  const FiscalConfigScreen({super.key});

  @override
  State<FiscalConfigScreen> createState() => _FiscalConfigScreenState();
}

class _FiscalConfigScreenState extends State<FiscalConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final FiscalService _fiscalService = FiscalService();
  
  // Controller per i campi del form
  final _vatNumberController = TextEditingController();
  final _taxCodeController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _zipCodeController = TextEditingController();
  final _provinceController = TextEditingController();
  final _rtCertificateController = TextEditingController();
  
  DateTime _certificateExpiry = DateTime.now().add(const Duration(days: 365));
  bool _lotteryEnabled = true;
  VatRate _defaultVatRate = VatRate.standard;
  
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadExistingConfiguration();
  }

  @override
  void dispose() {
    _vatNumberController.dispose();
    _taxCodeController.dispose();
    _businessNameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _zipCodeController.dispose();
    _provinceController.dispose();
    _rtCertificateController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingConfiguration() async {
    setState(() => _isLoading = true);
    
    try {
      await _fiscalService.initialize();
      final config = _fiscalService.configuration;
      
      if (config != null) {
        _vatNumberController.text = config.vatNumber;
        _taxCodeController.text = config.taxCode;
        _businessNameController.text = config.businessName;
        _addressController.text = config.address;
        _cityController.text = config.city;
        _zipCodeController.text = config.zipCode;
        _provinceController.text = config.province;
        _rtCertificateController.text = config.rtCertificate;
        _certificateExpiry = config.certificateExpiry;
        _lotteryEnabled = config.lotteryEnabled;
        _defaultVatRate = config.defaultVatRate;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore caricamento configurazione: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveConfiguration() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final config = FiscalConfiguration(
        vatNumber: _vatNumberController.text.trim(),
        taxCode: _taxCodeController.text.trim(),
        businessName: _businessNameController.text.trim(),
        address: _addressController.text.trim(),
        city: _cityController.text.trim(),
        zipCode: _zipCodeController.text.trim(),
        province: _provinceController.text.trim(),
        rtCertificate: _rtCertificateController.text.trim(),
        certificateExpiry: _certificateExpiry,
        lotteryEnabled: _lotteryEnabled,
        defaultVatRate: _defaultVatRate,
      );

      await _fiscalService.saveConfiguration(config);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configurazione fiscale salvata con successo'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore salvataggio: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  String? _validateVatNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Partita IVA obbligatoria';
    }
    
    final vatNumber = value.trim().replaceAll(' ', '');
    if (vatNumber.length != 11) {
      return 'Partita IVA deve essere di 11 cifre';
    }
    
    if (!RegExp(r'^\d{11}$').hasMatch(vatNumber)) {
      return 'Partita IVA deve contenere solo numeri';
    }
    
    return null;
  }

  String? _validateTaxCode(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Codice fiscale obbligatorio';
    }
    
    final taxCode = value.trim().toUpperCase();
    if (taxCode.length != 16) {
      return 'Codice fiscale deve essere di 16 caratteri';
    }
    
    if (!RegExp(r'^[A-Z]{6}\d{2}[A-Z]\d{2}[A-Z]\d{3}[A-Z]$').hasMatch(taxCode)) {
      return 'Formato codice fiscale non valido';
    }
    
    return null;
  }

  String? _validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName obbligatorio';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurazione Fiscale'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.business, color: Colors.blue[700]),
                                const SizedBox(width: 8),
                                Text(
                                  'Dati Aziendali',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _businessNameController,
                              decoration: const InputDecoration(
                                labelText: 'Ragione Sociale *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.business_center),
                              ),
                              validator: (value) => _validateRequired(value, 'Ragione sociale'),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _vatNumberController,
                                    decoration: const InputDecoration(
                                      labelText: 'Partita IVA *',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.numbers),
                                      hintText: 'IT01234567890',
                                    ),
                                    validator: _validateVatNumber,
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _taxCodeController,
                                    decoration: const InputDecoration(
                                      labelText: 'Codice Fiscale *',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.credit_card),
                                    ),
                                    validator: _validateTaxCode,
                                    textCapitalization: TextCapitalization.characters,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.location_on, color: Colors.blue[700]),
                                const SizedBox(width: 8),
                                Text(
                                  'Indirizzo',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _addressController,
                              decoration: const InputDecoration(
                                labelText: 'Indirizzo *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.home),
                              ),
                              validator: (value) => _validateRequired(value, 'Indirizzo'),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: _cityController,
                                    decoration: const InputDecoration(
                                      labelText: 'Città *',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.location_city),
                                    ),
                                    validator: (value) => _validateRequired(value, 'Città'),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _zipCodeController,
                                    decoration: const InputDecoration(
                                      labelText: 'CAP *',
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (value) => _validateRequired(value, 'CAP'),
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _provinceController,
                                    decoration: const InputDecoration(
                                      labelText: 'Provincia *',
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (value) => _validateRequired(value, 'Provincia'),
                                    textCapitalization: TextCapitalization.characters,
                                    maxLength: 2,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.security, color: Colors.blue[700]),
                                const SizedBox(width: 8),
                                Text(
                                  'Configurazione Tecnica',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _rtCertificateController,
                              decoration: const InputDecoration(
                                labelText: 'Certificato RT *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.card_membership),
                                hintText: 'Codice certificato registratore telematico',
                              ),
                              validator: (value) => _validateRequired(value, 'Certificato RT'),
                            ),
                            const SizedBox(height: 16),
                            ListTile(
                              leading: const Icon(Icons.calendar_today),
                              title: const Text('Scadenza Certificato'),
                              subtitle: Text(DateFormat('dd/MM/yyyy').format(_certificateExpiry)),
                              trailing: const Icon(Icons.edit),
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _certificateExpiry,
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(const Duration(days: 3650)),
                                );
                                if (picked != null) {
                                  setState(() => _certificateExpiry = picked);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.settings, color: Colors.blue[700]),
                                const SizedBox(width: 8),
                                Text(
                                  'Opzioni Fiscali',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<VatRate>(
                              value: _defaultVatRate,
                              decoration: const InputDecoration(
                                labelText: 'Aliquota IVA Predefinita',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.percent),
                              ),
                              items: VatRate.values.map((rate) {
                                return DropdownMenuItem(
                                  value: rate,
                                  child: Text('${rate.rate.toStringAsFixed(1)}% - ${rate.description}'),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _defaultVatRate = value);
                                }
                              },
                            ),
                            const SizedBox(height: 16),
                            SwitchListTile(
                              title: const Text('Lotteria degli Scontrini'),
                              subtitle: const Text('Abilita la generazione di codici per la lotteria'),
                              value: _lotteryEnabled,
                              onChanged: (value) {
                                setState(() => _lotteryEnabled = value);
                              },
                              secondary: const Icon(Icons.confirmation_number),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    ElevatedButton(
                      onPressed: _isSaving ? null : _saveConfiguration,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isSaving
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white),
                                ),
                                SizedBox(width: 8),
                                Text('Salvataggio...'),
                              ],
                            )
                          : const Text(
                              'Salva Configurazione',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Informazioni aggiuntive
                    Card(
                      color: Colors.blue[50],
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info, color: Colors.blue[700]),
                                const SizedBox(width: 8),
                                Text(
                                  'Informazioni',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[700],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '• La configurazione è necessaria per la conformità fiscale RT\n'
                              '• Tutti i documenti saranno firmati digitalmente\n'
                              '• I corrispettivi verranno trasmessi automaticamente all\'AdE\n'
                              '• Il certificato RT deve essere valido e aggiornato',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
