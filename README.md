# tim-09
CarWash &amp; Go - Sistem za brzo naručivanje i zakazivanje terenskog pranja automobila na parkingu klijenta uz odabir ekonomične ili profesionalne usluge.

# CarWash &amp; Go 

Sistem za naručivanje terenskog pranja vozila. Platforma povezuje vlasnike vozila kojima je potrebno pranje na trenutnoj lokaciji sa peračima u blizini, omogućavajući izbor tipa pranja i praćenje statusa usluge u realnom vremenu.

Projekat iz predmeta Razvoj multiplatformskih aplikacija.

## Tim

| Ime i prezime | Broj indeksa | GitHub nalog |
| --- | --- | --- |
| Milan Šegan | 107/24 SI | [@github-nalog](https://github.com/sShegy) |
| Andrija Stojanović | 93/24 SI | [@github-nalog](https://github.com/andrijas6) |

## Zahtevi za temu

1. **Uloge.** Sistem koriste klijenti, perači i administratori sa različitim ovlašćenjima: klijent naručuje pranje, perač prihvata poslove, a administrator nadgleda sistem i rešava žalbe.
2. **Stanja.** Zahtev za pranje prolazi kroz više stanja: prijavljen na lokaciji, prihvaćen od strane perača, u toku (pranje se obavlja), i na kraju završen ili otkazan.
3. **Pravila.** Perač ne može prihvatiti novi zahtev za pranje ukoliko već ima aktivan posao u toku, o čemu konačnu odluku donosi server proverom preklapanja.
4. **Rad bez mreže.** Perač može uslikati opran auto i označiti posao kao završen čak i u podzemnoj garaži bez signala; podaci se automatski šalju na server kada se veza uspostavi.
5. **Posao za osoblje.** Administrator u backoffice aplikaciji na velikom ekranu ima uvid u zbirnu mapu svih aktivnih zahteva, prati lokacije perača i odobrava njihove profile.
6. **Javni sadržaj.** Cenovnik usluga, kalkulator procene cene pranja na osnovu tipa vozila i recenzije dostupni su svima bez prijave, što ima smisla da pronađu pretraživači.

## Delovi sistema

| Deo | Korisnici | Tehnologija | Platforme |
| --- | --- | --- | --- |
| Mobilna aplikacija | klijenti, perači | Flutter | Android |
| Backoffice | administratori | Flutter | Windows, veb |
| Javni veb | svi posetioci | Jaspr | pregledač |
| Server | ostali delovi sistema | Relic, PostgreSQL | Linux |
| Domenski paket | svi delovi sistema | Dart | sve |

Svi delovi koriste isti domenski paket, u kome su model i pravila. Server čuva podatke i ponovo proverava svako pravilo.
