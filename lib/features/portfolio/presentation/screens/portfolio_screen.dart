import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/firebase/firestore_portfolio_service.dart';
import '../../../../shared/providers/metal_price_provider.dart';
import '../../../../shared/providers/currency_provider.dart';

class PortfolioScreen extends ConsumerStatefulWidget {
  const PortfolioScreen({super.key});

  @override
  ConsumerState<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends ConsumerState<PortfolioScreen> {
  late Box<PortfolioItem> _portfolioBox;
  final FirestorePortfolioService _firestoreService = FirestorePortfolioService();
  bool _isInitialized = false;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  bool get _isLoggedIn {
    final user = FirebaseAuth.instance.currentUser;
    return user != null && !user.isAnonymous;
  }

  @override
  void initState() {
    super.initState();
    _initializePortfolio();
  }

  Future<void> _initializePortfolio() async {
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(PortfolioItemAdapter());
    }
    _portfolioBox = Hive.isBoxOpen('portfolio')
        ? Hive.box<PortfolioItem>('portfolio')
        : await Hive.openBox<PortfolioItem>('portfolio');

    // If logged in, sync from Firestore
    if (_isLoggedIn) {
      await _loadFromFirestore();
    }

    setState(() {
      _isInitialized = true;
    });
  }

  Future<void> _loadFromFirestore() async {
    try {
      final items = await _firestoreService.loadAll(_uid!);
      // Replace local Hive data with Firestore data
      await _portfolioBox.clear();
      for (final data in items) {
        _portfolioBox.add(PortfolioItem.fromFirestoreMap(data));
      }
    } catch (e) {
      print('Failed to load portfolio from Firestore: $e');
    }
  }

