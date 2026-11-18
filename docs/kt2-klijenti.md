# KT2: Andrijin nastavak posle serverskog PR-a

Ovo je plan preostale implementacije za CarWash & Go, tim 09. Stanje servera provereno je 18. 11. 2026. na commitu `9652ca1`, koji uključuje `923660e`. Opisani novi klijentski fajlovi i potpisi predstavljaju predlog implementacije, nisu već gotov kod.

Milanov serverski PR se prvo spaja u `main`. Andrija zatim iz tog ažuriranog `main` pravi `feature/kt2-clients`. Milanov deo daje server, bazu, sesije, zajednički ugovor i mapper. Andrijin deo povezuje obe aplikacije sa njima i završava korisničke tokove KT2.

Sve putanje u ovom dokumentu su u odnosu na koren repozitorijuma.

## 1. Preuzimanje i prva provera

Ako postoje lokalne nesnimljene izmene, prvo ih sačuvati u odgovarajući sopstveni commit. Zatim, posle merge-a serverskog PR-a:

```bash
git fetch origin
git switch main
git pull --ff-only origin main
git switch -c feature/kt2-clients
flutter pub get
```

Pročitati `docs/kt2-api.md` za stvarni HTTP ugovor, `docs/kt2-provere.md` za izvršene provere i ovaj dokument za preostali posao. Stari plan pisan pre servera više nije izvor za nazive DTO tipova ili redosled izrade.

Uz pokrenut Docker Desktop, ako lokalni `.env` još ne postoji:

```bash
cp .env.example .env
docker compose up --build -d --wait
curl -i http://localhost:8080/health
dart apps/server/tool/demo_api.dart
```

Ne prepisivati postojeći lokalni `.env`. Docker `down -v` nije potreban: briše sačuvane razvojne podatke. Demo koristi početne zapise i sam vraća svoju dodelu u red, a novi zapis otkazuje.

Svi početni nalozi imaju lozinku `DemoPass123!`: `marko` i `ana` su klijenti, `dispecer` je osoblje, a `nikola`, `jovan` i `stefan` su perači. Mobilna aplikacija dopušta klijenta/perača; backoffice samo dispečera.

## 2. Šta već postoji i koristi se dalje

| Postojeći deo | Stvarni fajlovi i namena |
|---|---|
| Server | `apps/server`, Relic tačno 1.2.0, PostgreSQL i transakcije |
| Podizanje | `compose.yaml`, `.env.example`, `database/migrations/001_initial.sql` |
| Ugovor | `packages/contracts/lib/src/auth.dart`, `requests.dart`, `commands.dart`, `api_error.dart`, `json_values.dart` |
| Mapper | `packages/api_mapping/lib/src/request_mapper.dart`, `user_mapper.dart`, `error_mapper.dart` |
| Prava | `packages/domain/lib/src/permissions.dart` |
| Poslovno vreme | `packages/domain/lib/src/business_time.dart`: `inBusinessTime`, `businessDate` |
| Pravila i prelazi | Postojeći `packages/domain/lib/src/wash_request/` |
| Poruke | `packages/ui/lib/src/text/domain_errors.dart`, već koriste parametre serverske greške |
| Tokovi | Postojeći `MyRequestsBloc`, `DispatchBloc`, `WashRequestFormBloc` |

Stvarni DTO nazivi: `LoginRequest`, `SessionDto`, `UserDto`, `CreateRequest`, `VehicleDto`, `WashRequestDto`, `StatusDto`, `RequestPageDto`, `WasherDto`, `AssignRequest`, `CancelRequestDto`, `RequestResponse`, `ApiError`.

Postojeći javni mapper-i: `requestToDto`, `requestFromDto`, `statusToDto`, `statusFromDto`, `userToDto`, `userFromDto`, `washerToDto`, `washerFromDto`, `errorToDto`, `errorFromDto`. `createFromDto` serveru služi za domensko kreiranje. Ne praviti paralelan mapper u aplikacijama. Ako se dodaje prevod nacrta ili stranice, dopuniti isti paket uz direktnu zavisnost koju novi import zahteva i bez kružnih zavisnosti.

