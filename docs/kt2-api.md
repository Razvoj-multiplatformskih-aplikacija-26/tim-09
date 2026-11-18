# KT2: ugovor i povezivanje klijenata

Server, baza, autentifikacija i zajednički ugovor nalaze se na grani `feature/kt2-server`. Mobilna aplikacija i backoffice u ovom koraku zadržavaju KT1 fake adaptere. Sledeći korak je zajednički mrežni adapter, AuthBloc i povezivanje ekrana.

## Paketi koje klijenti koriste

- `contracts`: DTO tipovi, bez uvoza domena, Flutter-a i dart:io.
- `api_mapping`: DTO ↔ domen i prevod grešaka u oba smera.
- `domain`: ista pravila, prava i modeli na klijentima i serveru.
- `use_cases`, `blocs`, `ui`: postojeći tokovi, portovi i poruke.

Javne funkcije mapper-a: `requestToDto`, `requestFromDto`, `statusToDto`, `statusFromDto`, `userToDto`, `userFromDto`, `washerToDto`, `washerFromDto`, `errorToDto`, `errorFromDto`. Funkcija `createFromDto` služi serveru: poziva zajedničko domensko kreiranje i njegove validacije.

Sačuvani podaci se rekonstruišu preko `existing` konstruktora. Oni nisu namenjeni validaciji novog korisničkog unosa. Greške imaju parametre stvarnog pravila; UI ih koristi umesto lokalnih konstanti.

## HTTP

Osnovna adresa je `http://localhost:8080`. Za Android Emulator koristi se `http://10.0.2.2:8080`. Veb aplikacija se pokreće na `http://localhost:3000`.

| Poziv | Uspeh | Namena |
|---|---|---|
| GET /health | 200 | Spremnost servera i baze |
| POST /auth/login | 200 | Korisnik, rok i native token ili veb cookie |
| GET /auth/me | 200 | Obnova/provera sesije |
| POST /auth/logout | 204 | Opoziv sesije |
| GET /requests?scope=mine&limit=20&offset=0 | 200 | Svoje narudžbine ili dodeljeni aktivni poslovi perača |
| GET /requests?scope=all&limit=50&offset=0 | 200 | Dispečerski pregled |
| GET /requests/:id | 200 | Dostupan detalj |
| POST /requests | 201 | Novi zahtev klijenta |
| POST /requests/:id/assign | 200 | Dodela perača, samo dispečer |
| POST /requests/:id/release | 200 | Vraćanje u red, samo dispečer |
| POST /requests/:id/cancel | 200 | Otkazivanje po pravu, stanju i roku |
| GET /washers | 200 | Lista perača i dostupnost, samo dispečer |

Lista vraća `RequestPageDto` sa `items`, `total`, `limit`, `offset`. Podržan je filter `status`: submitted, accepted, in_progress, completed, cancelled. Limit je 1–100, offset nenegativan. Sortiranje: termin rastuće, pa ID rastuće. Dispečer koristi scope all; klijent i perač mine.

Detalj i komande vraćaju `RequestResponse`, odnosno JSON `{"request": {...}}`. Dodela koristi `AssignRequest(washerId: ...)`, otkazivanje `CancelRequestDto(reason: ...)`, vraćanje u red prazan objekat `{}`.

## Prijava i identitet

```json
{
  "username": "marko",
  "password": "DemoPass123!",
  "application": "mobile",
  "sessionTransport": "bearer"
}
```

Aplikacije: mobile i backoffice. Transport: bearer za native, cookie za veb. Odgovor `SessionDto` ima `user`, `expiresAt` i native `token`. U korisniku perača postoji i `washerId`. Uloga dolazi iz baze, a ne iz login zahteva.

Native šalje `Authorization: Bearer <token>` i čuva token iza porta u bezbednom skladištu platforme. Veb koristi BrowserClient sa credentials, HttpOnly cookie i `/auth/me`; u veb JSON-u nema tokena. Cookie mutacije traže dozvoljeni Origin. CORS i preflight su na serveru.

HTTP 401 znači nevažeću/isteklu/opozvanu prijavu. HTTP 403 znači pogrešnu aplikaciju ili nedostatak prava, pa ne treba automatski odjaviti svaku postojeću sesiju. Login pogrešnom aplikacijom dobija `wrong_application`.

Kreiranje ne šalje vlasnika, ulogu, cenu, trajanje ili stanje. Server ih određuje. Ne šalje se ceo izmenjeni `WashRequest` kao proizvoljni save.

## Kreiranje i podaci

```json
{
  "vehicle": {"type": "sedan", "plate": "BG 123-AB"},
  "tier": "economy",
  "address": {"text": "Knez Mihailova 6, Beograd"},
  "start": "2026-11-19T09:00:00Z",
  "note": "Parking iza zgrade."
}
```

