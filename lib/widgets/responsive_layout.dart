/// lib/widgets/responsive_layout.dart
library;

import "package:flutter/material.dart";

/// Breakpointy pro různĂ© velikosti zařízení.
class ScreenBreakpoints {
 // Mobilní zařízení
 static const double mobileSmall = 320;
 static const double mobileMedium = 375;
 static const double mobileLarge = 414;

 // Tablety
 static const double tabletSmall = 600;
 static const double tabletMedium = 768;
 static const double tabletLarge = 900;

 // Desktopy
 static const double desktopSmall = 1024;
 static const double desktopMedium = 1280;
 static const double desktopLarge = 1440;
}

/// Enum reprezentující typ zařízení.
enum DeviceType {
 mobileSmall,
 mobileMedium,
 mobileLarge,
 tabletSmall,
 tabletMedium,
 tabletLarge,
 desktopSmall,
 desktopMedium,
 desktopLarge,
}

/// Widget pro responzivní layout, který poskytuje různĂ© widgety
/// v závislosti na velikosti obrazovky.
class ResponsiveLayout extends StatelessWidget {
 /// Builder pro mobilní zařízení.
 final Widget Function(BuildContext context)? mobileBuilder;

 /// Builder pro tablety.
 final Widget Function(BuildContext context)? tabletBuilder;

 /// Builder pro desktopy.
 final Widget Function(BuildContext context)? desktopBuilder;

 /// Výchozí builder, který se pouťije, pokud není definován
 /// specifický builder pro danou velikost obrazovky.
 final Widget Function(BuildContext context) defaultBuilder;

 const ResponsiveLayout({
   super.key,
   this.mobileBuilder,
   this.tabletBuilder,
   this.desktopBuilder,
   required this.defaultBuilder,
 });

 @override
 Widget build(BuildContext context) {
   return LayoutBuilder(
     builder: (context, constraints) {
       final deviceType = _getDeviceType(constraints.maxWidth);

       // Desktop layout
       if (_isDesktop(deviceType) && desktopBuilder != null) {
         return desktopBuilder!(context);
       }

       // Tablet layout
       if (_isTablet(deviceType) && tabletBuilder != null) {
         return tabletBuilder!(context);
       }

       // Mobile layout
       if (_isMobile(deviceType) && mobileBuilder != null) {
         return mobileBuilder!(context);
       }

       // Default layout
       return defaultBuilder(context);
     },
   );
 }

 /// Určí typ zařízení podle Ĺˇířky obrazovky.
 DeviceType _getDeviceType(double width) {
   if (width < ScreenBreakpoints.mobileSmall) {
     return DeviceType.mobileSmall;
   } else if (width < ScreenBreakpoints.mobileMedium) {
     return DeviceType.mobileMedium;
   } else if (width < ScreenBreakpoints.mobileLarge) {
     return DeviceType.mobileLarge;
   } else if (width < ScreenBreakpoints.tabletSmall) {
     return DeviceType.tabletSmall;
   } else if (width < ScreenBreakpoints.tabletMedium) {
     return DeviceType.tabletMedium;
   } else if (width < ScreenBreakpoints.tabletLarge) {
     return DeviceType.tabletLarge;
   } else if (width < ScreenBreakpoints.desktopSmall) {
     return DeviceType.desktopSmall;
   } else if (width < ScreenBreakpoints.desktopMedium) {
     return DeviceType.desktopMedium;
   } else {
     return DeviceType.desktopLarge;
   }
 }

 /// Kontroluje, zda je zařízení mobilní.
 bool _isMobile(DeviceType deviceType) {
   return deviceType == DeviceType.mobileSmall ||
          deviceType == DeviceType.mobileMedium ||
          deviceType == DeviceType.mobileLarge;
 }

 /// Kontroluje, zda je zařízení tablet.
 bool _isTablet(DeviceType deviceType) {
   return deviceType == DeviceType.tabletSmall ||
          deviceType == DeviceType.tabletMedium ||
          deviceType == DeviceType.tabletLarge;
 }

 /// Kontroluje, zda je zařízení desktop.
 bool _isDesktop(DeviceType deviceType) {
   return deviceType == DeviceType.desktopSmall ||
          deviceType == DeviceType.desktopMedium ||
          deviceType == DeviceType.desktopLarge;
 }
}

/// Widget, který vrací různĂ© widgety v závislosti na orientaci zařízení.
class OrientationLayout extends StatelessWidget {
 /// Builder pro portrĂ©tní orientaci.
 final Widget Function(BuildContext context) portraitBuilder;

 /// Builder pro landscape orientaci.
 final Widget Function(BuildContext context) landscapeBuilder;

 const OrientationLayout({
   super.key,
   required this.portraitBuilder,
   required this.landscapeBuilder,
 });

 @override
 Widget build(BuildContext context) {
   return OrientationBuilder(
     builder: (context, orientation) {
       if (orientation == Orientation.portrait) {
         return portraitBuilder(context);
       } else {
         return landscapeBuilder(context);
       }
     },
   );
 }
}

