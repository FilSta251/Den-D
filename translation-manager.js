#!/usr/bin/env node

/**
 * Zjednodušený Translation Management System
 * Bez externích závislostí - pouze Node.js built-in moduly
 */

const fs = require('fs');
const path = require('path');

// Konfigurace jazyků a regionů
const LANGUAGES = {
  'cs': { name: 'Čeština', currency: 'CZK', symbol: 'Kč', prices: { monthly: 120, yearly: 800 }},
  'en': { name: 'English', currency: 'USD', symbol: '$', prices: { monthly: 4.99, yearly: 39.99 }},
  'de': { name: 'Deutsch', currency: 'EUR', symbol: '€', prices: { monthly: 9.99, yearly: 79.99 }},
  'es': { name: 'Español', currency: 'EUR', symbol: '€', prices: { monthly: 9.99, yearly: 79.99 }},
  'fr': { name: 'Français', currency: 'EUR', symbol: '€', prices: { monthly: 9.99, yearly: 79.99 }},
  'pl': { name: 'Polski', currency: 'PLN', symbol: 'zł', prices: { monthly: 30, yearly: 200 }},
  'uk': { name: 'Українська', currency: 'UAH', symbol: 'грн', prices: { monthly: 150, yearly: 1200 }}
};

// Základní překlady pro všechny jazyky
const TRANSLATIONS = {
  cs: {
    app_name: "Plánovač Svatby",
    welcome: "Vítejte",
    login: "Přihlásit se",
    register: "Registrovat se",
    email: "Email",
    password: "Heslo",
    save: "Uložit",
    cancel: "Zrušit",
    delete: "Smazat",
    edit: "Upravit",
    add: "Přidat",
    home: "Domů",
    guests: "Hosté",
    budget: "Rozpočet",
    settings: "Nastavení",
    wedding_date: "Datum svatby",
    venue: "Místo svatby",
    budget_amount: "Rozpočet ({symbol})",
    monthly_price: "{monthly} {symbol}/měsíc",
    yearly_price: "{yearly} {symbol}/rok",
    error_network: "Chyba sítě",
    error_server: "Chyba serveru",
    success_saved: "Úspěšně uloženo"
  },
  
  en: {
    app_name: "Wedding Planner",
    welcome: "Welcome",
    login: "Log In",
    register: "Register",
    email: "Email",
    password: "Password",
    save: "Save",
    cancel: "Cancel",
    delete: "Delete",
    edit: "Edit",
    add: "Add",
    home: "Home",
    guests: "Guests",
    budget: "Budget",
    settings: "Settings",
    wedding_date: "Wedding Date",
    venue: "Wedding Venue",
    budget_amount: "Budget ({symbol})",
    monthly_price: "{symbol}{monthly}/month",
    yearly_price: "{symbol}{yearly}/year",
    error_network: "Network Error",
    error_server: "Server Error",
    success_saved: "Successfully Saved"
  },
  
  de: {
    app_name: "Hochzeitsplaner",
    welcome: "Willkommen",
    login: "Anmelden",
    register: "Registrieren",
    email: "E-Mail",
    password: "Passwort",
    save: "Speichern",
    cancel: "Abbrechen",
    delete: "Löschen",
    edit: "Bearbeiten",
    add: "Hinzufügen",
    home: "Startseite",
    guests: "Gäste",
    budget: "Budget",
    settings: "Einstellungen",
    wedding_date: "Hochzeitsdatum",
    venue: "Hochzeitslocation",
    budget_amount: "Budget ({symbol})",
    monthly_price: "{monthly} {symbol}/Monat",
    yearly_price: "{yearly} {symbol}/Jahr",
    error_network: "Netzwerkfehler",
    error_server: "Serverfehler",
    success_saved: "Erfolgreich gespeichert"
  },
  
  es: {
    app_name: "Planificador de Bodas",
    welcome: "Bienvenido",
    login: "Iniciar sesión",
    register: "Registrarse",
    email: "Email",
    password: "Contraseña",
    save: "Guardar",
    cancel: "Cancelar",
    delete: "Eliminar",
    edit: "Editar",
    add: "Añadir",
    home: "Inicio",
    guests: "Invitados",
    budget: "Presupuesto",
    settings: "Configuración",
    wedding_date: "Fecha de la boda",
    venue: "Lugar de la boda",
    budget_amount: "Presupuesto ({symbol})",
    monthly_price: "{monthly} {symbol}/mes",
    yearly_price: "{yearly} {symbol}/año",
    error_network: "Error de red",
    error_server: "Error del servidor",
    success_saved: "Guardado exitosamente"
  },
  
  fr: {
    app_name: "Planificateur de Mariage",
    welcome: "Bienvenue",
    login: "Se connecter",
    register: "S'inscrire",
    email: "Email",
    password: "Mot de passe",
    save: "Enregistrer",
    cancel: "Annuler",
    delete: "Supprimer",
    edit: "Modifier",
    add: "Ajouter",
    home: "Accueil",
    guests: "Invités",
    budget: "Budget",
    settings: "Paramètres",
    wedding_date: "Date du mariage",
    venue: "Lieu du mariage",
    budget_amount: "Budget ({symbol})",
    monthly_price: "{monthly} {symbol}/mois",
    yearly_price: "{yearly} {symbol}/an",
    error_network: "Erreur réseau",
    error_server: "Erreur serveur",
    success_saved: "Enregistré avec succès"
  },
  
  pl: {
    app_name: "Planner Ślubu",
    welcome: "Witamy",
    login: "Zaloguj się",
    register: "Zarejestruj się",
    email: "Email",
    password: "Hasło",
    save: "Zapisz",
    cancel: "Anuluj",
    delete: "Usuń",
    edit: "Edytuj",
    add: "Dodaj",
    home: "Strona główna",
    guests: "Goście",
    budget: "Budżet",
    settings: "Ustawienia",
    wedding_date: "Data ślubu",
    venue: "Miejsce ślubu",
    budget_amount: "Budżet ({symbol})",
    monthly_price: "{monthly} {symbol}/miesiąc",
    yearly_price: "{yearly} {symbol}/rok",
    error_network: "Błąd sieci",
    error_server: "Błąd serwera",
    success_saved: "Pomyślnie zapisano"
  },
  
  uk: {
    app_name: "Планувальник Весіль",
    welcome: "Ласкаво просимо",
    login: "Увійти",
    register: "Зареєструватися",
    email: "Email",
    password: "Пароль",
    save: "Зберегти",
    cancel: "Скасувати",
    delete: "Видалити",
    edit: "Редагувати",
    add: "Додати",
    home: "Головна",
    guests: "Гості",
    budget: "Бюджет",
    settings: "Налаштування",
    wedding_date: "Дата весілля",
    venue: "Місце весілля",
    budget_amount: "Бюджет ({symbol})",
    monthly_price: "{monthly} {symbol}/міс",
    yearly_price: "{yearly} {symbol}/рік",
    error_network: "Помилка мережі",
    error_server: "Помилка сервера",
    success_saved: "Успішно збережено"
  }
};

