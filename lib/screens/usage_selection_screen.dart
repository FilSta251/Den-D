import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class UsageSelectionScreen extends StatelessWidget {
  const UsageSelectionScreen({super.key});

  // Navigáční funkce "“ odstranili jsme volbu 'pomahat'
  void _selectOption(BuildContext context, String optionKey) {
    if (optionKey == 'planovat') {
      Navigator.pushReplacementNamed(context, '/introduction');
    } else if (optionKey == 'dodavatel') {
      Navigator.pushReplacementNamed(context, '/supplierAuth');
    }
  }

  IconData _getIconForOption(String optionKey) {
    switch (optionKey) {
      case 'planovat':
        return Icons.event;
      case 'dodavatel':
        return Icons.business;
      default:
        return Icons.help_outline;
    }
  }

  Widget _buildOptionCard(BuildContext context, String optionKey, String title,
      String description) {
    return GestureDetector(
      onTap: () => _selectOption(context, optionKey),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(
                _getIconForOption(optionKey),
                size: 48,
                color: Colors.pink,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style:
                          const TextStyle(fontSize: 16, color: Colors.black54),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('usage_selection_title')),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              _buildOptionCard(
                context,
                'planovat',
                tr('option_planovat'),
                tr('option_planovat_desc'),
              ),
              _buildOptionCard(
                context,
                'dodavatel',
                tr('option_dodavatel'),
                tr('option_dodavatel_desc'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
