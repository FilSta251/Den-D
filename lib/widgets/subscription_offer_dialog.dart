// lib/widgets/subscription_offer_dialog.dart

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../repositories/subscription_repository.dart';
import '../utils/logger.dart';
import '../models/subscription.dart'; // Ujistěte se, že tento soubor obsahuje definici SubscriptionType

class SubscriptionOfferDialog extends StatelessWidget {
  const SubscriptionOfferDialog({Key? key}) : super(key: key);

  void _subscribe(BuildContext context, {required bool yearly}) async {
    final SubscriptionRepository subscriptionRepository =
        GetIt.instance<SubscriptionRepository>();
    try {
      if (yearly) {
        // Volání metody pro roční předplatné (bez trialu)
        await subscriptionRepository.purchaseYearlySubscription(withTrial: false);
      } else {
        // Volání metody pro měsíční předplatné
        await subscriptionRepository.purchaseMonthlySubscription();
      }
      Navigator.of(context).pop(true);
    } catch (e) {
      Logger().logError("Subscription purchase failed", e);
      Navigator.of(context).pop(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Předplatné vyžadováno'),
      content: const Text(
        'Tato funkce je dostupná pouze pro předplatitele. Zvolte, prosím, některý z balíčků:\n\n'
        'Měsíční: 120 Kč\nRoční: 800 Kč',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Zrušit'),
        ),
        ElevatedButton(
          onPressed: () => _subscribe(context, yearly: false),
          child: const Text('Měsíční'),
        ),
        ElevatedButton(
          onPressed: () => _subscribe(context, yearly: true),
          child: const Text('Roční'),
        ),
      ],
    );
  }
}