class SimpleTranslationManager {
  constructor() {
    this.outputDir = './translations';
    this.ensureOutputDir();
  }

  ensureOutputDir() {
    if (!fs.existsSync(this.outputDir)) {
      fs.mkdirSync(this.outputDir, { recursive: true });
    }
  }

  // Aplikace regionálních nastavení
  applyRegionalSettings() {
    console.log('🌍 Aplikuji regionální nastavení...');
    
    Object.keys(LANGUAGES).forEach(locale => {
      const config = LANGUAGES[locale];
      const translation = { ...TRANSLATIONS[locale] };
      
      // Nahradí placeholdery skutečnými hodnotami
      Object.keys(translation).forEach(key => {
        if (typeof translation[key] === 'string') {
          translation[key] = translation[key]
            .replace(/{symbol}/g, config.symbol)
            .replace(/{monthly}/g, config.prices.monthly)
            .replace(/{yearly}/g, config.prices.yearly);
        }
      });
      
      // Přidá metadata
      translation._meta = {
        version: "1.0.0",
        language: config.name,
        currency: config.currency,
        symbol: config.symbol,
        lastUpdated: new Date().toISOString(),
        completeness: 100
      };
      
      TRANSLATIONS[locale] = translation;
    });
  }

  // Uložení překladů
  saveTranslations() {
    console.log('💾 Ukládám překlady...');
    
    Object.keys(LANGUAGES).forEach(locale => {
      const filePath = path.join(this.outputDir, `${locale}.json`);
      
      fs.writeFileSync(
        filePath,
        JSON.stringify(TRANSLATIONS[locale], null, 2),
        'utf8'
      );
      
      console.log(`✅ Uloženo ${locale}.json`);
    });
  }

