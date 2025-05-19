# Zachování veřejných tříd a metod, aby aplikace fungovala správně
-keep public class * {
    public protected *;
}

# Neupozorňovat na varování (pokud některé knihovny chybí nebo mají problémy)
-dontwarn **

# Povolení serializace pro Firebase (pokud používáte Firestore nebo Realtime Database)
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Povolení reflection pro databázové operace (důležité pro Firebase Firestore)
-keepattributes *Annotation*
-keep class * extends androidx.room.RoomDatabase { *; }
-keep class * extends com.google.firebase.firestore.DocumentSnapshot { *; }
-keep class * extends com.google.firebase.firestore.QueryDocumentSnapshot { *; }
-keep class * extends com.google.firebase.firestore.QuerySnapshot { *; }

# Povolení Google Play Services API
-keep class com.google.android.gms.** { *; }
-keep class com.google.common.** { *; }

# Povolení logování chyb (pokud používáte Firebase Crashlytics)
-keep class com.google.firebase.crashlytics.** { *; }

# Povolení Material Design knihoven (pro správné fungování UI)
-keep class com.google.android.material.** { *; }

# Zabránění odstranění tříd potřebných pro autentizaci
-keep class com.google.firebase.auth.** { *; }
-keep class com.google.firebase.auth.FirebaseUser { *; }