Server određuje vlasnika, cenu, trajanje i vremena promene. Klijentska komanda ih ne šalje. Postojeća serverska šema i API dovoljni su za ovaj nastavak; promene ugovora dogovoriti sa Milanom i proveriti oba kraja.

Pri povezivanju dopuniti jednu važnu stvar u read modelu: postojeći `WashRequest.price` računa lokalni `estimate`, a `requestFromDto` trenutno ne zadržava primljeni `priceRsd`. Za različite verzije cenovnika klijent zato mora da sačuva i prikaže serversku cenu. Jednostavno rešenje, uz dogovor sa Milanom: dodati opcioni final `PriceEstimate? quotedPrice` u `WashRequest`; getter koristi tu vrednost kad postoji, inače postojeći estimate za lokalni/fake model. `requestFromDto` postavlja quotedPrice iz `dto.priceRsd` i `dto.durationMinutes`; `copyWith`, jednakost i hash čuvaju vrednost. Testirati serverovu cenu različitu od lokalne i DTO round-trip. Ovo je dopuna za stvarni klijentski read model; trenutno testirani fake ekran koristi isti lokalni cenovnik.

## 3. Granice arhitekture

Tok ostaje: ekran → Bloc → use case/port → mrežni adapter → HTTP server → domen i baza.

- `domain`: pravila, prava i modeli; bez HTTP-a, Flutter-a i baze.
- `contracts`: HTTP podaci; bez domena, Flutter-a i `dart:io`.
- `api_mapping`: jedan prevod ugovora i domena, uključujući greške.
- `use_cases`: portovi i aplikacioni tipovi; bez HTTP/Flutter implementacija.
- `blocs`: čist Dart; zavisi od use case-ova i modela, ne od secure storage-a ili HTTP klijenta.
- Novi `api_client`: čist Dart mrežni adapter za oba klijenta i VM/veb.
- Novi `platform_adapters`: Flutter implementacija bezbednog skladišta iza porta.
- Aplikacije: sastavljanje zavisnosti, konfiguracija platforme, rute i prikaz.

Zadržati postojeći stil: male klase, `final` polja, jasno imenovanje, Bloc događaji/stanja i vrednosna jednakost. Ne uvoditi drugi state management niti opšti framework za ovaj zadatak. Nove komentare u izvornom kodu ne dodavati; objašnjenja i odluke ostaju u dokumentaciji. Commit-i nemaju AI `Co-Authored-By` trailer.

## 4. Prvo promeniti klijentske portove i sve njihove pozivaoce

`packages/use_cases/lib/src/ports/wash_request_repository.dart` trenutno ima `requestsOf`, `allRequests`, `create` i generički `save`. Takav `save` ne odgovara serveru: nema rute za proizvoljno čuvanje celog zahteva.

Predlog novog potpisa, uz odgovarajuće importe i nove tipove:

```dart
abstract interface class WashRequestRepository {
  Future<RequestPage> list(RequestQuery query);
  Future<WashRequest?> find(WashRequestId id);
  Future<Result<WashRequest>> create(WashRequestDraft draft);
  Future<Result<WashRequest>> cancel({required WashRequestId id, required String reason});
  Future<Result<WashRequest>> assign({required WashRequestId id, required WasherId washerId});
  Future<Result<WashRequest>> release({required WashRequestId id});
}
```

Dodati aplikacione `RequestQuery` i `RequestPage` u `use_cases`. Query nosi scope mine/all, limit, offset i opcioni filter stanja; page nosi listu domenskih zahteva, total, limit i offset. Ne uvoziti `RequestPageDto` u ovaj sloj.

