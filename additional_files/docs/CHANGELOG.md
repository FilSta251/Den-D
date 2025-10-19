# Changelog

Všechny významné změny tohoto projektu budou zaznamenány v tomto souboru.

Formát se řídí pravidly [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) a tento projekt dodržuje [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Added
- Nové funkce ve vývoji, například další lokalizace, rozšířená správa uživatelských profilů a optimalizace UI pro různé zařízení.
- Možnost přidání pokročilých analytických funkcí.
- Vylepšení správy předplatného a in-app nákupů.

### Changed
- Probíhají refaktoringy kódu pro zvýšení škálovatelnosti a údržby.
- Aktualizace závislostí na novější verze, pokud to bude možné bez narušení kompatibility.

### Fixed
- Opravy chyb zjištěných v beta testování.

---

## [1.0.0] - 2023-02-01
### Added
- **Inicialní vydání Wedding Planner:**
  - **Autentizace:** Implementována autentizace uživatelů pomocí Firebase Auth.
  - **Správa úkolů:** Možnost vytváření, úpravy, mazání a filtrování úkolů.
  - **Sledování výdajů:** Modul pro správu finančních výdajů spojených se svatbou.
  - **Plánování událostí:** Funkce pro plánování a správu událostí (např. zkušební večeře, obřad, recepce).
  - **Zprávy a chat:** Implementován chat pro komunikaci mezi uživateli a dodavateli.
  - **Správa pomocníků:** Evidence pomocníků a jejich rolí.
  - **Informace o svatbě:** Modul pro správu detailů svatby (datum, místo, rozpočet, jména).
  - **Předplatné a platby:** Integrace in-app nákupů pro prémiové funkce.
  - **Notifikace:** Podpora lokálních upozornění pomocí `flutter_local_notifications`.
  - **Analytika & hlášení chyb:** Implementace Firebase Analytics a Crashlytics.
  - **Lokalizace:** Podpora vícejazyčnosti (angličtina, čeština).
  - **Responzivní design:** Optimalizované UI pro různé velikosti obrazovek.
  - **CI/CD & Deployment:** Konfigurace pro GitHub Actions, GitLab CI, CircleCI a deployment skripty.
  - **Dependency Injection:** Použití GetIt pro správu závislostí.
  - **Offline úložiště:** Implementováno pomocí SharedPreferences.

### Changed
- Nastavení projektové struktury a architektury pro modulární vývoj.
- Vylepšení UI komponent pro konzistentní vzhled a lepší uživatelský zážitek.

### Fixed
- Opravy chyb v synchronizaci dat mezi Firestore a lokální cache.
- Opravy chyb v navigační logice a předávání závislostí mezi obrazovkami.
- Řešení drobných chyb v validaci vstupních dat.

---

*This project was built with passion using Flutter and Firebase. Enjoy planning your wedding with Wedding Planner!*
