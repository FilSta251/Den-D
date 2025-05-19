// lib/widgets/error_widget.dart
import 'package:flutter/material.dart';

class CustomErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const CustomErrorWidget({Key? key, required this.message, required this.onRetry}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(message, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text("Zkusit znovu"),
          )
        ],
      ),
    );
  }
}