| Fajl | Konkretna izmena |
|---|---|
| `src/get_my_requests.dart` | `scope=mine`, bez prosleđivanja vlasnika serveru, rezultat je stranica. |
| `src/get_all_requests.dart` | `scope=all`, paginacija i opcioni filter. |
| Novi `src/get_request.dart` | Čitanje detalja po ID-u nezavisno od učitane liste. |
| `src/submit_request.dart` | Komanda `create` vraća serverski `Result`; ne preuzimati listu kao konačnu proveru limita. |
| `src/cancel_request.dart` | Poziva `cancel(id, reason)`; server određuje aktera, sat i konačnu dozvolu. |
| `src/accept_request.dart` | Poziva `assign(id, washerId)`; ukloniti konačnu proveru dostupnosti nad klijentskom listom i generički save. |
| `src/release_request.dart` | Poziva `release(id)`; bez slanja gotovog novog stanja. |
| `src/wash_request_draft.dart` | Ukloniti nepotreban `clientId`; fake adapter vlasnika dobija iz svoje sesije, server iz svoje. |
| `src/repository_exception.dart` | Razlikovati mrežu/timeout, protokol i sesiju; ne svesti sve na isti proizvoljan tekst. |
| `lib/use_cases.dart` | Izvesti nove tipove, portove i use case-ove. |

Za lokalni preview dozvola ostaju domen i prijavljeni korisnik. Oni služe prikazu; konačan rezultat komande stiže sa servera. Serverov interni `RequestStore` i transakcije ne zamenjivati ovim klijentskim portom.

Istim commit-om prilagoditi `apps/mobile/lib/data/fake_car_wash.dart`, `apps/backoffice/lib/data/fake_dispatch_repository.dart`, `packages/blocs/test/fake_wash_requests.dart` i privatne fake implementacije u `packages/use_cases/test`. Fake dobija korisnika i Clock, izvršava domen i podržava isti query/page/command oblik. Sačuvati kašnjenje i simulaciju neuspeha/praznog odgovora.

## 5. Napraviti zajednički api_client

Predlog novih fajlova u `packages/api_client`:

- `pubspec.yaml`: `resolution: workspace`, direktne zavisnosti `http`, `contracts`, `api_mapping`, `use_cases`, `domain` prema stvarnim importima.
- `lib/api_client.dart`: javni export.
- `lib/src/car_wash_api.dart`: osnovna adresa, slanje, JSON, statusi i ograničeno trajanje zahteva.
- `lib/src/http_wash_request_repository.dart`: port iz prethodnog koraka.
- `lib/src/http_auth_repository.dart`: login/me/logout.
- `lib/src/http_washer_repository.dart`: serverska lista perača.
- `lib/src/session_controller.dart`: tekuća native sesija i obaveštenje o njenom isteku; bez Flutter-a.
- `lib/src/http_client_factory.dart`, `_vm.dart`, `_web.dart`: odvojen izbor HTTP implementacije za platformu.
- `test/`: uspeh, poslovne greške, sesija, timeout i loš protokol.

Dodati paket u koreni `pubspec.yaml`, zatim `flutter pub get` i ažuriran `pubspec.lock`. Svaka aplikacija dodaje direktne zavisnosti koje zaista importuje.

Veza porta sa postojećim rutama:

| Radnja | HTTP |
|---|---|
| Login | `POST /auth/login` |
| Provera/obnova | `GET /auth/me` |
| Logout | `POST /auth/logout`, uspeh 204 |
| Lista | `GET /requests?scope=mine` ili `scope=all`, limit/offset/status |
| Detalj | `GET /requests/:id` |
| Kreiranje | `POST /requests`, telo `CreateRequest` |
| Dodela | `POST /requests/:id/assign`, telo `AssignRequest` |
| Vraćanje | `POST /requests/:id/release`, telo `{}` |
| Otkazivanje | `POST /requests/:id/cancel`, telo `CancelRequestDto` |
| Perači | `GET /washers`, odgovor `{"items": [...]}` |

Lista je `RequestPageDto`; detalj i uspešne komande imaju `RequestResponse` sa poljem `request`. Greška je direktno `{"code": ..., "details": ...}`, bez omotača `error`. Odgovor 204 ne dekodirati kao JSON.

