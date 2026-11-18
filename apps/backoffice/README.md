# Backoffice

Dispečerska tabla sistema CarWash & Go, za veliki ekran (Windows, macOS i veb). Dispečer vidi sve zahteve podeljene na red čekanja, aktivne i prethodne, dodeljuje perača, vraća prihvaćen zahtev u red i otkazuje zahteve.

Perač koji već ima prihvaćen posao ili posao u toku ne može da dobije novi. Pravilo je u domenskom paketu, isto kao za mobilnu aplikaciju i server.

Od KT2 aplikacija počinje prijavom dispečera i radi sa serverom preko paketa `api_client`; perači i njihova dostupnost stižu sa servera. Fake podaci u memoriji (`lib/data/`) koriste se u testovima i uz `--dart-define=FAKE_DATA=true`. Implementacije se biraju samo u `lib/dependencies.dart`.

## Pokretanje

```sh
cd apps/backoffice
flutter run -d chrome --web-port=3000   # veb, origin mora biti http://localhost:3000
flutter run -d windows                  # Windows, samo na Windows računaru
flutter run -d macos                    # macOS, samo na Macu
flutter test
flutter test integration_test -d windows   # prijava i obnova nad pokrenutim serverom
```

## Prečice

| Taster | Radnja |
| --- | --- |
| ↑ / ↓ | prethodni / sledeći zahtev |
| A | dodela perača izabranom prijavljenom zahtevu |
| Esc | poništava izbor |
| F5 | osvežava listu |

Filter stanja i stranice (po 50 zahteva) šalju se serveru. Tuđe promene se vide ručnim osvežavanjem; posle sopstvene radnje i poslovnog odbijanja tabla se osvežava sama.

Na prozoru užem od 900 px detalji se otvaraju na posebnom ekranu. U debug izdanju meni sa epruvetom simulira grešku servera i prazan odgovor.
