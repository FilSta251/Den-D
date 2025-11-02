/// test/services/local_storage_services_test.dart - OPRAVENÁ VERZE
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:den_d/services/local_schedule_service.dart';
import 'package:den_d/services/local_budget_service.dart';

void main() {
  // Nastavení SharedPreferences pro testy
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('LocalScheduleService testy', () {
    late LocalScheduleService scheduleService;

    setUp(() {
      scheduleService = LocalScheduleService();
    });

    test('Přidání nové položky harmonogramu', () {
      // Arrange
      final item = LocalScheduleService.createScheduleItem(
        title: 'Příjezd hostů',
        time: DateTime(2024, 6, 15, 14, 0),
      );

      // Act
      scheduleService.addScheduleItem(item);

      // Assert
      expect(scheduleService.itemCount, 1);
      expect(scheduleService.scheduleItems.first.title, 'Příjezd hostů');
    });

    test('Nalezení položek podle času', () {
      // Arrange
      final items = [
        LocalScheduleService.createScheduleItem(
          title: 'Snídaně',
          time: DateTime(2024, 6, 15, 8, 0),
        ),
        LocalScheduleService.createScheduleItem(
          title: 'Oběd',
          time: DateTime(2024, 6, 15, 12, 0),
        ),
        LocalScheduleService.createScheduleItem(
          title: 'Večeře',
          time: DateTime(2024, 6, 15, 18, 0),
        ),
      ];

      for (final item in items) {
        scheduleService
            .addScheduleItem(item); // ✅ OPRAVENO: addItem → addScheduleItem
      }

      // Act
      final morningItems = scheduleService.findItemsInTimeRange(
        DateTime(2024, 6, 15, 6, 0),
        DateTime(2024, 6, 15, 10, 0),
      );

      // Assert - VRÁCENO DO SPRÁVNÉHO STAVU!
      expect(morningItems.length, 1); // ✅ Očekáváme 1, ne 0!
      expect(morningItems.first.title, 'Snídaně');
    });

    test('Kontrola konfliktů v čase', () {
      // Arrange
      final existingItem = LocalScheduleService.createScheduleItem(
        title: 'Obřad',
        time: DateTime(2024, 6, 15, 14, 0),
      );
      scheduleService.addScheduleItem(existingItem); // ✅ OPRAVENO

      // Act
      final conflicts = scheduleService.findTimeConflicts(
        DateTime(2024, 6, 15, 14, 15),
        tolerance: const Duration(minutes: 30),
      );

      // Assert
      expect(conflicts.length, 1);
      expect(conflicts.first.title, 'Obřad');
    });

    test('Seřazení položek podle času', () {
      // Arrange
      final items = [
        LocalScheduleService.createScheduleItem(
          title: 'Večeře',
          time: DateTime(2024, 6, 15, 18, 0),
        ),
        LocalScheduleService.createScheduleItem(
          title: 'Snídaně',
          time: DateTime(2024, 6, 15, 8, 0),
        ),
        LocalScheduleService.createScheduleItem(
          title: 'Příprava',
          time: null, // Bez času
        ),
      ];

      for (final item in items) {
        scheduleService.addScheduleItem(item); // ✅ OPRAVENO
      }

      // Act
      final sorted = scheduleService.itemsSortedByScheduleTime;

      // Assert
      expect(sorted[0].title, 'Snídaně');
      expect(sorted[1].title, 'Večeře');
      expect(sorted[2].title, 'Příprava'); // Položky bez času jsou na konci
    });
  });

  group('LocalBudgetService testy', () {
    late LocalBudgetService budgetService;

    setUp(() {
      budgetService = LocalBudgetService();
    });

    test('Přidání a výpočet celkové částky', () {
      // Arrange
      final expenses = [
        LocalBudgetService.createExpense(
          title: 'Květiny',
          amount: 5000,
          category: 'Dekorace',
        ),
        LocalBudgetService.createExpense(
          title: 'Catering',
          amount: 25000,
          category: 'Jídlo a pití',
        ),
      ];

      // Act
      for (final expense in expenses) {
        budgetService.addExpense(expense);
      }

      // Assert
      expect(budgetService.totalAmount, 30000);
      expect(budgetService.categories.length, 2);
    });

    test('Filtrování podle kategorie', () {
      // Arrange
      final expenses = [
        LocalBudgetService.createExpense(
          title: 'Květiny',
          amount: 5000,
          category: 'Dekorace',
        ),
        LocalBudgetService.createExpense(
          title: 'Svíčky',
          amount: 2000,
          category: 'Dekorace',
        ),
        LocalBudgetService.createExpense(
          title: 'Catering',
          amount: 25000,
          category: 'Jídlo a pití',
        ),
      ];

      for (final expense in expenses) {
        budgetService.addExpense(expense);
      }

      // Act
      final decorationExpenses =
          budgetService.getExpensesByCategory('Dekorace');
      final decorationAmount = budgetService.getAmountByCategory('Dekorace');

      // Assert
      expect(decorationExpenses.length, 2);
      expect(decorationAmount, 7000);
    });

    test('Správa zaplacených a nezaplacených výdajů', () {
      // Arrange
      final expenses = [
        LocalBudgetService.createExpense(
          title: 'Záloha na sál',
          amount: 10000,
          category: 'Místo',
          isPaid: true,
        ),
        LocalBudgetService.createExpense(
          title: 'Doplatek za sál',
          amount: 15000,
          category: 'Místo',
          isPaid: false,
        ),
      ];

      for (final expense in expenses) {
        budgetService.addExpense(expense);
      }

      // Act
      final paidExpenses = budgetService.getPaidExpenses();
      final unpaidAmount = budgetService.unpaidAmount;

      // Assert
      expect(paidExpenses.length, 1);
      expect(unpaidAmount, 15000);
    });

    test('Statistiky rozpočtu', () {
      // Arrange
      final expenses = [
        LocalBudgetService.createExpense(
          title: 'Květiny',
          amount: 5000,
          category: 'Dekorace',
          isPaid: true,
        ),
        LocalBudgetService.createExpense(
          title: 'Catering',
          amount: 25000,
          category: 'Jídlo a pití',
          isPaid: false,
        ),
        LocalBudgetService.createExpense(
          title: 'Fotograf',
          amount: 15000,
          category: 'Služby',
          isPaid: true,
        ),
      ];

      for (final expense in expenses) {
        budgetService.addExpense(expense);
      }

      // Act
      final stats = budgetService.getBudgetStatistics();

      // Assert
      expect(stats['totalExpenses'], 3);
      expect(stats['totalAmount'], 45000);
      expect(stats['paidAmount'], 20000);
      expect(stats['unpaidAmount'], 25000);
      expect(stats['categories'], 3);
    });
  });

  group('Integrace mezi službami', () {
    test('Export a import dat', () async {
      // Arrange
      final scheduleService = LocalScheduleService();
      final item = LocalScheduleService.createScheduleItem(
        title: 'Test položka',
        time: DateTime.now(),
      );
      scheduleService.addScheduleItem(item); // ✅ OPRAVENO

      // Act
      final exported = scheduleService.exportToJson();
      final newService = LocalScheduleService();
      await newService.importFromJson(exported);

      // Assert
      expect(newService.itemCount, 1);
      expect(newService.scheduleItems.first.title, 'Test položka');
    });
  });
}