  void _showAddItemDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddPortfolioItemDialog(
        onSave: (item) async {
          _portfolioBox.add(item);
          // Sync to Firestore if logged in
          if (_isLoggedIn) {
            try {
              final docId = await _firestoreService.saveItem(
                _uid!,
                item.toFirestoreMap(),
              );
              item.firestoreId = docId;
              // Update the last item in Hive with the firestoreId
              await _portfolioBox.putAt(_portfolioBox.length - 1, item);
            } catch (e) {
              print('Failed to sync new item to Firestore: $e');
            }
          }
          setState(() {});
        },
      ),
    );
  }

  void _showEditItemDialog(PortfolioItem item, int index) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddPortfolioItemDialog(
        existingItem: item,
        onSave: (updatedItem) async {
          updatedItem.firestoreId = item.firestoreId;
          await _portfolioBox.putAt(index, updatedItem);
          // Sync to Firestore if logged in
          if (_isLoggedIn && updatedItem.firestoreId != null) {
            try {
              await _firestoreService.saveItem(
                _uid!,
                updatedItem.toFirestoreMap(),
                docId: updatedItem.firestoreId,
              );
            } catch (e) {
              print('Failed to sync edit to Firestore: $e');
            }
          }
          setState(() {});
        },
      ),
    );
  }

  double _calculateTotalValue() {
    final goldPrice = ref.watch(metalPriceProvider);
    final silverPrice = ref.watch(silverPriceProvider);

    if (goldPrice == null && silverPrice == null) return 0.0;
    
    double total = 0.0;
    for (var item in _portfolioBox.values) {
      final price = item.metal == 'Gold' ? goldPrice : silverPrice;
      if (price != null) {
        final pricePerGram = price.getPricePerGram();
        final karatMultiplier = item.karat / 24;
        total += pricePerGram * karatMultiplier * item.weight;
      }
    }
    return total;
  }

  double _calculateTotalProfitLoss() {
    final goldPrice = ref.watch(metalPriceProvider);
    final silverPrice = ref.watch(silverPriceProvider);

    if (goldPrice == null && silverPrice == null) return 0.0;
    
    double totalCost = 0.0;
    double totalValue = 0.0;
    
    for (var item in _portfolioBox.values) {
      totalCost += item.purchasePrice * item.weight;

      final price = item.metal == 'Gold' ? goldPrice : silverPrice;
      if (price != null) {
        final pricePerGram = price.getPricePerGram();
        final karatMultiplier = item.karat / 24;
        totalValue += pricePerGram * karatMultiplier * item.weight;
      }
    }
    
    return totalValue - totalCost;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (!_isInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My Portfolio',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Summary Cards
                    Builder(builder: (_) {
                      final totalProfitLoss = _calculateTotalProfitLoss();
                      return Column(children: [
                        _buildSummaryCard(
                          'Total Value',
                          _calculateTotalValue(),
                          const Color(0xFFFFB800),
                          Icons.account_balance_wallet,
                        ),
                        const SizedBox(height: 12),
                        _buildSummaryCard(
                          'Total Profit/Loss',
                          totalProfitLoss,
                          totalProfitLoss >= 0 ? Colors.green : Colors.red,
                          totalProfitLoss >= 0 ? Icons.trending_up : Icons.trending_down,
                          showSign: true,
                        ),
                      ]);
                    }),
                    const SizedBox(height: 24),
                    
                    // Holdings Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Holdings',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${_portfolioBox.values.length} items',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            
            // Portfolio Items
            if (_portfolioBox.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 80,
                        color: Colors.grey.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No holdings yet',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add your first gold or silver holding',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = _portfolioBox.getAt(index)!;
                    return _buildPortfolioItem(item, index);
                  },
                  childCount: _portfolioBox.length,
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddItemDialog,
        backgroundColor: const Color(0xFFFFB800),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Add Holding',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, double value, Color color, IconData icon, {bool showSign = false}) {
    final currency = ref.watch(selectedCurrencyProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color,
            color.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatCurrency(value, currency, showSign: showSign),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortfolioItem(PortfolioItem item, int index) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currency = ref.watch(selectedCurrencyProvider);
    
    final goldPrice = ref.watch(metalPriceProvider);
    final silverPrice = ref.watch(silverPriceProvider);
    final price = item.metal == 'Gold' ? goldPrice : silverPrice;
    
    double currentValue = 0.0;
    double profitLoss = 0.0;
    double profitLossPercent = 0.0;
    
    if (price != null) {
      final pricePerGram = price.getPricePerGram();
      final karatMultiplier = item.karat / 24;
      currentValue = pricePerGram * karatMultiplier * item.weight;
      final totalCost = item.purchasePrice * item.weight;
      profitLoss = currentValue - totalCost;
      profitLossPercent = totalCost != 0
          ? (profitLoss / totalCost) * 100
          : 0.0;
    }
    
    return Dismissible(
      key: Key('portfolio_item_$index'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) {
        final firestoreId = item.firestoreId;
        _portfolioBox.deleteAt(index);
        if (_isLoggedIn && firestoreId != null) {
          _firestoreService.deleteItem(_uid!, firestoreId);
        }
        setState(() {});

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Item removed'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () async {
                _portfolioBox.add(item);
                // Re-create in Firestore on undo
                if (_isLoggedIn) {
                  try {
                    final newDocId = await _firestoreService.saveItem(
                      _uid!,
                      item.toFirestoreMap(),
                    );
                    item.firestoreId = newDocId;
                    await _portfolioBox.putAt(_portfolioBox.length - 1, item);
                  } catch (_) {}
                }
                setState(() {});
              },
            ),
          ),
        );
      },
      child: GestureDetector(
        onTap: () => _showEditItemDialog(item, index),
        child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[800] : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: item.metal == 'Gold'
                            ? const Color(0xFFFFB800).withValues(alpha: 0.2)
                            : Colors.grey.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        item.metal == 'Gold' ? Icons.star : Icons.circle,
                        color: item.metal == 'Gold'
                            ? const Color(0xFFFFB800)
                            : Colors.grey,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item.metal} ${item.karat}K',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${item.weight}g • ${_formatDate(item.purchaseDate)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: profitLoss >= 0
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        profitLoss >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                        color: profitLoss >= 0 ? Colors.green : Colors.red,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${profitLoss > 0 ? '+' : ''}${profitLossPercent.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: profitLoss >= 0 ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildItemDetail('Purchase', _formatCurrency(item.purchasePrice * item.weight, currency)),
                _buildItemDetail('Current', _formatCurrency(currentValue, currency)),
                _buildItemDetail(
                  'P/L',
                  _formatCurrency(profitLoss, currency, showSign: true),
                  valueColor: profitLoss >= 0 ? Colors.green : Colors.red,
                ),
              ],
            ),
            if (item.notes != null && item.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                item.notes!,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildItemDetail(String label, String value, {Color? valueColor}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  String _formatCurrency(double value, String currency, {bool showSign = false}) {
    final symbols = {
      'USD': '\$',
      'SAR': 'SAR ',
      'AED': 'AED ',
      'EGP': 'EGP ',
      'KWD': 'KWD ',
      'EUR': '€',
      'GBP': '£',
    };

    final symbol = symbols[currency] ?? '$currency ';
    final sign = showSign && value > 0 ? '+' : '';
    return '$sign$symbol${value.toStringAsFixed(2)}';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

// Portfolio Item Model
class PortfolioItem {
  String? firestoreId;
  final String metal;
  final int karat;
  final double weight;
  final double purchasePrice;
  final DateTime purchaseDate;
  final String? notes;

  PortfolioItem({
    this.firestoreId,
    required this.metal,
    required this.karat,
    required this.weight,
    required this.purchasePrice,
    required this.purchaseDate,
    this.notes,
  });

  Map<String, dynamic> toFirestoreMap() => {
    'metal': metal,
    'karat': karat,
    'weight': weight,
    'purchasePrice': purchasePrice,
    'purchaseDate': purchaseDate.millisecondsSinceEpoch,
    'notes': notes ?? '',
  };

  factory PortfolioItem.fromFirestoreMap(Map<String, dynamic> data) {
    return PortfolioItem(
      firestoreId: data['firestoreId'],
      metal: data['metal'] ?? 'Gold',
      karat: data['karat'] ?? 24,
      weight: (data['weight'] as num).toDouble(),
      purchasePrice: (data['purchasePrice'] as num).toDouble(),
      purchaseDate: DateTime.fromMillisecondsSinceEpoch(data['purchaseDate'] as int),
      notes: data['notes'] == '' ? null : data['notes'],
    );
  }
}

// Hive Adapter for PortfolioItem
class PortfolioItemAdapter extends TypeAdapter<PortfolioItem> {
  @override
  final int typeId = 0;

  @override
  PortfolioItem read(BinaryReader reader) {
    final metal = reader.readString();
    final karat = reader.readInt();
    final weight = reader.readDouble();
    final purchasePrice = reader.readDouble();
    final purchaseDate = DateTime.fromMillisecondsSinceEpoch(reader.readInt());
    final notes = reader.readString();
    // Read firestoreId if available (backward compat with old entries)
    String? firestoreId;
    try {
      final id = reader.readString();
      if (id.isNotEmpty) firestoreId = id;
    } catch (_) {}

    return PortfolioItem(
      firestoreId: firestoreId,
      metal: metal,
      karat: karat,
      weight: weight,
      purchasePrice: purchasePrice,
      purchaseDate: purchaseDate,
      notes: notes.isEmpty ? null : notes,
    );
  }

  @override
  void write(BinaryWriter writer, PortfolioItem obj) {
    writer.writeString(obj.metal);
    writer.writeInt(obj.karat);
    writer.writeDouble(obj.weight);
    writer.writeDouble(obj.purchasePrice);
    writer.writeInt(obj.purchaseDate.millisecondsSinceEpoch);
    writer.writeString(obj.notes ?? '');
    writer.writeString(obj.firestoreId ?? '');
  }
}

// Add/Edit Portfolio Item Dialog
class AddPortfolioItemDialog extends StatefulWidget {
  final Function(PortfolioItem) onSave;
  final PortfolioItem? existingItem;

  const AddPortfolioItemDialog({
    super.key,
    required this.onSave,
    this.existingItem,
  });

  bool get isEditing => existingItem != null;

  @override
  State<AddPortfolioItemDialog> createState() => _AddPortfolioItemDialogState();
}

class _AddPortfolioItemDialogState extends State<AddPortfolioItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();
  final _priceController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedMetal = 'Gold';
  int _selectedKarat = 24;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.existingItem != null) {
      final item = widget.existingItem!;
      _selectedMetal = item.metal;
      _selectedKarat = item.karat;
      _weightController.text = item.weight.toString();
      _priceController.text = item.purchasePrice.toString();
      _selectedDate = item.purchaseDate;
      _notesController.text = item.notes ?? '';
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                widget.isEditing ? 'Edit Holding' : 'Add Holding',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              
              // Metal Selection
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Gold'),
                      value: 'Gold',
                      groupValue: _selectedMetal,
                      onChanged: (value) {
                        setState(() {
                          _selectedMetal = value!;
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Silver'),
                      value: 'Silver',
                      groupValue: _selectedMetal,
                      onChanged: (value) {
                        setState(() {
                          _selectedMetal = value!;
                          _selectedKarat = 24; // Silver is always 24K
                        });
                      },
                    ),
                  ),
                ],
              ),
              
              // Karat Selection (only for gold)
              if (_selectedMetal == 'Gold') ...[
                const SizedBox(height: 16),
                Text(
                  'Karat',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [24, 22, 21, 18].map((karat) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text('${karat}K'),
                          selected: _selectedKarat == karat,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedKarat = karat;
                              });
                            }
                          },
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              
              const SizedBox(height: 16),
              
              // Weight Input
              TextFormField(
                controller: _weightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Weight (grams)',
                  prefixIcon: Icon(Icons.scale),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter weight';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // Purchase Price Input
              TextFormField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Purchase Price (per gram)',
                  prefixIcon: Icon(Icons.attach_money),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter purchase price';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // Date Selection
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: Text('Purchase Date: ${_formatDate(_selectedDate)}'),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setState(() {
                      _selectedDate = date;
                    });
                  }
                },
              ),
              
              // Notes Input
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  prefixIcon: Icon(Icons.note),
                ),
                maxLines: 2,
              ),
              
              const SizedBox(height: 24),
              
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          final item = PortfolioItem(
                            metal: _selectedMetal,
                            karat: _selectedKarat,
                            weight: double.parse(_weightController.text),
                            purchasePrice: double.parse(_priceController.text),
                            purchaseDate: _selectedDate,
                            notes: _notesController.text.isEmpty ? null : _notesController.text,
                          );
                          widget.onSave(item);
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFB800),
                      ),
                      child: Text(
                        widget.isEditing ? 'Save' : 'Add',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}