/// RozĹˇíření pro získání informací o velikosti obrazovky v kontextu.
extension ScreenSizeExtension on BuildContext {
 /// Vrací Ĺˇířku obrazovky.
 double get screenWidth => MediaQuery.of(this).size.width;

 /// Vrací výĹˇku obrazovky.
 double get screenHeight => MediaQuery.of(this).size.height;

 /// Vrací orientaci obrazovky.
 Orientation get orientation => MediaQuery.of(this).orientation;

 /// Kontroluje, zda je zařízení mobilní.
 bool get isMobile => screenWidth < ScreenBreakpoints.tabletSmall;

 /// Kontroluje, zda je zařízení tablet.
 bool get isTablet => screenWidth >= ScreenBreakpoints.tabletSmall &&
                      screenWidth < ScreenBreakpoints.desktopSmall;

 /// Kontroluje, zda je zařízení desktop.
 bool get isDesktop => screenWidth >= ScreenBreakpoints.desktopSmall;

 /// Vrací typ zařízení.
 DeviceType get deviceType {
   final width = screenWidth;

   if (width < ScreenBreakpoints.mobileSmall) {
     return DeviceType.mobileSmall;
   } else if (width < ScreenBreakpoints.mobileMedium) {
     return DeviceType.mobileMedium;
   } else if (width < ScreenBreakpoints.mobileLarge) {
     return DeviceType.mobileLarge;
   } else if (width < ScreenBreakpoints.tabletSmall) {
     return DeviceType.tabletSmall;
   } else if (width < ScreenBreakpoints.tabletMedium) {
     return DeviceType.tabletMedium;
   } else if (width < ScreenBreakpoints.tabletLarge) {
     return DeviceType.tabletLarge;
   } else if (width < ScreenBreakpoints.desktopSmall) {
     return DeviceType.desktopSmall;
   } else if (width < ScreenBreakpoints.desktopMedium) {
     return DeviceType.desktopMedium;
   } else {
     return DeviceType.desktopLarge;
   }
 }
}

/// Třída s pomocnými metodami pro responzivní design.
class ResponsiveHelper {
 /// Vrací velikost fontu v závislosti na velikosti obrazovky.
 static double getResponsiveFontSize(BuildContext context, double baseFontSize) {
   final deviceType = context.deviceType;

   switch (deviceType) {
     case DeviceType.mobileSmall:
       return baseFontSize * 0.8;
     case DeviceType.mobileMedium:
       return baseFontSize * 0.9;
     case DeviceType.mobileLarge:
       return baseFontSize;
     case DeviceType.tabletSmall:
       return baseFontSize * 1.1;
     case DeviceType.tabletMedium:
       return baseFontSize * 1.2;
     case DeviceType.tabletLarge:
       return baseFontSize * 1.3;
     case DeviceType.desktopSmall:
       return baseFontSize * 1.2;
     case DeviceType.desktopMedium:
       return baseFontSize * 1.3;
     case DeviceType.desktopLarge:
       return baseFontSize * 1.4;
   }
 }

 /// Vrací velikost mezery v závislosti na velikosti obrazovky.
 static double getResponsiveSpacing(BuildContext context, double baseSpacing) {
   final deviceType = context.deviceType;

   switch (deviceType) {
     case DeviceType.mobileSmall:
       return baseSpacing * 0.8;
     case DeviceType.mobileMedium:
       return baseSpacing * 0.9;
     case DeviceType.mobileLarge:
       return baseSpacing;
     case DeviceType.tabletSmall:
       return baseSpacing * 1.2;
     case DeviceType.tabletMedium:
       return baseSpacing * 1.4;
     case DeviceType.tabletLarge:
       return baseSpacing * 1.6;
     case DeviceType.desktopSmall:
       return baseSpacing * 1.5;
     case DeviceType.desktopMedium:
       return baseSpacing * 1.7;
     case DeviceType.desktopLarge:
       return baseSpacing * 2.0;
   }
 }

 /// Vrací velikost ikony v závislosti na velikosti obrazovky.
 static double getResponsiveIconSize(BuildContext context, double baseIconSize) {
   final deviceType = context.deviceType;

   switch (deviceType) {
     case DeviceType.mobileSmall:
       return baseIconSize * 0.8;
     case DeviceType.mobileMedium:
       return baseIconSize * 0.9;
     case DeviceType.mobileLarge:
       return baseIconSize;
     case DeviceType.tabletSmall:
       return baseIconSize * 1.2;
     case DeviceType.tabletMedium:
       return baseIconSize * 1.3;
     case DeviceType.tabletLarge:
       return baseIconSize * 1.4;
     case DeviceType.desktopSmall:
       return baseIconSize * 1.3;
     case DeviceType.desktopMedium:
       return baseIconSize * 1.4;
     case DeviceType.desktopLarge:
       return baseIconSize * 1.5;
   }
 }
}

