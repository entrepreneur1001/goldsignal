import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PriceCard extends StatelessWidget {
  final String metal;
  final IconData icon;
  final Color color;
  final double pricePerOunce;
  final double pricePerGram;
  final String currency;
  final double change24h;
  final double changePercent;
  
  const PriceCard({
    super.key,
    required this.metal,
    required this.icon,
    required this.color,
    required this.pricePerOunce,
    required this.pricePerGram,
    required this.currency,
    required this.change24h,
    required this.changePercent,
  });
  
  bool get isPositive => change24h >= 0;
  
  @override
  Widget build(BuildContext context) {
    final numberFormat = NumberFormat('#,##0.00');
    
    return Card(
      elevation: 4,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha:0.1),
              color.withValues(alpha:0.05),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha:0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        metal,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(
                        'Live Price',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isPositive 
                          ? Colors.green.withValues(alpha:0.1)
                          : Colors.red.withValues(alpha:0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isPositive 
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          color: isPositive ? Colors.green : Colors.red,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${changePercent.toStringAsFixed(2)}%',
                          style: TextStyle(
                            color: isPositive ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Prices
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Per Ounce
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Per Ounce',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$currency ${numberFormat.format(pricePerOunce)}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ),
                  
                  Container(
                    height: 40,
                    width: 1,
                    color: Colors.grey.withValues(alpha:0.3),
                  ),
                  
                  // Per Gram
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Per Gram',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$currency ${numberFormat.format(pricePerGram)}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // 24h Change
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '24h Change: ',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      '${isPositive ? '+' : ''}$currency ${numberFormat.format(change24h)}',
                      style: TextStyle(
                        color: isPositive ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}