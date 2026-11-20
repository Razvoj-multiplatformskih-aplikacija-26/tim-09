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

## Povezani klijenti (feature/kt2-clients)

Datum: 19. novembar 2026. Grana: `feature/kt2-clients`, napravljena iz `main` posle merge-a serverskog PR-a. Proveravano na Windows 11 računaru, Flutter 3.47.6.

### Šta je urađeno

- Port `WashRequestRepository` ima eksplicitne komande `create`, `cancel`, `assign`, `release`, stranicu `list(RequestQuery)` i `find(id)`. Generički `save` i `clientId` u nacrtu su uklonjeni; vlasnika, aktera, cenu i vreme određuje server.
- Novi čisti Dart paket `api_client`: `CarWashApi` (osnovna adresa, JSON, statusi, deset sekundi po zahtevu), HTTP repozitorijumi zahteva, perača i prijave, `SessionController` i odvojen izbor HTTP klijenta za VM (Bearer) i veb (`BrowserClient` sa `withCredentials`, HttpOnly cookie).
- Novi paket `platform_adapters` sa `SecureSessionStorage` iza porta `SessionStorage` (flutter_secure_storage 11.2.0). Na macOS-u bez data protection keychain-a, da ne bi bio potreban provisioning profil.
- `AuthBloc`, `RequestDetailBloc`, paginacija i filteri u `MyRequestsBloc` i `DispatchBloc`, perači sa `/washers`.
- `WashRequest.quotedPrice`: klijent prikazuje cenu koju je vratio server, a lokalni cenovnik ostaje procena u formi. Server ne čuva ni ne menja ovo polje.
- Poruke za mrežu, sesiju, protokol i razloge prijave su na jednom mestu u `ui` (`app_messages.dart`). Datumi i vremena se prikazuju u Europe/Belgrade, a izbor termina se tumači preko `businessDate`.
- Zajednički in-memory adapteri (`package:use_cases/testing.dart`) izvršavaju isti domen kao server i služe testovima i eksplicitnoj fake konfiguraciji.

Odbačene mogućnosti: automatsko ponavljanje POST-a posle prekida (ishod upisa nije poznat, pa korisnik dobija poruku da osveži podatke); jedan `MaterialApp` sa redirect-om pri isteku sesije (stari ekrani bi mogli da čitaju Bloc koji više ne postoji, pa svaka faza prijave ima svoj podsklop koji se zatvara sa sesijom); računanje zauzetosti perača iz trenutne stranice (server vraća `hasActiveJob` nad svim aktivnim poslovima).

### Automatski testovi

| Grupa | Prošlo |
|---|---:|
| domain, use_cases, blocs, contracts, api_mapping, api_client | 140 |
| Relic i PostgreSQL integracija | 30 |
| Mobilni widget testovi | 35 |
| Backoffice widget testovi | 27 |
| UI poruke i formatiranje | 5 |
| platform_adapters | 2 |
| Ukupno | 239 |

Serverska grupa je izvršena nad bazom `carwash_test` (`TEST_DATABASE_PORT=55432`), nije preskočena. `flutter analyze` nema problema, `dart format --output=none --set-exit-if-changed apps packages` ne traži izmene.

Novi testovi pokrivaju: 200/201/204, stranice, filtere i detalj van prve stranice; 409/422 sa parametrima, 401, 403 (prava i pogrešna aplikacija), nepoznat kod, 400/405/500 i loš JSON; timeout i nedostupan server bez ponavljanja upisa; obnovu native tokena, brisanje nevažećeg tokena, čuvanje tokena pri prekidu mreže, cookie transport bez Authorization zaglavlja, odjavu koja briše token tek posle servera, jedan događaj isteka pri više paralelnih 401 i zakasneli 401 stare sesije posle nove prijave; odbijanje komande sa očuvanim razlogom i reload-om, uključujući prazan i neuspešan reload; widget tokove prijave, odjave, isteka, uloge perača, zabrane rute `/new`, nedostupnog detalja, filtera, stranica i osvežavanja perača posle `washer_busy`. Postojeći KT1 testovi rasporeda i prečica prolaze bez izmene očekivanja.

### Provera nad stvarnim serverom

Server je izgrađen iz ažuriranog `pubspec.lock` i pokrenut kroz Compose; `/health` vraća 200, a postojeći `apps/server/tool/demo_api.dart` prolazi ceo tok.

`dart packages/api_client/tool/live_check.dart` koristi iste HTTP repozitorijume kao aplikacije i prošao je 25 provera: nedostupan server, prijava klijenta i dispečera, klijent odbijen u backoffice-u, pogrešna lozinka, Marko kreira zahtev, server određuje vlasnika i stanje, napomena od 301 znaka vraća granicu sa servera, dispečer nalazi zahtev kroz stranice i filter, detalj po ID-u, Ana ne vidi Markov zahtev, tri zabrane klijentu, perači sa servera, dva dispečera za istog perača (jedan uspeh, jedan `washer_busy`), osvežena zauzetost, Marko vidi dodelu, vraćanje u red, obnova iz sačuvanog tokena, otkazivanje svog zahteva, odjava, opozvan token daje jedan istek sesije i nema obnove posle odjave.

