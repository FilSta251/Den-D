// lib/widgets/custom_app_bar.dart

import 'package:flutter/material.dart';

/// CustomAppBar je znovupoužitelný widget pro AppBar,
/// který umožňuje snadnou parametrizaci titulku, podtitulku, akcí, leading widgetu,
/// volitelně nastavitelné výšky a spodního widgetu (např. TabBar).
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  /// Hlavní titulek AppBaru.
  final String title;

  /// Volitelný podtitul, který se zobrazí pod hlavním titulkem.
  final String? subtitle;

  /// Seznam akčních widgetů umístěných v pravé části AppBaru.
  final List<Widget>? actions;

  /// Vlastní widget umístěný vlevo (např. tlačítko pro otevření Draweru nebo zpět).
  final Widget? leading;

  /// Volitelná výška AppBaru.
  final double? height;

  /// Volitelný spodní widget, např. TabBar.
  final Widget? bottom;

  /// Callback, který se zavolá při stisknutí tlačítka zpět, pokud [leading] není explicitně zadán.
  final VoidCallback? onBackPressed;

  const CustomAppBar({
    Key? key,
    required this.title,
    this.subtitle,
    this.actions,
    this.leading,
    this.height,
    this.bottom,
    this.onBackPressed,
  }) : super(key: key);

  @override
  Size get preferredSize {
    // Výchozí výška AppBaru (kToolbarHeight) plus výška spodního widgetu, pokud je nastaven.
    final double appBarHeight = height ?? kToolbarHeight;
    final double bottomHeight = bottom != null ? kTextTabBarHeight : 0.0;
    return Size.fromHeight(appBarHeight + bottomHeight);
  }

  @override
  Widget build(BuildContext context) {
    // Pokud není explicitně nastaven leading, a onBackPressed existuje, zobrazí se tlačítko zpět.
    Widget? effectiveLeading = leading;
    if (effectiveLeading == null && onBackPressed != null) {
      effectiveLeading = IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: onBackPressed,
        tooltip: 'Zpět',
      );
    }

    return AppBar(
      // Zajištění, že AppBar respektuje SafeArea (notch, status bar).
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
              style: Theme.of(context).textTheme.subtitle2,
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
      // Příklad: Možnost přidání gradientního pozadí (volitelné – odkomentujte, pokud je potřeba).
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
