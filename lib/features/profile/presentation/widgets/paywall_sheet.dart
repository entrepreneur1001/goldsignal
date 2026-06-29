import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class PaywallSheet {
  static Future<void> show(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr('profile.pro_unavailable_msg')),
      ),
    );
  }
}