Windows desktop backoffice (`flutter test integration_test -d windows`) je stvarno pokrenut nad serverom: prijava dispečera, ponovno pokretanje aplikacije obnavlja prijavu iz Windows bezbednog skladišta, odjava, i posle ponovnog pokretanja nema obnove.

Release veb backoffice je posluživan na `http://localhost:3000` i proveren u headless Chrome-u (puppeteer-core, privremeni profil): ekran prijave, klijent odbijen porukom „Backoffice je namenjen dispečerima.“, dispečer vidi tablu sa servera, sesija je HttpOnly kolačić nedostupan `document.cookie` i nije u localStorage, F5 zadržava prijavu preko `/auth/me`, odjava briše kolačić i F5 je ne vraća, bez JavaScript grešaka.

### Buildovi

| Aplikacija | Komanda | Rezultat |
|---|---|---|
| Backoffice | `flutter build web --release` | Prošlo |
| Backoffice | `flutter build windows --release` | Prošlo |
| Mobile | `flutter build apk --debug` | Prošlo |
| Server | `docker build -f apps/server/Dockerfile .` | Prošlo |

Na ovom Windows računaru `docker compose up --build` traži dodatnu bake dozvolu za putanju Dockerfile-a (`--allow=fs.read=apps\server\Dockerfile`). Ista slika je izgrađena komandom `docker build -f apps/server/Dockerfile -t carwash-kt2-server .`, a zatim pokrenuta sa `docker compose up -d --wait`. Na macOS-u ranije provereni `docker compose up --build` nije menjan.

### Ispravke posle pregleda (20. novembar 2026.)

Pregled verzije `0f2d702` našao je tri greške u backoffice-u; sve tri su ispravljene i pokrivene testovima koji padaju na toj verziji.

1. **„Sva stanja“ nije uklanjalo filter.** `PopupMenuButton` vrednost `null` tumači kao odustajanje. Meni sada koristi privatni enum `_FilterChoice` sa nenultom opcijom za sva stanja, koja se u `onSelected` prevodi u `DispatchFilterChanged(null)`. Mrežni ugovor je isti: bez filtera se `status` izostavlja.
2. **Sporiji stari odgovor je prepisivao noviji prikaz.** `DispatchBloc._reload` dobija redni broj učitavanja i lokalni snimak filtera i offseta. Posle svakog čekanja (stranica, povratak sa stranice van opsega, perači) odgovor se odbacuje ako je u međuvremenu počelo novije učitavanje ili radnja; to važi i za uspeh i za grešku. Offset se upisuje tek kad se odgovor prihvati. Početak radnje poništava učitavanja koja još traju, pa ne mogu da uklone `busy`.
3. **Uski detalj je gubio radnje kad filtrirana lista postane prazna.** Uvedeno je zajedničko stanje `DispatchReady` za `DispatchLoaded` i `DispatchEmpty`; prazna tabla sada nosi perače, filter, `busyId` i poruku. `_act`, potvrda poruke, `RequestDetailScreen` i `assignWasher` rade nad bilo kojom spremnom tablom.

Regresioni testovi: `packages/blocs/test/dispatch_stale_load_test.dart` (6, sa `Completer` odgovorima), pet testova prazne table u `dispatch_bloc_test.dart`, `apps/backoffice/test/review_fixes_test.dart` (9 widget testova, uključujući pravi `api_client` sa `MockClient` koji potvrđuje upit bez `status`). Na verziji `0f2d702` pada 5 od 6 Bloc testova trke i 7 od 9 widget testova; preostali čuvaju ponašanje koje je i ranije bilo ispravno (Esc ne menja filter, „Prikaži sve“, greška poslednjeg važećeg upita).

Posle ispravki prolazi 259 testova (181 Dart uključujući 30 serverskih nad `carwash_test`, 78 Flutter), bez preskakanja; `flutter analyze` i provera formata su čisti. Release veb na `localhost:3000` je u Chrome-u nad serverom proveren: „U toku“ → „Sva stanja“, Esc čuva filter, brz niz filtera, i na širini 600 px jedini prihvaćeni zahtev vraćen u red pa ponovo dodeljen sa prazne table (zahtev `seed-3` je posle provere ponovo prihvaćen, perač w-2). Windows release build i desktop integracioni test prolaze.

## Preostalo za kompletnu KT2 demonstraciju

Ovo nije bilo moguće izvršiti na Windows računaru i ostaje za ručnu proveru pre odbrane:

- Android emulator nije konfigurisan na ovom računaru, pa mobilna aplikacija nije pokrenuta na emulatoru; proveren je build i ceo tok kroz widget testove i isti HTTP adapter nad serverom.
- iOS simulator i macOS backoffice zahtevaju Mac: `flutter build ios --simulator --no-codesign` i `flutter build macos --release`, zatim prijava, restart i odjava na obe platforme.
- Tačka 9 iz plana (stara mobilna aplikacija, serverska granica napomene 200) traži emulator; serverski deo i prikaz granice iz `details` potvrđeni su gornjim alatom i testom `422 nosi novu serversku granicu`.
- Istovremeni rad emulatora, desktop i veb klijenta na istoj bazi treba pokazati uživo; svaki od njih je pojedinačno proveren nad istim serverom.
