/// lib/widgets/custom_app_bar.dart
library;

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

/// CustomAppBar je znovupouťitelný widget pro AppBar,
/// který umoťĹuje snadnou parametrizaci titulku, podtitulku, akcí, leading widgetu,
/// volitelně nastavitelnĂ© výĹˇky a spodního widgetu (např. TabBar).
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  /// Hlavní titulek AppBaru.
  final String title;

  /// Volitelný podtitul, který se zobrazí pod hlavním titulkem.
  final String? subtitle;

  /// Seznam akčních widgetů umístěných v pravĂ© části AppBaru.
  final List<Widget>? actions;

  /// Vlastní widget umístěný vlevo (např. tláčítko pro otevření Draweru nebo zpět).
  final Widget? leading;

  /// Volitelná výĹˇka AppBaru.
  final double? height;

  /// Volitelný spodní widget, např. TabBar.
  final Widget? bottom;

  /// Callback, který se zavolá při stisknutí tláčítka zpět, pokud [leading] není explicitně zadán.
  final VoidCallback? onBackPressed;

  const CustomAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.leading,
    this.height,
    this.bottom,
    this.onBackPressed,
  });

  @override
  Size get preferredSize {
    // Výchozí výĹˇka AppBaru (kToolbarHeight) plus výĹˇka spodního widgetu, pokud je nastaven.
    final double appBarHeight = height ?? kToolbarHeight;
    final double bottomHeight = bottom != null ? kTextTabBarHeight : 0.0;
    return Size.fromHeight(appBarHeight + bottomHeight);
  }

  @override
  Widget build(BuildContext context) {
    // Pokud není explicitně nastaven leading, a onBackPressed existuje, zobrazí se tláčítko zpět.
    Widget? effectiveLeading = leading;
    if (effectiveLeading == null && onBackPressed != null) {
      effectiveLeading = IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: onBackPressed,
        tooltip: tr('back'),
      );
    }

    return AppBar(
      // ZajiĹˇtění, ťe AppBar respektuje SafeArea (notch, status bar).
      automaticallyImplyLeading: false,
      leading: effectiveLeading,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).appBarTheme.titleTextStyle,
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.titleSmall,
            ),
        ],
      ),
      actions: actions,
      bottom: bottom != null
          ? PreferredSize(
              preferredSize: const Size.fromHeight(kTextTabBarHeight),
              child: bottom!,
            )
          : null,
      // Příklad: Moťnost přidání gradientního pozadí (volitelnĂ© "“ odkomentujte, pokud je potřeba).
      // flexibleSpace: Container(
      //   decoration: const BoxDecoration(
      //     gradient: LinearGradient(
      //       colors: [Colors.pink, Colors.deepPurple],
      //       begin: Alignment.topLeft,
      //       end: Alignment.bottomRight,
      //     ),
      //   ),
      // ),
    );
  }
}
