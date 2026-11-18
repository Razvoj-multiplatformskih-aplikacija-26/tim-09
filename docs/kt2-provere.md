# KT2: rezultati provera

Datum: 18. novembar 2026. Grana: `feature/kt2-server`.

Proveren je postojeći KT1 interfejs i implementirani KT2 server, baza, autentifikacija, ugovor i mapper. Mobilna i backoffice aplikacija još koriste fake adaptere. Njihov budući mrežni adapter, AuthBloc i skladištenje prijave nisu deo potvrđenog toka aplikacija sa serverom.

## Automatski testovi

| Grupa | Prošlo |
|---|---:|
| domain, use_cases, blocs, contracts, api_mapping | 82 |
| Relic i PostgreSQL integracija | 30 |
| Mobilni widget testovi | 24 |
| Backoffice widget testovi | 21 |
| UI poruke | 2 |
| Ukupno | 159 |

Serverska integracija koristi stvarni PostgreSQL u posebnoj bazi `carwash_test`. Grupa nije preskočena. Čisti Dart testovi dodatno su prošli u UTC okruženju, kao i svih 47 widget/UI testova. `flutter analyze` nema prijavljenih problema; `dart format --output=none --set-exit-if-changed apps packages` ne traži izmene.

Pokriveni su:

- Domenska pravila za vozilo, registraciju, adresu, napomenu, cenu, trajanje, termine, otkazivanje, stanja i prava.
- Zimsko i letnje računanje vremena u Europe/Belgrade, tačna granica od jednog sata, sedam dana i završetak u 20 h.
- Napomena od 300 složenih emoji znakova, odbijanje 301. znaka i uklanjanje okolnih razmaka.
- JSON prevod svih pet stanja, parametri grešaka, nepoznat kod greške, dodatna polja odgovora i stroga polja komandi.
- Nevažeći JSON, tipovi, datumi, filteri, paginacija, pokušaj podmetanja identiteta/cene i SQL sadržaj u unosu.
- Prijava, pogrešna lozinka, pogrešna aplikacija, sve zaštićene rute bez prijave, vlasništvo i prava tri uloge.
- Bearer i cookie transport, mešanje transporta, istek, opoziv jedne sesije i promena uloge u bazi.
- Dodela, vraćanje u red, ponovna dodela, otkazivanje i odbijanje nedozvoljene promene bez menjanja zapisa.
- 32 istovremena kreiranja za istog klijenta: jedno preostalo mesto dobija tačno jedan zahtev, ostalih 31 se odbija.
- 20 različitih klijenata konkuriše za jednog perača: jedna dodela uspeva, ostalih 19 dobija `washer_busy`.
- CORS, preflight, kontrolisane JSON greške 404/405 i zaglavlja grešaka.
- Mobilno učitavanje, navigacija, validacija forme, čuvanje unosa posle neuspeha, ponovni pokušaj i potvrda/odustajanje od otkazivanja.
- Mobilni raspored na širinama 320, 360, 390, 430 i 768; backoffice na 360, 899, 900, 1280 i 1920.
- Backoffice dodela, vraćanje u red, otkazivanje, ograničenja stanja, tastatura, osvežavanje i zamena prethodne poruke.

Komande iz korena repozitorijuma:

```bash
flutter pub get
docker compose --profile test up -d --wait test-db
TEST_DATABASE_PORT=55432 dart test packages/domain/test packages/use_cases/test packages/blocs/test packages/contracts/test packages/api_mapping/test apps/server/test
flutter test apps/mobile/test apps/backoffice/test packages/ui/test
TZ=UTC dart test packages/domain/test packages/use_cases/test packages/blocs/test packages/contracts/test packages/api_mapping/test
TZ=UTC flutter test apps/mobile/test apps/backoffice/test packages/ui/test
flutter analyze
dart format --output=none --set-exit-if-changed apps packages
```

## Buildovi bez emulatora

| Aplikacija | Komanda iz foldera aplikacije | Rezultat |
|---|---|---|
| Mobile | `flutter build apk --debug` | Prošlo |
| Mobile | `flutter build apk --release` | Prošlo |
| Mobile | `flutter build ios --simulator --no-codesign` | Prošlo |
| Backoffice | `flutter build macos --release` | Prošlo |
| Backoffice | `flutter build web --release` | Prošlo |
| Server | Docker build i AOT kompilacija | Prošlo |

Android i iOS emulator/simulator nisu pokretani. iOS provera ovde znači kompilaciju aplikacije za simulator, bez izvršavanja i bez provere fizičkog telefona. Windows build nije izvršen na macOS računaru.

iOS build u folderu Desktop prvobitno je padao pri potpisivanju generisanog `Flutter.framework` zbog Finder/FileProvider metapodataka. Isti kod je uspešno izgrađen iz privremenog klona van Desktop-a. Zatim je uspeo i build radne kopije kada je samo ignorisani izlaz `apps/mobile/build/ios` preusmeren simboličkim linkom u `Library/Caches/CarWash-Go-KT2`. SDK i izvorni iOS projekat nisu menjani. `flutter clean` uklanja taj lokalni link; za ponavljanje koristiti nesinhronizovan folder ili ponovo preusmeriti izlaz.

Buildovi prijavljuju upozorenje za Cupertino font i pojedina upozorenja alata Android/Xcode; nijedno nije prekinulo navedene završne buildove. Zavisnosti nisu nadograđivane tokom provere.

