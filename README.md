# tim-09
CarWash &amp; Go - Sistem za brzo naručivanje i zakazivanje terenskog pranja automobila na parkingu klijenta uz odabir ekonomične ili profesionalne usluge.

# CarWash &amp; Go 

Sistem za naručivanje terenskog pranja vozila. Platforma povezuje vlasnike vozila kojima je potrebno pranje na trenutnoj lokaciji sa peračima u blizini, omogućavajući izbor tipa pranja i praćenje statusa usluge u realnom vremenu.

Projekat iz predmeta Razvoj multiplatformskih aplikacija.

## Tim

| Ime i prezime | Broj indeksa | GitHub nalog |
| --- | --- | --- |
| Milan Šegan | 107/24 SI | [@sShegy](https://github.com/sShegy) |
| Andrija Stojanović | 93/24 SI | [@andrijas6](https://github.com/andrijas6) |

## Zahtevi za temu

1. **Uloge.** Sistem koriste klijenti, perači i administratori sa različitim ovlašćenjima: klijent naručuje pranje, perač prihvata poslove, a administrator nadgleda sistem i rešava žalbe.
2. **Stanja.** Zahtev za pranje prolazi kroz više stanja: prijavljen na lokaciji, prihvaćen od strane perača, u toku (pranje se obavlja), i na kraju završen ili otkazan.
3. **Pravila.** Perač ne može prihvatiti novi zahtev za pranje ukoliko već ima aktivan posao u toku, o čemu konačnu odluku donosi server proverom preklapanja. Klijent zakazuje termin najmanje 1 h, a najviše 7 dana unapred, na pun sat ili pola sata, tako da pranje počne i završi se između 8 i 20 h; registarska oznaka mora biti u formatu „BG 123-AB“, a napomena za perača ima najviše 300 znakova. Klijent može imati najviše 3 zahteva na čekanju, a prihvaćen zahtev može da otkaže najkasnije 1 h pre termina, osim ako perač kasni više od 30 minuta.
4. **Rad bez mreže.** Perač može uslikati opran auto i označiti posao kao završen čak i u podzemnoj garaži bez signala; podaci se automatski šalju na server kada se veza uspostavi.
5. **Posao za osoblje.** Administrator u backoffice aplikaciji na velikom ekranu ima uvid u zbirnu mapu svih aktivnih zahteva, prati lokacije perača i odobrava njihove profile.
6. **Javni sadržaj.** Cenovnik usluga, kalkulator procene cene pranja na osnovu tipa vozila i recenzije dostupni su svima bez prijave, što ima smisla da pronađu pretraživači.

## Delovi sistema

| Deo | Korisnici | Tehnologija | Platforme |
| --- | --- | --- | --- |
| Mobilna aplikacija | klijenti, perači | Flutter | Android |
| Backoffice | administratori | Flutter | Windows, macOS, veb |
| Javni veb | svi posetioci | Jaspr | pregledač |
| Server | ostali delovi sistema | Relic, PostgreSQL | Linux |
| Domenski paket | svi delovi sistema | Dart | sve |

Svi delovi koriste isti domenski paket, u kome su model i pravila. Server čuva podatke i ponovo proverava svako pravilo.

## KT2: server i baza

Serverski deo koristi Dart, Relic 1.2.0 i PostgreSQL. Zajednički paketi `contracts` i `api_mapping` opisuju HTTP podatke i prevod prema domenu. [Ugovor i povezivanje klijenata](docs/kt2-api.md) navode rute, greške i sledeće korake za aplikacije.

Mobilna i backoffice aplikacija podrazumevano rade sa ovim serverom preko zajedničkog paketa `api_client`. Obe počinju prijavom; podaci, prava i pravila dolaze sa servera.

[Izveštaj o proverama](docs/kt2-provere.md) sadrži rezultate automatskih testova, buildova, provera pregledača i prekida servisa, kao i preostala ograničenja.

[Plan povezivanja klijenata](docs/kt2-klijenti.md) opisuje Andrijin nastavak posle serverskog PR-a, sa redosledom rada i izmenama po fajlovima.

### Pokretanje iz čistog klona

Potrebni su Git i pokrenut Docker Desktop sa Docker Compose-om. Iz korena repozitorijuma:

```bash
cp .env.example .env
docker compose up --build -d --wait
```

Razvojne vrednosti iz primera rade bez izmena. Server je na `http://localhost:8080`. Baza, migracije i početni podaci podižu se automatski. Podaci ostaju u Docker volumenu pri restartu.

```bash
curl -i http://localhost:8080/health
docker compose logs server
```

Ako na macOS-u komanda `docker` nije u PATH-u, za tekući terminal dodati:

```bash
export PATH="/Applications/Docker.app/Contents/Resources/bin:$PATH"
```

`.env` je ignorisan u Git-u. `SERVER_PORT` bira objavljeni port, `SESSION_TTL_SECONDS` rok prijave, a `CORS_ALLOWED_ORIGINS` dozvoljene veb adrese razdvojene zarezom. Podrazumevani veb origin je `http://localhost:3000`. Lozinke naloga su bcrypt heševi; lozinka u primeru služi razvojnim nalozima.

### Demo nalozi

Svi početni nalozi koriste lozinku `DemoPass123!`, odnosno vrednost `DEMO_PASSWORD` pri prvom seed-u.

| Korisničko ime | Uloga | Aplikacija |
|---|---|---|
| marko | Klijent | Mobilna |
| ana | Klijent | Mobilna |
| dispecer | Dispečer | Backoffice |
| nikola | Perač w-1, početno slobodan | Mobilna |
| jovan | Perač w-2, početno prihvaćen posao | Mobilna |
| stefan | Perač w-3, početno posao u toku | Mobilna |

Seed sadrži 12 zahteva svih pet stanja. Marko i Ana imaju različite zahteve. Promena `DEMO_PASSWORD` ne prepisuje već postojeće naloge pri restartu.

### API provera

Kada server radi, iz korena repozitorijuma i sa instaliranim Dart SDK-om:

```bash
dart apps/server/tool/demo_api.dart
```

Alat proverava prijavu, pregled, kreiranje, dostupnost promene drugoj ulozi, zabranu dve staff akcije/tuđeg zapisa, dve istovremene dodele istog perača, vraćanje u red i odjavu. Očekuje početne demo zapise `seed-1`, `seed-2` i slobodnog `w-1`. Tokeni se ne ispisuju. Napravljeni demo zahtev se na kraju otkazuje, a dodela vraća u red.

### Testovi

Flutter SDK mora da zadovolji Dart ograničenje `^3.13.0`. Iz korena:

```bash
flutter pub get
flutter analyze
docker compose --profile test up -d --wait test-db
TEST_DATABASE_PORT=55432 dart test packages/domain/test packages/use_cases/test packages/blocs/test packages/contracts/test packages/api_mapping/test packages/api_client/test apps/server/test
flutter test apps/mobile/test apps/backoffice/test packages/ui/test packages/platform_adapters/test
```

Integracioni testovi koriste posebnu bazu `carwash_test` i obnavljaju samo njene testne podatke. Bez `TEST_DATABASE_PORT` serverska integraciona grupa se preskače. Port se može promeniti kroz istoimenu konfiguraciju.

Iz `apps/backoffice` proveriti i veb prevođenje:

```bash
flutter build web
```

### Pokretanje klijenata

Server mora da radi (vidi gore). Adresa servera se zadaje javnom konfiguracijom `API_BASE_URL`; bez nje Android emulator koristi `http://10.0.2.2:8080`, a ostale platforme `http://localhost:8080`. ID uređaja birati iz `flutter devices`.

Mobilna aplikacija, iz `apps/mobile`:

```bash
flutter run -d <android-device-id> --dart-define=API_BASE_URL=http://10.0.2.2:8080
flutter run -d <ios-simulator-id> --dart-define=API_BASE_URL=http://localhost:8080
```

Backoffice, iz `apps/backoffice`:

```bash
flutter run -d windows --dart-define=API_BASE_URL=http://localhost:8080
flutter run -d macos --dart-define=API_BASE_URL=http://localhost:8080
flutter run -d chrome --web-port=3000 --dart-define=API_BASE_URL=http://localhost:8080
```

Veb mora da radi na `http://localhost:3000`, jer je taj origin dozvoljen u `CORS_ALLOWED_ORIGINS`; ne mešati `localhost` i `127.0.0.1`. Fizički telefon ne vidi `localhost` računara: potrebna je LAN adresa računara i objavljen port servera, što nije podrazumevana razvojna konfiguracija.

Mobilna aplikacija prima klijente i perače, backoffice samo dispečera. Native klijenti čuvaju token u bezbednom skladištu platforme (Keystore, Keychain, Windows Credential Manager) i pri pokretanju ga proveravaju pozivom `/auth/me`. Veb backoffice koristi HttpOnly cookie i ne vidi token. Lozinka se nigde ne čuva.

Lokalni HTTP je dozvoljen samo za razvoj: Android debug/profile manifest (`usesCleartextTraffic`), iOS `NSAllowsLocalNetworking`. Release Android build nad lokalnim HTTP-om nije podržan bez posebne konfiguracije. Na macOS-u backoffice ima `network.client` i koristi Keychain bez Keychain Sharing-a, pa nije potreban provisioning profil.

Za rad bez servera (demo i razvoj ekrana) postoji fake konfiguracija u memoriji, uključena samo eksplicitno: `--dart-define=FAKE_DATA=true`. Nema tihog prebacivanja na fake kada server ne radi.

Provera klijentskog mrežnog sloja nad pokrenutim serverom, iz korena:

```bash
dart packages/api_client/tool/live_check.dart
```

Alat prolazi kroz prijave, pogrešnu aplikaciju, kreiranje, granicu napomene sa servera, stranice i filter, detalj po ID-u, zabrane, dva dispečera za istog perača, obnovu i odjavu. Napravljeni zahtev na kraju otkazuje, a dodelu vraća u red. Tokeni se ne ispisuju.

Provera desktop prijave i obnove iz bezbednog skladišta, iz `apps/backoffice` sa pokrenutim serverom:

```bash
flutter test integration_test -d windows
```

### Pravila, konkurentnost i sesije

Server pre upisa koristi isti domen kao klijenti. Zaključavanje reda perača i zahteva u PostgreSQL transakciji sprečava dve dodele istog perača. Zaključavanje vlasnika pre brojanja čuva granicu od tri zahteva na čekanju. Poslovni rezultat nije zasnovan na ranije poslatom klijentskom stanju.

Identitet dolazi iz serverske sesije. Klijent ne može poslati drugog vlasnika, proizvoljnu ulogu, cenu ili stanje. Dodela i vraćanje u red su samo za dispečera; klijent otkazuje samo svoj zapis uz pravila stanja i roka.

Native klijent dobija nasumični token, a veb HttpOnly cookie. Server čuva heš tokena, rok i opoziv. Svaki poziv proverava sesiju. Prijava opstaje pri restartu servera i prestaje istekom ili odjavom.

Vreme se prenosi u UTC, a radno vreme proverava u `Europe/Belgrade`. Greške nose kod i parametre pravila, a zajednički UI pravi poruku. `RemoteRuleViolation` omogućava kontrolisan prikaz nepoznatog pravila.

Spoljni servis teme je iza serverskog `GeocodingGateway` porta. KT2 fake adapter daje demo koordinate; nedostupnost geokodiranja ostavlja zahtev sa tekstualnom adresom. Servisni ključevi pripadaju budućem serverskom adapteru i lokalnom okruženju.