Svaki zahtev ograničiti, npr. na deset sekundi. Poznato poslovno odbijanje komande prevesti kroz `ApiError` i `errorFromDto` u `Failure`, uključujući `not_allowed`/`not_found` gde su poslovni rezultat. Čitanje nedostupnog detalja prikazuje odgovarajuće stanje. `invalid_credentials` na login-u nije istek već otvorene sesije; `wrong_application` je poseban login razlog. Zaštićeni poziv sa 401 prekida odgovarajuću sesiju, a 403 ne odjavljuje automatski korisnika. Nečitljiv odgovor, 400/405 zbog pogrešnog zahteva i 500 imaju kontrolisanu tehničku obradu. Nepoznat poslovni kod dobija rezervnu korisničku poruku preko postojećeg mapper-a.

Ne praviti HTTP pozive iz widget-a. Ne ponavljati POST automatski: prekid odgovora ne dokazuje da upis nije izvršen. Kod neizvesnog ishoda ponuditi osvežavanje pre ponovnog slanja.

## 6. Prijava i bezbedno skladište

Dodati portove `AuthRepository`, `SessionStorage` i `WasherRepository` u `packages/use_cases/lib/src/ports/`, kao i aplikacioni tip sesije sa korisnikom i `expiresAt`. Auth port pokriva obnovu, prijavu i odjavu; storage port čita/upisuje/briše native token. Token ne uključivati u običan `toString`, Bloc stanje koje observer ispisuje ili log zahteva. Lozinka se ne čuva na uređaju.

Novi `packages/platform_adapters` implementira `SessionStorage` Flutter secure-storage pluginom; `use_cases`, `blocs` i `api_client` ne uvoze plugin. Native token ide u bezbedno skladište platforme, ne u obične preferences ili tekstualni fajl. Izabranu verziju plugina i njena Android/Apple podešavanja proveriti prema [dokumentaciji flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage).

Native login šalje `application=mobile` ili `backoffice` i `sessionTransport=bearer`. `SessionDto.token` se sačuva, a naredni pozivi šalju `Authorization: Bearer ...`. Pokretanje aplikacije: učitati token → pozvati `/auth/me` → otvoriti prijavljeni deo. Nevažeći/istekli token se briše; privremeni prekid mreže nudi retry i ne briše prijavu kao da je nevažeća.

