import 'package:flutter/material.dart';

class PaywallSheet {
  static Future<void> show(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('GoldSignal Pro is temporarily unavailable.'),
      ),
    );
  }
}