Datum je primer. `CreateRequest` kodira vreme u UTC. Radno vreme je u Europe/Belgrade. `inBusinessTime` i `businessDate` su zajedničke domenske pomoćne funkcije; pri prikazu i izboru termina potrebno je koristiti poslovnu zonu.

JSON datum mora imati postojeći kalendarski datum, sekunde i vremensku zonu (`Z` ili eksplicitni offset). Nemogući datumi i vremena se odbijaju, umesto da se automatski prebace u sledeći mesec ili dan. DTO odgovori dopuštaju dodatna polja radi kompatibilnosti, dok se neočekivana polja u komandama odbijaju.

`WashRequestDto` dodatno ima id, clientId, slot.start, slot.durationMinutes, createdAt, priceRsd, currency i status. Novac je ceo broj dinara, currency je RSD. Status je objekat sa type i podacima iz postojećih domenskih stanja. `StatusDto` čuva oznaku i podatke; oba smera prevoda su u mapper-u.

Lista perača vraća `{"items": [...]}`; svaki `WasherDto` ima id, name i hasActiveJob. Dostupnost se računa nad svim aktivnim poslovima. UI ne računa zauzetost samo iz trenutne stranice zahteva.

## Greške

```json
{"code":"note_too_long","details":{"actualLength":250,"maxLength":200}}
```

Greška je na vrhu JSON-a, bez error omotača i bez gotove korisničke poruke. `ApiError.fromJson` čuva i nepoznate kodove. `errorFromDto` ih pretvara u `RemoteRuleViolation`; UI već ima rezervnu poruku.

| HTTP | Kodovi |
|---|---|
| 400 | invalid_request |
| 401 | invalid_credentials, unauthenticated, session_expired, session_revoked |
| 403 | wrong_application, not_allowed |
| 404 | not_found |
| 405 | method_not_allowed |
| 409 | washer_busy, too_many_pending_requests, invalid_transition |
| 422 | invalid_license_plate, address_missing, note_too_long, slot_too_soon, slot_too_far, slot_not_on_half_hour, outside_working_hours, cancellation_too_late |
| 500 | server_error |

Detalji: note_too_long nosi actualLength/maxLength; slot_too_soon minNoticeMinutes/earliestAllowedStart; slot_too_far maxAdvanceDays/latestAllowedStart; outside_working_hours openingHour/closingHour/businessTimeZone; cancellation_too_late noticeMinutes/washerLateAfterMinutes; too_many_pending_requests maxPending/currentPending; washer_busy washerId. InvalidTransition sadrži potpune from/to status objekte.

JSON oblik greške i CORS zaglavlja važe i za nepostojeću rutu i pogrešan HTTP metod. Preflight `OPTIONS` obrađuje se pre rutiranja.

## Sledeći koraci za klijente

1. Napraviti jedan čist Dart `api_client` za oba klijenta.
2. Uskladiti klijentski port sa eksplicitnim create/cancel/assign/release komandama i stranicama liste. Postojeći port/fake adapteri zasad ostaju kompatibilni.
3. Dodati auth port, AuthBloc, login/logout i obnovu prijave. Fiksni currentClient/currentDispatcher ostaju samo u fake/test konfiguraciji.
4. Native skladištenje tokena ide iza porta u Keychain/Keystore i desktop bezbedno skladište. Veb ostaje na HttpOnly cookie-ju.
5. Poslovnu HTTP grešku vratiti kao tipizovan Failure; mrežu i sesiju obraditi odvojeno.
6. Posle odbijene akcije osvežiti podatke uz očuvanu poruku.
7. Povezati oba klijenta na stvarni server kroz njihove dependencies fabrike.
8. Učitavati detalj nezavisno od trenutne stranice liste i perače sa servera.
9. Podesiti Android INTERNET/debug HTTP, macOS network.client i web credentials.
10. Proveriti restart, istek i logout na svakoj ciljnoj platformi; ranije izgrađena aplikacija mora pročitati novu granicu pravila iz details.

## Serverske odluke za odbranu

- Pravilo jednog aktivnog posla računa domen; server ga izvršava u transakciji uz zaključavanje perača i zahteva.
- Ograničenje broja zahteva koristi zaključavanje vlasnika pre brojanja i kreiranja.
- Cena, trajanje, ID, vlasnik i vremena promene dolaze sa servera.
- Sesije su nasumični tokeni sa hešom u bazi, istekom i opozivom; lozinke su bcrypt heševi.
- Migracije i seed se automatski primenjuju. Seed ima 12 zapisa svih stanja i šest demo naloga.
- Spoljni servis je iza GeocodingGateway porta; KT2 adapter daje determinističke demo koordinate. Koordinate su interno sačuvane u bazi, a postojeći Address i mrežni ugovor ostaju tekstualni.
- Ručno osvežavanje je plan za tuđe promene; budući treći klijent može koristiti iste DTO, mapper i domenska prava.
