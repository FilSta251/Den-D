# Design Document for Wedding Planner Application

## 1. Úvod

**Wedding Planner** je komplexní mobilní aplikace určená k usnadnění plánování svatby. Aplikace nabízí uživatelům nástroje pro správu úkolů, výdajů, událostí, zpráv, pomocníků, informací o svatbě a předplatného. Tento dokument popisuje návrh aplikace, její architekturu, technologický stack, uživatelské rozhraní a další klíčové aspekty.

## 2. Cíle a Požadavky

### 2.1 Funkční Požadavky
- **Autentizace uživatelů:** Přihlášení, registrace a správa účtů prostřednictvím Firebase Auth.
- **Správa úkolů:** Vytváření, úprava, mazání a filtrování úkolů s termíny a prioritami.
- **Finanční přehled:** Sledování a správa výdajů spojených se svatbou.
- **Plánování událostí:** Organizace a správa událostí (např. zkušební večeře, obřad, recepce).
- **Komunikace:** Integrovaný chat a zprávy mezi uživateli a dodavateli.
- **Správa pomocníků:** Evidence pomocníků, jejich rolí a kontaktních informací.
- **Informace o svatbě:** Ukládání detailů svatby (datum, místo, rozpočet, jména).
- **Předplatné a platby:** Integrace in-app nákupů pro přístup k prémiovým funkcím.
- **Notifikace:** Lokální a push upozornění.
- **Analytika a hlášení chyb:** Sledování výkonu a stabilita aplikace pomocí Firebase Analytics a Crashlytics.
- **Lokalizace:** Podpora vícejazyčnosti (např. angličtina, čeština).
- **Responzivní UI:** Optimalizované uživatelské rozhraní pro různé velikosti obrazovek.

### 2.2 Ne-funkční Požadavky
- **Modulární architektura:** Jednotlivé moduly (modely, repozitáře, služby, obrazovky, widgety, utilitky) jsou odděleny pro lepší údržbu a rozšiřitelnost.
- **Bezpečnost:** Zabezpečená komunikace s backendem (např. Firebase), správná správa přístupových práv.
- **Výkon:** Optimalizace pro rychlé načítání dat a plynulý uživatelský zážitek.
- **Testovatelnost:** Implementace unit, widget a integračních testů.
- **Reproducibilita buildů:** Použití přesných verzí závislostí a CI/CD pipeline pro spolehlivé buildy.

## 3. Architektura a Technologický Stack

### 3.1 Architektura
Aplikace je navržena podle zásad **Clean Architecture** a **Modulární architektury** s jasným oddělením odpovědností:
- **Models:** Obsahují datové struktury (uživatel, úkol, výdaje, události, zprávy, pomocníci, svatební informace, předplatné).
- **Repositories:** Spravují komunikaci s backendem (např. Firebase Firestore) a poskytují CRUD operace a real-time synchronizaci.
- **Services:** Implementují klíčové funkce (autentizace, notifikace, platby, lokální úložiště, analytika, hlášení chyb).
- **Screens:** Uživatelské obrazovky, které tvoří uživatelské rozhraní.
- **Widgets:** Opakovaně použitelné komponenty (custom AppBar, navigační menu, chybové dialogy).
- **Utils:** Globální konstanty, validátory a další pomocné nástroje.
- **Dependency Injection:** Spravováno pomocí GetIt (service locator) pro předávání závislostí napříč aplikací.
- **CI/CD:** Konfigurace pro kontinuální integraci a nasazení (GitHub Actions, GitLab CI, CircleCI).

### 3.2 Technologický Stack
- **Flutter:** Pro vývoj multiplatformní mobilní aplikace (Android, iOS).
- **Firebase:** Pro backendové služby (Firestore, Auth, Analytics, Crashlytics).
- **GetIt:** Pro dependency injection.
- **SharedPreferences:** Pro lokální úložiště dat.
- **Fastlane a CI/CD nástroje:** Pro automatizaci buildů a nasazení.

## 4. Datový Model a Práce s Daty

### 4.1 Firestore
Datový model je strukturován jako kolekce:
- **users:** Informace o uživatelích.
- **tasks:** Úkoly a checklisty.
- **expenses:** Finanční výdaje.
- **events:** Události a plánované akce.
- **messages:** Chatové zprávy.
- **helpers:** Informace o pomocnících.
- **wedding_info:** Detailní informace o svatbě.
- **subscriptions:** Informace o předplatném.
- **payments:** Záznamy platebních transakcí.

### 4.2 Lokální Úložiště
LokálníStorageService využívá SharedPreferences k ukládání konfiguračních dat a případné cachování pro offline režim.

## 5. Uživatelské Rozhraní a UX

### 5.1 UI Design
- **Responzivní design:** Aplikace je optimalizována pro různé velikosti obrazovek.
- **Material Design:** Použití Flutter Material komponent pro konzistentní vzhled.
- **Custom témata:** Definovaná pomocí globálních konstant pro barvy, fonty a rozměry.
- **Lokalizace:** Podpora vícejazyčného rozhraní (angličtina, čeština).

### 5.2 UX
- **Intuitivní navigace:** Pomocí custom draweru a pojmenovaných tras.
- **Feedback uživatele:** Notifikace, chybové dialogy a progress indikátory.
- **Personalizace:** Uživatelé mohou upravovat svůj profil a nastavení.

## 6. CI/CD a Nasazení

- **CI/CD Pipeline:** Konfigurace pro GitHub Actions, GitLab CI a CircleCI jsou připraveny pro automatické testování a buildy.
- **Deployment:** Automatizované skripty (deploy.sh, Docker Compose, fastlane) pro nasazení aplikace na příslušné platformy.
- **Testování:** Sada unit, widget a integračních testů zajišťuje stabilitu a kvalitu kódu.

## 7. Bezpečnost

- **Autentizace a autorizace:** Firebase Auth pro bezpečné přihlašování a správu uživatelských účtů.
- **Šifrování dat:** Citlivá data jsou šifrována, lokální úložiště a komunikace s backendem využívají zabezpečené protokoly.
- **Hlášení chyb:** Firebase Crashlytics a vlastní logování pro sledování a opravu chyb v reálném čase.

## 8. Budoucí Rozšíření

- **Další platformy:** Možnost rozšíření podpory o web nebo desktop.
- **Rozšířená analytika:** Integrace dalších analytických nástrojů pro lepší sledování uživatelského chování.
- **Pokročilé platební možnosti:** Přidání dalších platebních metod a zlepšení správy předplatného.
- **Offline režim:** Vylepšení synchronizace dat a offline funkcionality pomocí pokročilejších úložišť.

## 9. Závěr

Tento design dokument poskytuje ucelený přehled o návrhu a architektuře aplikace Wedding Planner. Cílem je vytvořit robustní, bezpečnou a uživatelsky přívětivou aplikaci, která pomůže uživatelům snadno a efektivně plánovat jejich svatbu. Budoucí rozšíření a refaktoringy budou probíhat průběžně, aby byla aplikace stále aktuální a konkurenceschopná.

*This project was built with passion using Flutter and Firebase. Enjoy planning your wedding with Wedding Planner!*