  // Validace překladů
  validateTranslations() {
    console.log('🔍 Validuji překlady...');
    
    const baseKeys = Object.keys(TRANSLATIONS.cs).filter(key => key !== '_meta');
    const issues = [];

    Object.keys(LANGUAGES).forEach(locale => {
      if (locale === 'cs') return;
      
      const currentKeys = Object.keys(TRANSLATIONS[locale] || {}).filter(key => key !== '_meta');
      const missing = baseKeys.filter(key => !currentKeys.includes(key));
      const extra = currentKeys.filter(key => !baseKeys.includes(key));
      
      if (missing.length > 0) {
        issues.push(`${locale}: Chybí ${missing.length} klíčů - ${missing.join(', ')}`);
      }
      
      if (extra.length > 0) {
        issues.push(`${locale}: Navíc ${extra.length} klíčů - ${extra.join(', ')}`);
      }
    });

    if (issues.length === 0) {
      console.log('✅ Všechny překlady jsou kompletní!');
    } else {
      console.log('⚠️  Nalezeny problémy:');
      issues.forEach(issue => console.log(`   ${issue}`));
    }

    return issues;
  }

  // Export do jednoduchého CSV formátu
  exportToSimpleCSV() {
    console.log('📊 Exportuji do CSV...');
    
    const baseKeys = Object.keys(TRANSLATIONS.cs).filter(key => key !== '_meta');
    
    let csvContent = 'Key';
    Object.keys(LANGUAGES).forEach(locale => {
      csvContent += `,${LANGUAGES[locale].name}`;
    });
    csvContent += '\n';

    baseKeys.forEach(key => {
      csvContent += key;
      Object.keys(LANGUAGES).forEach(locale => {
        const value = TRANSLATIONS[locale][key] || '';
        csvContent += `,"${value.replace(/"/g, '""')}"`;
      });
      csvContent += '\n';
    });

    const csvPath = path.join(this.outputDir, 'translations.csv');
    fs.writeFileSync(csvPath, csvContent, 'utf8');
    console.log(`✅ Exportováno do ${csvPath}`);
  }

  // Generování TypeScript definic
  generateTypeDefinitions() {
    console.log('📝 Generuji TypeScript definice...');
    
    const baseKeys = Object.keys(TRANSLATIONS.cs).filter(key => key !== '_meta');
    
    const typeDefinition = `// Auto-generated translation types
export interface Translation {
${baseKeys.map(key => `  ${key}: string;`).join('\n')}
}

export type TranslationKey = keyof Translation;
export type SupportedLocale = ${Object.keys(LANGUAGES).map(l => `'${l}'`).join(' | ')};

export const supportedLocales: SupportedLocale[] = [${Object.keys(LANGUAGES).map(l => `'${l}'`).join(', ')}];
`;

    const typesPath = path.join(this.outputDir, 'types.ts');
    fs.writeFileSync(typesPath, typeDefinition, 'utf8');
    console.log(`✅ Vygenerováno ${typesPath}`);
  }

