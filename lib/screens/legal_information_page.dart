import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class LegalInformationPage extends StatelessWidget {
  const LegalInformationPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('legal_information_title', fallback: 'Právní informace')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          tr('legal_information_content', fallback: 'Právní informace

Obchodní údaje

Provozovatel aplikace:

Název firmy: [Filip Šťasný]
Adresa sídla: [Starovice 251]
IČO: [17364612]
DIČ: [CZ17364612]
E-mail: [info@stastnyfoto.com]
Telefon: [604733111]

Podmínky užívání

Používáním aplikace uživatel souhlasí s těmito podmínkami a je povinen je dodržovat. Aplikace slouží k plánování a organizaci svateb a souvisejících událostí. Uživatelé jsou povinni používat aplikaci v souladu s platnými právními předpisy České republiky a Evropské unie.

Ochrana osobních údajů (GDPR)

Vaše osobní údaje jsou zpracovávány v souladu s Nařízením Evropského parlamentu a Rady (EU) 2016/679 (GDPR). Shromažďujeme a zpracováváme pouze nezbytné údaje potřebné pro poskytování služeb aplikace. Máte právo požádat o přístup ke svým osobním údajům, jejich opravu, vymazání, omezení zpracování či přenositelnost dat.

Pro více informací o ochraně osobních údajů se obraťte na e-mail uvedený v kontaktních údajích.

Platby a předplatné

V aplikaci nabízíme měsíční nebo roční předplatné, které uživatelům umožňuje přístup k plným funkcím aplikace. Ceny jsou uvedeny v českých korunách (Kč). Zakoupením předplatného potvrzujete, že souhlasíte s podmínkami platby a automatickou obnovou předplatného, pokud jej ručně nezrušíte.

Reklamační řád

V případě problémů s aplikací nebo platbami nás kontaktujte na uvedeném e-mailu nebo telefonicky. Vaši reklamaci vyřídíme v nejkratším možném termínu, nejpozději však do 30 dnů od jejího přijetí.

Autorská práva

Obsah aplikace (texty, obrázky, kód a další materiály) je chráněn autorským zákonem. Jakékoli kopírování, šíření či jiná manipulace bez výslovného souhlasu autora aplikace jsou zakázány.

Závěrečná ustanovení

Tyto podmínky nabývají účinnosti okamžikem zveřejnění v aplikaci. Vyhrazujeme si právo na jejich změnu, přičemž nové znění podmínek nabývá účinnosti v okamžiku jejich zveřejnění.'),
          style: Theme.of(context).textTheme.bodyText2,
        ),
      ),
    );
  }
}