## Pravi pregledač

Release veb aplikacija i API provereni su u zasebnom headless Brave procesu preko Playwright-a, bez korišćenja ličnog profila pregledača. Prošlo je 15 browser scenarija:

1. CORS odgovor bez prijave dostupan je JavaScript-u.
2. Klijentska uloga ne može da se prijavi kao backoffice.
3. Preflight i cookie login rade; odgovor ne izlaže token u JSON-u.
4. Cookie je trajan, HttpOnly i nedostupan `document.cookie`.
5. Prijava opstaje posle osvežavanja stranice.
6. Prijava opstaje posle zatvaranja i ponovnog otvaranja pregledača sa istim testnim profilom.
7. JSON 404 i 405 odgovori dostupni su kroz CORS.
8. Mutacija sa nedozvoljenog origin-a se odbija i ne menja zapis.
9. Logout uklanja cookie; osvežavanje ne vraća prijavu.
10. Backoffice release interfejs se učitava.
11. Tastatura bira zahtev i otvara dozvoljenu akciju.
12. Dodela slobodnog perača radi u interfejsu.
13. Vraćanje u red radi u interfejsu.
14. Potvrda i otkazivanje rade u interfejsu.
15. Širine 360/899/900, F5 i runtime prolaze bez JavaScript grešaka.

Stavke 1–9 proveravaju stvarni API. Stavke 10–15 proveravaju trenutni backoffice sa fake adapterom. One ne dokazuju povezivanje backoffice aplikacije sa bazom. Sačuvani su i pregledani snimci širokog i uskog rasporeda i dijaloga dodele.

## Rok sesije i prekidi servisa

Na zasebnom serveru sa `SESSION_TTL_SECONDS=4` provereni su native token i browser cookie pre i posle stvarnog isteka vremena. Oba su važila pre isteka; native je potom dobio 401 `session_expired`, a pregledač je uklonio istekli cookie.

Na izolovanom Docker projektu provereni su:

- Nedostupan server vraća transportnu grešku u ograničenom vremenu.
- Restart servera zadržava sesiju i sve zapise.
- Prekid baze vraća kontrolisani JSON `server_error`, bez izlaganja internih detalja klijentu.
- Po povratku baze server nastavlja rad bez ponovnog pokretanja i gubitka sesije/podataka.
- Hladan restart servera i baze čuva podatke i ne duplira seed.

Ove provere ne potvrđuju budući prikaz mrežnih grešaka u aplikacijama sa stvarnim adapterom.

## Promena pravila bez nove kompilacije klijenta

Zaseban Dart HTTP klijent prvo je AOT kompajliran sa domenskom granicom napomene 300 i postojećim paketima `contracts`, `api_mapping` i UI prevodom poruke. U izdvojenoj serverskoj kopiji granica je zatim promenjena na 200, a server ponovo izgrađen. Ranije kompajliran klijent je poslao 250 znakova, dobio HTTP 422 sa `actualLength=250` i `maxLength=200`, i preko postojećeg mapper-a prikazao tekst „Napomena može imati najviše 200 znakova.“

Ovo potvrđuje HTTP ugovor, mapper i prevod poruke sa starim kompajliranim klijentom. Ne predstavlja test login ekrana ili mrežnog adaptera Flutter aplikacije. Granica u glavnom projektu ostala je 300.

## Čist klon i demo

Proveren je izdvojen klon sa kopiranjem neizmenjenog `.env.example` u `.env`, jednim `docker compose up --build -d --wait`, migracijom, seed-om, health proverom i kompletnim `demo_api.dart` tokom. Za izolaciju od postojećeg servera korišćeni su zaseban Compose projekat i objavljeni port; unutrašnja konfiguracija ostala je razvojna konfiguracija iz primera.

Demo proverava prijavu dve uloge, pregled, tri zabrane pristupa, kreiranje, vidljivost promene drugoj ulozi, dve istovremene dodele, vraćanje u red, otkazivanje, logout i nevažeći odjavljeni token. Napravljeni demo zapis ostaje otkazan, a dodela se vraća u red.

## Ispravke pronađene tokom provere

- Middleware sada obuhvata i promašenu rutu/pogrešan metod: JSON i CORS važe i za 404/405.
- ISO dekoder odbija nemogući datum, sat ili pomeraj zone umesto Dart normalizacije.
- DTO vozila dopušta dodatna polja odgovora, dok komanda kreiranja i dalje strogo proverava ulazna polja.
- Mobilna kartica dozvoljava ceni da pređe u novi red. Sažetak forme na uskom ekranu prikazuje dugme ispod procene.
- Backoffice odmah zamenjuje prethodni SnackBar novom porukom.
- Domenski test podaci koriste poslovnu zonu umesto vremenske zone računara.

## Preostalo za kompletnu KT2 demonstraciju

Potrebno je implementirati i povezati zajednički mrežni adapter, auth tok i skladištenje prijave u mobilnoj i backoffice aplikaciji. Zatim ponoviti iste korisničke tokove kroz obe stvarno povezane aplikacije, proveriti deljenje promena između njih, istek i obnovu prijave na ciljnoj platformi i pokretanje na emulatoru/uređaju. Uputstvo za taj deo je u [KT2 API dokumentaciji](kt2-api.md).

Detaljni završni logovi i snimci ove lokalne provere nalaze se u folderu `Documents/CarWash-Go-KT2/Provere-2026-11-18` na računaru na kome je provera izvršena.