Veb login šalje `application=backoffice`, `sessionTransport=cookie`. HTTP klijent je `BrowserClient` sa `withCredentials=true`; prema [BrowserClient dokumentaciji](https://pub.dev/documentation/http/latest/browser_client/BrowserClient-class.html) to omogućava slanje credentials za cross-site zahteve. Pregledač rukuje HttpOnly cookie-jem: ne čitati token, ne praviti njegovu kopiju u localStorage i ne slati native Authorization paralelno. Osvežavanje stranice obnavlja korisnika pozivom `/auth/me`.

Novi zajednički `AuthBloc` u `packages/blocs/lib/src/auth/` ima događaje i stanja za početnu proveru, login, uspeh, neuspeh, logout i istek. Pri isteku prikazuje „Prijava je istekla. Prijavite se ponovo.“ i uklanja korisničke podatke. Više paralelnih 401 odgovora ne pravi više preusmeravanja; zakašnjeli odgovor stare sesije ne sme odjaviti upravo prijavljen drugi nalog. Pri promeni korisnika zatvoriti stare Bloc-ove i odbaciti njihove kasne odgovore.

Normalan logout prvo opoziva serverovu sesiju, zatim briše native token i lokalni korisnički podsklop. Pri neuspešnom logout-u prikazati problem i ponuditi ponovni pokušaj. Posebno na vebu ne tvrditi da je potvrđena trajna odjava dok server nije obrisao HttpOnly cookie. Ne praviti lažnu uspešnu odjavu koja se posle F5 pretvara u prijavu.

## 7. Prilagoditi postojeće Bloc-ove

`packages/blocs/lib/src/my_requests/my_requests_bloc.dart` i event/state:

- Učitavanje stranice iz novog use case-a, sa total/limit/offset.
- Događaji za osvežavanje i promenu stranice.
- Prijavljeni korisnik dolazi iz stvarne sesije.
- Posle uspeha i poslovnog odbijanja otkazivanja ponovo učitati podatke.
- Odbijanje i poruka ostaju vidljivi i ako reload vrati praznu listu ili mrežnu grešku.
- Za perača prikazati njegove dodeljene aktivne poslove, bez kreiranja/klijentskog otkazivanja.

`packages/blocs/lib/src/dispatch/dispatch_bloc.dart` i event/state:

- Nove eksplicitne assign/release/cancel komande.
- Paginacija i filteri na serveru, očuvan izbor kada zapis ostaje dostupan.
- Učitavanje perača sa `/washers` i osvežavanje posle promene/odbijanja.
- Dostupnost dolazi iz `hasActiveJob`, ne iz prebrojavanja samo trenutne stranice.
- Posle `washer_busy` i drugog poslovnog odbijanja prikazati razlog i obnoviti zahteve/perače.
- Svaki završetak uklanja busy indikator. Ne sakriti prvobitni poslovni razlog naknadnom greškom reload-a.

`packages/blocs/lib/src/wash_request_form/wash_request_form_bloc.dart` i event/state: zadržati editing/submitting/done/rejected/failed. Poslovna greška ostaje tipizovana; timeout ili mreža završavaju slanje bez gubitka unosa. Posle odbijanja osvežiti relevantnu listu uz očuvanu poruku.

Dodati `RequestDetailBloc` u `packages/blocs/lib/src/request_detail/` i izvesti ga kroz `lib/blocs.dart`. Detalj koristi `find(id)`: mora raditi kada zapis nije na trenutnoj stranici, na direktnoj adresi i posle osvežavanja. Potrebna stanja: učitavanje, podaci, nedostupan/nepostojeći zapis, greška i retry.

## 8. Mobilna aplikacija: fajl po fajl

| Fajl | Šta se menja |
|---|---|
| `apps/mobile/pubspec.yaml` | Zavisnosti na zajednički api_client i platform_adapters. |
| `lib/config.dart` — novi | `API_BASE_URL` konfiguracija i platformska podrazumevana adresa. |
| `lib/main.dart` | Prave zavisnosti umesto bezuslovnog `AppDependencies.fake()`. |
| `lib/dependencies.dart` | Mrežna fabrika, auth/storage i repo zavisnosti; `currentClient` samo za fake/test. |
| `lib/app.dart` | AuthBloc iznad rutera; korisnički Bloc-ovi tek za proverenu sesiju, ponovo kreirani pri promeni naloga. |
| `lib/router.dart` | Login/provera sesije i zaštita privatnih ruta; `/prices` ostaje javan. |
| `lib/screens/login_screen.dart` — novi | Username, skrivena lozinka, loading, submit i poruke. |
| `lib/screens/home_shell.dart` | Korisnik/uloga, logout i odgovarajuća navigacija. |
| `lib/screens/my_requests_screen.dart` | Prava lista, stranice, retry, poruka i reload; akcije prema ulozi. |
| `lib/screens/new_request_screen.dart` | Novi nacrt bez clientId, lokalni domen, poslovna zona, očuvan unos kod odbijanja. |
| `lib/screens/request_detail_screen.dart` | Ne traži zapis samo u `MyRequestsLoaded`; koristi zaseban detalj po ID-u. |
| `lib/data/fake_car_wash.dart` | Novi port i sesijski korisnik; ostaje za testove. |
| `test/support.dart` i postojeći testovi | Ubrizgan fake auth/storage; sačuvati KT1 i nove layout/regression provere. |

Prava uzimati iz `mayCreateRequest`, `mayViewRequest`, `mayCancelRequest` i postojećeg domenskog pravila otkazivanja, ne iz novih kopija if-uslova po ekranima. Perač nema nove staff akcije: postojeće serverske rute su izvor dozvoljenih funkcija. Završavanje pranja/offline fotografije ne uvoditi kao obavezni KT2 posao; offline deo pripada KT3.

## 9. Backoffice: fajl po fajl

| Fajl | Šta se menja |
|---|---|
| `apps/backoffice/pubspec.yaml` | Isti zajednički api_client/platform_adapters. |
| `lib/config.dart` — novi | URL iz konfiguracije; desktop i veb podrazumevano localhost. |
| `lib/main.dart` | Mrežne zavisnosti umesto bezuslovnog `BackofficeDependencies.fake()`. |
| `lib/dependencies.dart` | Stvarni korisnik/sesija i repozitorijumi; ukloniti fiksne perače iz mrežne konfiguracije. |
| `lib/app.dart` | Provera sesije, login i odvojen prijavljeni dispečerski podsklop; uklanjanje starih podataka na logout. |
| `lib/screens/login_screen.dart` — novi | `application=backoffice`; `wrong_application` prikazati kao „Backoffice je namenjen dispečerima.“ |
| `lib/screens/dispatch_screen.dart` | Server podaci, stranice, perači, retry, auth poruke; očuvati strelice, A, Esc, F5 i fokus. |
| `lib/widgets/request_details.dart` | `assignWasher` koristi učitane perače i `hasActiveJob`; imena više ne dolaze iz statičkog `washerName`. |
| `lib/screens/request_detail_screen.dart` | Serverski detalj i akcije na uskom ekranu, bez zavisnosti od slučajno učitane stranice. |
| `lib/data/fake_dispatch_repository.dart` | Isti novi port za testove. |
| `test/support.dart`, `dispatch_screen_test.dart` | Fake sesija/perači, prečice, selekcija, poruke i raspored. |

Postojeći backoffice nema svoj `router.dart`; nije obavezno uvoditi ga samo zbog login-a. Jednostavan auth omotač je dovoljan ako čuva potrebnu navigaciju i ponašanje pri refresh-u. Ako se uvode adresabilne backoffice rute, dodati ih dosledno i testirati direktno otvaranje.

Sačuvati postojeće teme, potvrde nepovratnih akcija i širok/uski raspored. U mrežnom radu nema tihog prebacivanja na fake ako server ne radi.

## 10. Vreme, poruke i paginacija

U `packages/ui/lib/src/text/serbian.dart` pre formatiranja datuma i vremena pozvati `inBusinessTime`. U mobilnom izboru termina izabrane komponente tumačiti preko `businessDate`, a na mrežu slati UTC preko postojećeg DTO-a. Ne dodavati samo slovo Z lokalnom vremenu. Testirati isti termin sa računarom/uređajem u drugoj zoni.

`domain_errors.dart` već koristi `maxLength`, rokove i limite iz greške; zadržati to. Auth/network poruke dodati na jednom zajedničkom mestu u `ui`. Ne prikazivati sirovi JSON, SQL, stack trace ili exception tekst korisniku. Nepoznato pravilo ima kontrolisanu poruku.

Početni limit: mobilni 20, backoffice 50; server dozvoljava 1–100. Dodati jednostavne prethodna/sledeća kontrole i total. Filter i paginacija šalju se serveru. Broj stavki trenutne stranice ne predstavljati kao ukupni broj u sistemu. Ako offset posle promene izađe iz opsega, učitati poslednju važeću stranicu. Ako se učitavaju aktivni i istorijski zahtevi odvojeno, svaki upit ima svoj filter i paginaciju.

Tuđe promene u KT2 mogu se videti ručnim osvežavanjem. Posle sopstvene komande i poslovnog odbijanja radi automatski reload. WebSocket nije potreban da se ispuni ovaj zahtev.

## 11. Adrese i platformska podešavanja

Javna konfiguracija `API_BASE_URL` može koristiti `--dart-define`; nije tajna. Podrazumevano Android emulator `http://10.0.2.2:8080`, iOS simulator/macOS/veb `http://localhost:8080`. Za fizički telefon LAN pristup je poseban slučaj i zahteva odgovarajuće objavljivanje porta; nije isto što i localhost.

U Android `apps/mobile/android/app/src/main/AndroidManifest.xml` dodati `android.permission.INTERNET`. Lokalni HTTP dozvoliti u razvojnoj konfiguraciji i proveriti odgovarajući debug/profile manifest; ne rešavati to promenom produkcionog URL-a na nepovezan servis. Ako se demonstrira release nad lokalnim HTTP-om, i taj build mora imati jasno dokumentovanu razvojnu konfiguraciju.

U `apps/backoffice/macos/Runner/DebugProfile.entitlements` i `Release.entitlements` dodati `com.apple.security.network.client`. Android i macOS zahteve navodi [Flutter Networking dokumentacija](https://docs.flutter.dev/data-and-backend/networking). Secure-storage/Keychain podešavanja uzeti iz izabrane verzije plugina; samo uspešan upis bez čitanja posle restarta nije dovoljna provera.

Za iOS proveriti `apps/mobile/ios/Runner/Info.plist`, razvojni lokalni HTTP/ATS i Keychain konfiguraciju. Ako se ponovi Finder/FileProvider problem Desktop foldera, videti `docs/kt2-provere.md`; to je lokalni build izlaz, ne razlog za menjanje domena ili servera.

Veb pokretati na `http://localhost:3000`, koji je već u serverskom CORS podešavanju. Ne mešati `localhost` i `127.0.0.1`. Ako se port/origin namerno promeni, uskladiti `CORS_ALLOWED_ORIGINS` i ponovo kreirati server konfiguracijom Compose-a. CORS ne rešavati gašenjem browser zaštite.

Dodati jednostavne ponovljive skripte u `tool/` ili jednako precizne README komande. Primeri iz foldera odgovarajuće aplikacije:

```bash
flutter run -d <android-device-id> --dart-define=API_BASE_URL=http://10.0.2.2:8080
flutter run -d <ios-simulator-id> --dart-define=API_BASE_URL=http://localhost:8080
flutter run -d macos --dart-define=API_BASE_URL=http://localhost:8080
flutter run -d chrome --web-port=3000 --dart-define=API_BASE_URL=http://localhost:8080
```

ID birati iz `flutter devices`; uglaste zagrade su mesto za stvarnu vrednost, ne doslovna shell komanda.

Dodavanje Flutter platformskog paketa u koreni workspace ne znači da ga treba dodati u `apps/server/tool/pubspec.docker.yaml`. Docker namerno koristi uži čisti Dart workspace. Posle svih izmena zavisnosti obavezno ponoviti serverski Docker build: `pubspec.lock` dele ceo projekat i Docker.

## 12. Redosled rada i predloženi commit-i

1. Portovi, query/page tipovi i svi fake adapteri/pozivaoci; testovi ponovo prolaze.
2. Zajednički HTTP adapter i mapiranje odgovora/grešaka, uz MockClient testove.
3. Auth port, session storage, AuthBloc i platformski adapter.
4. Prva integracija login + lista u obe aplikacije. Pre ostalog dokazati da oba klijenta čitaju istu bazu.
5. Kreiranje, otkazivanje, dodela i vraćanje u red; poslovno odbijanje + reload.
6. Detalj po ID-u, paginacija, pravi perači, poslovna zona i dovršavanje UI tokova.
7. Platformska podešavanja, buildovi, kompletan demo i README.

Imena commit-a opisuju stvarnu promenu; nije potrebno menjati autora ili dodavati co-author trailer. Ako nešto zahteva promenu servera, poslati Milanu tačan poziv, telo, status i očekivanje, bez tokena/lozinki iz stvarnih naloga. Ne razvijati drugi API da bi se zaobišao postojeći.

## 13. Obavezne završne provere

Pored postojećih 159 testova, dodati ciljane testove novih portova, mreže i auth toka:

- 200/201/204, pagination, sva stanja i detalj van prve stranice.
- 409/422 poslovni razlog, 401 sesija, 403 prava/pogrešna aplikacija, nepoznata greška, 500 i loš JSON.
- Timeout/nedostupan server završavaju loading i dopuštaju retry; ne ponavljaju upis automatski.
- Obnova native tokena, browser `/me`, login, logout, istek, paralelni 401 i promena korisnika bez starih podataka.
- Odbijanje komande čuva razlog i radi reload, uključujući prazan odgovor i neuspešan reload.
- Widget testovi login-a, zabrane ruta/akcija, čuvanja forme, paginacije i postojećeg rasporeda/prečica.

Iz korena, sa pokrenutim testnim PostgreSQL-om:

```bash
flutter pub get
flutter analyze
dart format --output=none --set-exit-if-changed apps packages
docker compose --profile test up -d --wait test-db
TEST_DATABASE_PORT=55432 dart test packages/domain/test packages/use_cases/test packages/blocs/test packages/contracts/test packages/api_mapping/test packages/api_client/test apps/server/test
flutter test apps/mobile/test apps/backoffice/test packages/ui/test
```

Dodati i testove platformskog paketa ako ih implementacija ima. Serverski testovi moraju biti stvarno izvršeni sa `TEST_DATABASE_PORT`, ne preskočeni. Ne koristiti razvojnu bazu kao testnu.

Zatim praktično pokazati:

1. Čist klon, neizmenjen `.env.example` → `.env`, jedna Compose komanda, health i seed.
2. Android/iOS simulator ili emulator, desktop backoffice i browser istovremeno na istoj bazi.
3. Marko kreira zahtev; dispečer ga vidi posle refresh-a, dodeljuje perača; Marko vidi promenu. Ana ne vidi Markove privatne zahteve.
4. Dispečer vraća zahtev u red; klijent otkazuje svoj zahtev. Potvrde i poruke rade.
5. Dva odvojena prijavljena backoffice klijenta pokušaju istog slobodnog perača: jedan uspeva, drugi dobija razlog i osvežene podatke.
6. Klijent ne može da uđe u backoffice; dve staff komande i tuđe otkazivanje odbijaju se i direktnim API pozivom.
7. Zatvaranje/ponovno otvaranje mobilne i desktop aplikacije i F5 browser-a zadržavaju prijavu. Logout je briše; istek serverove konfiguracije vraća na login uz poruku.
8. Ugašen server daje razumljivu grešku i retry, bez beskonačnog učitavanja. Posle povratka servera aplikacija nastavlja rad.
9. Izgraditi i sačuvati stvarnu mobilnu aplikaciju sa limitom napomene 300. Promeniti samo serverski domen na 200 i ponovo izgraditi server. Bez nove kompilacije mobilne aplikacije poslati 250 znakova: videti poruku sa 200, očuvan unos i reload. Posle demonstracije vratiti izmenu pravila.
10. Build mobilne aplikacije, desktop i web release. Čist Docker build i start posle svih promena workspace-a i lockfile-a.

Već izvršena provera starog AOT Dart klijenta potvrđuje ugovor/mapper/poruku; ne zamenjuje tačku 9 sa stvarnom mobilnom aplikacijom. Postojeći fake widget i browser testovi ne dokazuju povezivanje obe aplikacije sa bazom.

## 14. Kada je Andrijin deo završen

- Obe aplikacije podrazumevano koriste stvarni server i zajednički mrežni kod.
- Sve postojeće KT1 radnje i sva četiri KT2 kriterijuma rade kroz te aplikacije.
- Sesije i skladište stvarno rade na mobilnoj, desktop i veb platformi.
- Poznate i nepoznate greške imaju korisnički tekst; server ostaje konačni izvor pravila i prava.
- README navodi pokretanje iz čistog klona, adrese, demo naloge i komande za sve ciljne platforme.
- Testovi, buildovi i opisani praktični scenariji imaju potvrđen rezultat, uz navedena eventualna ograničenja.
- PR ide sa `feature/kt2-clients` na ažuriran `main`, posle pregleda i integracije.

Rok iz dostavljenog zadatka je 21. 11. 2026. u 23:59:59, kada kod već mora biti na GitHub `main`. Oba člana na odbrani objašnjavaju ceo sistem: granice slojeva, zajednička pravila, transakcije, ugovor, sesije, paginaciju i ručno osvežavanje, uključujući bar jednu odbačenu mogućnost za važne odluke.