  // Generování indexového souboru
  generateIndex() {
    console.log('📋 Generuji index soubor...');
    
    const imports = Object.keys(LANGUAGES).map(locale => 
      `import ${locale} from './${locale}.json';`
    ).join('\n');

    const exports = Object.keys(LANGUAGES).map(locale => 
      `  '${locale}': ${locale}`
    ).join(',\n');

    const indexContent = `${imports}

export const translations = {
${exports}
};

export const supportedLocales = [${Object.keys(LANGUAGES).map(l => `'${l}'`).join(', ')}];

export const languageNames = {
${Object.keys(LANGUAGES).map(locale => 
  `  '${locale}': '${LANGUAGES[locale].name}'`
).join(',\n')}
};

export default translations;
`;

    const indexPath = path.join(this.outputDir, 'index.js');
    fs.writeFileSync(indexPath, indexContent, 'utf8');
    console.log(`✅ Vygenerováno ${indexPath}`);
  }

  // Základní testy
  runBasicTests() {
    console.log('🧪 Spouští základní testy...');
    
    let passed = 0;
    let failed = 0;

    // Test 1: Kontrola prázdných hodnot
    console.log('Test 1: Kontrola prázdných hodnot');
    let emptyFound = false;
    Object.keys(LANGUAGES).forEach(locale => {
      Object.keys(TRANSLATIONS[locale]).forEach(key => {
        if (key !== '_meta' && (!TRANSLATIONS[locale][key] || TRANSLATIONS[locale][key].trim() === '')) {
          console.log(`❌ Prázdná hodnota: ${locale}.${key}`);
          emptyFound = true;
        }
      });
    });
    
    if (!emptyFound) {
      console.log('✅ Žádné prázdné hodnoty');
      passed++;
    } else {
      failed++;
    }

    // Test 2: Konzistence klíčů
    console.log('Test 2: Konzistence klíčů');
    const issues = this.validateTranslations();
    if (issues.length === 0) {
      console.log('✅ Všechny jazyky mají stejné klíče');
      passed++;
    } else {
      console.log('❌ Nesrovnalosti v klíčích');
      failed++;
    }

    console.log(`\n📊 Výsledky testů: ${passed} úspěšných, ${failed} neúspěšných`);
    return { passed, failed };
  }

  // Hlavní metoda
  run(options = {}) {
    console.log('🚀 Spouštím Translation Management System\n');
    
    // Aplikace regionálních nastavení
    this.applyRegionalSettings();
    
    // Validace
    if (options.validate !== false) {
      this.validateTranslations();
    }
    
    // Uložení překladů
    this.saveTranslations();
    
    // Export do CSV
    if (options.exportCsv) {
      this.exportToSimpleCSV();
    }
    
    // Generování TypeScript definic
    if (options.generateTypes) {
      this.generateTypeDefinitions();
    }
    
    // Generování index souboru
    if (options.generateIndex) {
      this.generateIndex();
    }
    
    // Spuštění testů
    if (options.runTests) {
      this.runBasicTests();
    }
    
    console.log('\n✅ Správa překladů dokončena!');
  }
}

// CLI interface
if (require.main === module) {
  const args = process.argv.slice(2);
  const options = {};
  
  // Parse command line arguments
  args.forEach(arg => {
    switch (arg) {
      case '--export-csv':
        options.exportCsv = true;
        break;
      case '--generate-types':
        options.generateTypes = true;
        break;
      case '--generate-index':
        options.generateIndex = true;
        break;
      case '--run-tests':
        options.runTests = true;
        break;
      case '--all':
        options.exportCsv = true;
        options.generateTypes = true;
        options.generateIndex = true;
        options.runTests = true;
        break;
      case '--help':
        console.log(`
Zjednodušený Translation Management System

Použití: node simple-translation-manager.js [options]

Možnosti:
  --export-csv      Export překladů do CSV
  --generate-types  Generování TypeScript definic
  --generate-index  Generování index souboru
  --run-tests       Spuštění základních testů
  --all             Spuštění všech operací
  --help            Zobrazení této nápovědy

Příklady:
  node simple-translation-manager.js --all
  node simple-translation-manager.js --export-csv --run-tests
  node simple-translation-manager.js --generate-types
        `);
        process.exit(0);
        break;
    }
  });
  
  // Spuštění translation manageru
  const manager = new SimpleTranslationManager();
  manager.run(options);
}

module.exports = SimpleTranslationManager;