# Backoffice

Dispečerska tabla sistema CarWash & Go, za veliki ekran (Windows i veb). Dispečer vidi sve zahteve podeljene na red čekanja, aktivne i prethodne, dodeljuje perača, vraća prihvaćen zahtev u red i otkazuje zahteve.

Perač koji već ima prihvaćen posao ili posao u toku ne može da dobije novi. Pravilo je u domenskom paketu, isto kao za mobilnu aplikaciju i server.

U KT1 aplikacija radi sa lažnim repozitorijumom u memoriji (`lib/data/`) i kao jedan, unapred prijavljen dispečer. Implementacije se biraju samo u `lib/dependencies.dart`.

## Pokretanje

```sh
cd apps/backoffice
flutter run -d chrome     # veb
flutter run -d windows    # Windows, samo na Windows računaru
flutter test
```

## Prečice

| Taster | Radnja |
| --- | --- |
| ↑ / ↓ | prethodni / sledeći zahtev |
| A | dodela perača izabranom prijavljenom zahtevu |
| Esc | poništava izbor |
| F5 | osvežava listu |

Na prozoru užem od 900 px detalji se otvaraju na posebnom ekranu. U debug izdanju meni sa epruvetom simulira grešku servera i prazan odgovor.
