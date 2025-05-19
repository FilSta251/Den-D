# Wedding Planner

**Wedding Planner** je komplexní mobilní aplikace určená k usnadnění plánování vaší dokonalé svatby. Aplikace poskytuje nástroje pro správu úkolů, výdajů, událostí, zpráv, pomocníků, informací o svatbě a předplatného – vše na jednom místě. Aplikace je postavena pomocí Flutteru a cílí na platformy Android a iOS, přičemž využívá Firebase pro backendové služby.

---

## Obsah

- [Funkce](#funkce)
- [Architektura](#architektura)
- [Instalace](#instalace)
- [Testování](#testování)
- [Nasazení](#nasazení)
- [Příspěvky](#příspěvky)
- [Licence](#licence)
- [Kontakt](#kontakt)

---

## Funkce

- **Autentizace uživatele:** Bezpečné přihlášení a registrace pomocí Firebase Auth.
- **Správa úkolů:** Vytvářejte, upravujte, odstraňujte a filtrujte úkoly s termíny a prioritami.
- **Sledování výdajů:** Monitorujte a spravujte finanční výdaje spojené se svatbou.
- **Plánování událostí:** Organizujte události, jako jsou zkušební večeře, obřady a recepce.
- **Zprávy a chat:** Komunikujte s rodinou, přáteli nebo dodavateli.
- **Správa pomocníků:** Udržujte přehled o pomocnících, jejich rolích a kontaktních údajích.
- **Informace o svatbě:** Ukládejte detaily svatby, jako jsou datum, místo, jména a rozpočet.
- **Předplatné a platby:** Získejte přístup k prémiovým funkcím prostřednictvím in-app nákupů.
- **Notifikace:** Získávejte lokální a push upozornění.
- **Analytika & hlášení chyb:** Integrované Firebase Analytics a Crashlytics pro sledování výkonu a stability aplikace.
- **Lokalizace:** Podpora více jazyků (angličtina, čeština).
- **Responzivní UI:** Optimalizované uživatelské rozhraní pro různé velikosti obrazovek a platformy.

---

## Architektura

Projekt je strukturován do několika modulárních vrstev:

- **Models:** Datové struktury pro uživatele, úkoly, výdaje, události, zprávy, pomocníky, informace o svatbě a předplatné.
- **Repositories:** Řeší komunikaci s databází (Firestore), CRUD operace a real-time synchronizaci.
- **Services:** Implementují základní funkcionalitu, jako je autentizace, notifikace, platby, lokální úložiště, analytika a hlášení chyb.
- **Screens:** Uživatelské obrazovky (domovská, úkoly, profil, nastavení atd.).
- **Widgets:** Opakovaně použitelné komponenty, například vlastní AppBar, navigační menu, chybové dialogy.
- **Utils:** Konstanta, validátory a další pomocné nástroje.
- **Dependency Injection:** Spravováno přes GetIt (service locator) pro snadný přístup ke službám a repozitářům.
- **CI/CD a Nasazení:** Konfigurace pro GitHub Actions, GitLab CI, CircleCI, Docker a další nástroje.

---

## Instalace

### Požadavky

- [Flutter](https://flutter.dev/docs/get-started/install) (verze 3.x nebo vyšší)
- [Firebase CLI](https://firebase.google.com/docs/cli) (pokud používáte Firebase)
- [Fastlane](https://fastlane.tools/) (pro nasazení na Android a iOS)
- Konfigurovaný Firebase projekt se službami Firestore, Auth, Analytics a Crashlytics

### Kroky

1. **Klonujte repozitář:**

   ```bash
   git clone https://github.com/yourusername/wedding-planner.git
   cd wedding-planner
