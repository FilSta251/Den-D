# Vylepšení Svatební Aplikace

Tato aktualizace zahrnuje několik významných vylepšení architektury a kódu:

## 1. Centralizace navigace

- Vytvořená třída `AppRouter` se statickými konstantami pro cesty a metodou `generateRoute`
- Odstraněna duplicita mezi `main.dart` a `routes.dart`
- Jednotný způsob navigace v celé aplikaci

## 2. Unifikace témat

- Centralizované definice tématu v `AppTheme`
- Konzistentní vzhled napříč aplikací
- Podpora světlého a tmavého režimu

## 3. Synchronizace harmonogramu

- Přidán `CloudScheduleService` pro ukládání harmonogramu do Firestore
- Implementován `ScheduleManager` pro synchronizaci mezi lokálním a cloudovým úložištěm
- Automatická synchronizace při změnách

## 4. Jednotný state management

- Vytvořen `BaseNotifier` pro sdílené chování stavů
- Konzistentní správa stavů načítání, chyb a dat
- Lepší zobrazení stavů v UI

## 5. Sdílené UI komponenty

- Globální widgety v `GlobalWidgets`
- Předpřipravené komponenty pro tlačítka, loadery, chybové stavy
- Konzistentní vzhled a chování

## Jak používat nové funkce

### Navigace

```dart
// Import
import '../router/app_router.dart';

// Použití
Navigator.pushNamed(context, Routes.weddingInfo);
```

### Téma

```dart
// Import
import '../theme/app_theme.dart';

// Použití v MaterialApp
theme: AppTheme.lightTheme,
darkTheme: AppTheme.darkTheme,
```

### NavigationService

```dart
// Získání instance přes DI
final navigationService = di.locator<NavigationService>();

// Navigace
navigationService.navigateTo(Routes.weddingInfo);
```

### ScheduleManager

```dart
// Získání instance přes DI
final scheduleManager = di.locator<ScheduleManager>();

// Přidání položky
scheduleManager.addItem(newItem);

// Synchronizace
await scheduleManager.syncWithCloud();
```

### GlobalWidgets

```dart
// Import
import '../widgets/global_widgets.dart';

// Použití
GlobalWidgets.primaryButton(
  text: 'Uložit',
  onPressed: () => saveData(),
);

// Zobrazení dialogu
final confirmed = await GlobalWidgets.showConfirmationDialog(
  context: context,
  title: 'Smazat položku?',
  message: 'Opravdu chcete smazat tuto položku?',
);
```
