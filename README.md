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

Mobilna i backoffice aplikacija u ovoj fazi još koriste KT1 fake adaptere. Server je spreman za njihov zajednički mrežni adapter i prijavu.

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
TEST_DATABASE_PORT=55432 dart test packages/domain/test packages/use_cases/test packages/blocs/test packages/contracts/test packages/api_mapping/test apps/server/test
```

Integracioni testovi koriste posebnu bazu `carwash_test` i obnavljaju samo njene testne podatke. Bez `TEST_DATABASE_PORT` serverska integraciona grupa se preskače. Port se može promeniti kroz istoimenu konfiguraciju.

Iz foldera `apps/mobile`, `apps/backoffice` i `packages/ui` pokrenuti:

```bash
flutter test
```

Iz `apps/backoffice` proveriti i veb prevođenje:

```bash
flutter build web
```

### Pravila, konkurentnost i sesije

Server pre upisa koristi isti domen kao klijenti. Zaključavanje reda perača i zahteva u PostgreSQL transakciji sprečava dve dodele istog perača. Zaključavanje vlasnika pre brojanja čuva granicu od tri zahteva na čekanju. Poslovni rezultat nije zasnovan na ranije poslatom klijentskom stanju.

Identitet dolazi iz serverske sesije. Klijent ne može poslati drugog vlasnika, proizvoljnu ulogu, cenu ili stanje. Dodela i vraćanje u red su samo za dispečera; klijent otkazuje samo svoj zapis uz pravila stanja i roka.

Native klijent dobija nasumični token, a veb HttpOnly cookie. Server čuva heš tokena, rok i opoziv. Svaki poziv proverava sesiju. Prijava opstaje pri restartu servera i prestaje istekom ili odjavom.

Vreme se prenosi u UTC, a radno vreme proverava u `Europe/Belgrade`. Greške nose kod i parametre pravila, a zajednički UI pravi poruku. `RemoteRuleViolation` omogućava kontrolisan prikaz nepoznatog pravila.

Spoljni servis teme je iza serverskog `GeocodingGateway` porta. KT2 fake adapter daje demo koordinate; nedostupnost geokodiranja ostavlja zahtev sa tekstualnom adresom. Servisni ključevi pripadaju budućem serverskom adapteru i lokalnom okruženju.
