# PetCall 2.0 — specyfikacja interfejsu

**Data:** 2026-10-15 · **Status:** do akceptacji · **Plan nadrzędny:** `docs/superpowers/plans/2026-10-15-petcall-12.1.5-update.md` (etap 2)

## 1. Cel i kryteria sukcesu

PetCall 2.0 dostaje nowy interfejs, który wygląda jak część gry, zachowuje wszystkie funkcje 1.0.x i jest prostszy w użyciu.

Kryteria sukcesu:
- Nowy gracz w kilka minut, bez instrukcji, ustawia pety, które lubi, i te, których nie chce.
- Doświadczony gracz buduje reguły typu „w mieście albo w raidzie na specjalizacji X” bez drzew AND/OR i bez kodu Lua.
- Gracz w każdej chwili widzi, dlaczego pet się nie przywołał (powody wstrzymania) i dlaczego dany zestaw jest lub nie jest aktywny (stan każdego warunku).
- Profile i zestawy z 1.0.x działają po aktualizacji identycznie, bez ręcznej migracji.
- Bez EllesmereUI interfejs wygląda jak natywny interfejs gry; z EllesmereUI przyjmuje jego skórkę.

## 2. Decyzje

| Decyzja | Wybór |
|---|---|
| Biblioteki | bez Ace3 i CallbackHandler; tylko LibStub, LibDataBroker-1.1, LibDBIcon-1.0 |
| Technika budowy UI | ramki tworzone w Lua na szablonach i mixinach Blizzarda (bez XML, bez własnego systemu układu) |
| Miejsce okna | samodzielne okno (bez dokowania do Dziennika Petów, bez zakładki w Kolekcjach) |
| Pierwszy plan | siatka petów; lista zestawów jako zwijany panel boczny, rozwijany automatycznie przy więcej niż jednym zestawie |
| Warunki zestawów | zdania z wieloma wartościami i przełącznikiem [nie]; jeden poziom grup „LUB”, ukryty do czasu użycia; Lua i makra w sekcji Zaawansowane |
| Filtry | zastąpione „regułami automatycznymi” (chipy) nad siatką; sumowanie wag bez zmian |
| Wagi | 6 poziomów bez zmian w danych; nowa obsługa (klik, PPM, suwak) i szansa w % |
| EllesmereUI | wyłącznie skórka przez `EllesmereUI.RegisterSkin`; **bez** sekcji w panelu opcji EllesmereUI |

## 3. Okno główne

- Ramka `ButtonFrameTemplate` z ikoną PetCall jako portretem, tytuł „PetCall”, przycisk ⚙ (otwiera kategorię PetCall w panelu Ustawień) i ×.
- Domyślnie 820×560; zmiana rozmiaru uchwytem (min. 640×440, maks. rozmiar ekranu), przesuwanie za tytuł, `SetClampedToScreen`. Pozycja, rozmiar i skala zapisywane na konto.
- ESC zamyka okno (`UISpecialFrames`). Okno otwiera się również w walce; nie wykonuje żadnych akcji chronionych.
- Otwierane przez: `/pcall`, `/petcall`, skrót „Open Configuration”, Ctrl+klik na przycisku minimapy / LDB / Addon Compartment, pozycję „Otwórz PetCall” w menu PPM, przycisk w panelu Ustawień.
- Budowane leniwie przy pierwszym otwarciu.

### 3.1 Panel „Zestawy” (lewy)

- Zwijany przyciskiem «/». Gdy istnieje wyłącznie zestaw domyślny — zwinięty do wąskiego paska z przyciskiem „Zestawy”. Rozwija się automatycznie, gdy istnieje więcej niż jeden zestaw (dopóki gracz go ręcznie nie zwinie; stan zapamiętany).
- Kolejność: „Domyślny” zawsze pierwszy, dalej malejąco wg priorytetu, potem alfabetycznie.
- Wiersz: kropka stanu + nazwa + znaczek priorytetu (+1, +2, …; brak dla „Normalna”).
  - ● aktywny teraz (to ten zestaw losuje peta),
  - ○ włączony, warunki niespełnione,
  - pomarańczowy ● — brak petów do wylosowania albo brak warunków (dymek wyjaśnia, co konkretnie),
  - ◌ wyłączony (nazwa przygaszona, dopisek „wył.”).
- PPM na wierszu (MenuUtil): Włącz/Wyłącz, Zmień nazwę, Eksportuj, Usuń (potwierdzenie StaticPopup). Zestaw domyślny: tylko Eksportuj.
- Na dole: „+ Nowy” (pole nazwy w wierszu, Enter tworzy; walidacja: niepusta, nie zaczyna się od `$`, unikalna — błąd przy polu) i „Importuj”.

### 3.2 Zakładki zestawu

- **Pety**, **Kiedy** (niewidoczna dla zestawu domyślnego), **Ustawienia zestawu**.
- Przełączenie zestawu zachowuje bieżącą zakładkę, jeśli istnieje w nowym zestawie.

### 3.3 Pasek stanu (dół okna)

- Lewa część: „Aktywny: ‹zestaw› · Pet: ‹nazwa›” (lub „brak peta”).
- Środek: „Wstrzymane przez: walka, lot” albo „Gotowy”. Dymek: pełna lista powodów z krótkim opisem.
- Prawa część: „Przywołaj inny” (= `resummon`) oraz przełącznik „Auto-przywoływanie: WŁ/WYŁ” (= główne `enable`).
- Odświeżany wyłącznie na callbacki rdzenia (`ReadyChanged`, `CurrentSetChanged`, `PetsChanged`).

## 4. Zakładka Pety

### 4.1 Pasek narzędzi

- Pole wyszukiwania (`SearchBoxTemplate`) — dopasowanie do nazwy gatunku i własnej nazwy, bez rozróżniania wielkości liter, opóźnienie 150 ms.
- Menu „Filtr” (MenuUtil):
  - Pokaż: wszystkie / wybrane (waga > 0, ręcznie lub regułą) / niewybrane,
  - typy petów (wielokrotny wybór), tylko ulubione,
  - sortowanie: nazwa (domyślnie), poziom, rzadkość, szansa,
  - „Ustaw wagę dla wszystkich widocznych ▸” (6 poziomów; potwierdzenie przy > 20 petach).
  - Stan filtra zapamiętany na sesję, nie w profilu.
- „Pozostałe pety: [waga ▾]” — waga domyślna zestawu (`defaultValue`).
- „Wyczyść” — usuwa wszystkie ręczne wagi zestawu (potwierdzenie).

### 4.2 Reguły automatyczne (dawne filtry)

- Pasek chipów pod paskiem narzędzi: „‹kryteria› → ‹waga›” + ×; na końcu „+ Reguła”.
- Edycja chipa w małym oknie (`Panel`) zakotwiczonym przy chipie: kryteria + przełącznik „wszystkie / dowolne” + waga.
- Kryteria: ulubione; typ peta (wiele); poziom (`=`, `≥`, `>`, `≤`, `<` + liczba 1–25).
- Pety, które mają wagę wyłącznie z reguły, mają w siatce znaczek „auto”; dymek wymienia regułę.
- Semantyka bez zmian: waga z każdej pasującej reguły dodaje się do wagi ręcznej (pet może wystąpić w tablicy losowania wiele razy).
- Stare filtry: płaskie AND/OR jednego poziomu → chip z „wszystkie”/„dowolne”. Głębsze drzewa → chip „Reguła złożona (poprzednia wersja)” z podglądem w dymku i akcją „Uprość”, aktywną tylko gdy `AutoRules.Simplify` zwraca wynik o identycznym znaczeniu. Taki chip nadal działa.

### 4.3 Siatka petów

- `ScrollBox` z widokiem siatki (`CreateScrollBoxListGridView`), `MinimalScrollBar`, fabryka elementów w Lua, wirtualizacja.
- Liczba kolumn = `floor(szerokość siatki / 200)`, min. 1.
- Kafelek: ikona z ramką w kolorze rzadkości, nazwa gatunku, w drugiej linii własna nazwa · poziom · ikona typu; znaczek wagi w rogu (`+2`, `+1`, `-1`, `-2`, `auto`, `Nigdy`; brak znaczka dla „Normalna”). „Nigdy” = kafelek przygaszony.
- Długie nazwy ucinane „…”, pełna nazwa w dymku.
- Klik: Normalna ↔ Nigdy (każda inna waga → Nigdy). PPM lub Ctrl+klik: menu 6 wag + „Przywołaj teraz” + „Ulubiony” (`C_PetJournal.SetFavorite`).
- Pety oczekujące na rozpakowanie (fanfare) nie są pokazywane.
- Puste stany: brak petów → „Nie masz jeszcze żadnych petów” + przycisk otwierający Dziennik Petów; brak wyników → „Brak petów pasujących do «…»” + „Wyczyść filtry”.

### 4.4 Panel podglądu (prawy)

- Szerokość ~240 px. Pokazuje peta pod kursorem; bez najechania — ostatnio kliknięty; bez wyboru — obecnie przywołany.
- Model 3D (obecny `ModelPreview`): obrót przeciąganiem, zoom kółkiem, powolny obrót w bezczynności; lista wyjątków statycznych zachowana. Gdy model się nie wczyta — duża ikona.
- Nazwa gatunku, własna nazwa, poziom, rzadkość (kolor), typ, źródło zdobycia (z danych gatunku).
- Suwak wagi 6-stopniowy („Nigdy … Bardzo często”).
- „Szansa w tym zestawie: 3,2%” (`set:GetChance`) + dopisek, jeśli pet teraz nie może być przywołany (odnowienie, nieprzywoływalny).
- Przyciski „Przywołaj” i ☆.
- Gdy okno ma < 760 px szerokości, panel się chowa, a podgląd pokazuje się jako dymek przy kafelku (zachowanie jak w 1.0.x).

## 5. Zakładka Kiedy (edytor warunków)

### 5.1 Model

- Zestaw jest aktywny, gdy **którakolwiek grupa** jest spełniona; grupa jest spełniona, gdy **wszystkie jej warunki** są spełnione.
- Domyślnie istnieje jedna grupa i nie widać żadnych oznaczeń grup. Link „+ Albo inny zestaw warunków” dodaje kolejną kartę, oddzieloną napisem **LUB**. Usunięcie przedostatniej grupy wraca do widoku jednej grupy.
- Zestaw bez warunków jest aktywny zawsze (zachowanie 1.0.x) — edytor pokazuje to wprost: „Bez warunków ten zestaw jest aktywny zawsze”.

### 5.2 Wiersz warunku

- Kropka na żywo: ● spełniony / ○ niespełniony; dymek z powodem („Jesteś w: Valdrakken”).
- Typ (tekst), operator słowny, kontrolki wartości wg schematu typu, przełącznik [nie], ×.
- Każda zmiana zapisuje się od razu i działa bez `/reload`.
- Nagłówek karty pokazuje stan całego zestawu („● aktywny” / „○ nieaktywny”).

### 5.3 Typy warunków

| Typ | Wartości | Uwagi |
|---|---|---|
| Miejsce | wiele stref/podstref; „+ obecne” | nowe wpisy zapisują `mapID` (niezależne od języka); stare wpisy po nazwie (`zoneName`) działają nadal |
| Typ miejsca | miasto/odpoczynek, loch, raid, scenariusz, delve, BG/arena, otwarty świat (wiele) | rozszerza `specialLocation` |
| Grupa | solo, drużyna, raid (wiele) | naprawia ignorowanie ustawień Party/Raid |
| Postać | klasa (lub Dowolna), specjalizacja (lub Dowolna), opcjonalnie nazwa postaci | „Dowolna” klasa działa (naprawa) |
| Pora dnia | przedział godzin czasu serwera (może przechodzić przez północ) | nowy |
| Zaawansowane: warunek makra | tekst warunku makra | przykłady pod polem; sprawdzanie przez wspólny ticker |
| Zaawansowane: kod Lua | edytor wielowierszowy | „Sprawdź” kompiluje i pokazuje wynik lub błąd; kod z importu wyłączony do akceptacji (czerwony pasek „Przejrzyj i włącz”) |

Menu „+ Dodaj warunek” grupuje typy: Miejsce, Grupa i postać, Czas, Zaawansowane.

### 5.4 Szablony

Pusty zestaw (oprócz domyślnego) pokazuje szablony jednym kliknięciem: „W mieście”, „W raidzie lub lochu”, „Tutaj (obecne miejsce)”, „Na obecnej specjalizacji”, „W grupie”.

### 5.5 Zgodność ze starymi regułami

- `Conditions.ToModel` zamienia zapis `trigger` na model: lista najwyższego poziomu = jedna grupa; `OR` tego samego typu → jeden wiersz z wieloma wartościami; `OR` z `AND`-ami → grupy.
- Drzewa, których nie da się wyrazić modelem (głębokość > 2 lub mieszanki), są pokazywane jako blok „Reguła złożona (poprzednia wersja)” z czytelnym opisem (`Describe`) i akcją „Uprość” (aktywną tylko gdy `Conditions.Simplify` daje model o identycznym znaczeniu). Blok nadal działa i można go usunąć.
- Zapis zostaje w polu `trigger`; rozszerzenia są addytywne (listy wartości, `negate`, `mapIDs`, przedziały godzin). Brak osobnej migracji danych.

### 5.6 Poza zakresem

Warunki świąt/wydarzeń (API kalendarza wymaga otwierania kalendarza i bywa zawodne) — możliwy dodatek w przyszłości.

## 6. Zakładka Ustawienia zestawu

- Włączony (przełącznik), Priorytet (lista 5 poziomów jak w 1.0.x: Extra Low … Extra High), „Przywołaj natychmiast po aktywacji” (`immediate`) z opisem.
- Nazwa (pole + „Zmień”; walidacja jak przy tworzeniu), „Eksportuj”, „Usuń zestaw” (potwierdzenie).
- Zestaw domyślny: tylko Eksportuj (nie da się go wyłączyć, przemianować ani usunąć).

## 7. Eksport i import

- Eksport: okno z polem tekstowym, cały tekst zaznaczony, „Ctrl+C, aby skopiować”. Nowy format przez `C_EncodingUtil` (CBOR → kompresja → Base64) z prefiksem `PetCall:2:`; pety jako `speciesID` (jak w 1.0.10+).
- Import: pole na tekst + nazwa zestawu + „Importuj”. Akceptuje `PetCall:2:` i stary `PetCall:1:` (AceSerializer — dekoder starego formatu w rdzeniu). Sanityzacja: nieznane typy warunków/reguł usuwane; kod Lua wyłączony do akceptacji (komunikat w oknie po imporcie). Błędy pokazywane w oknie, okno zostaje otwarte.

## 8. Minimapa, LDB, menu PPM

- Obiekt LDB typu źródło danych: tekst „‹nazwa peta›” (lub „PetCall”), ikona przygaszona przy wyłączonym auto-przywoływaniu.
- Tooltip: Auto WŁ/WYŁ, aktywny zestaw, pet, „Wstrzymane przez: …”, liczba petów, podpowiedzi klawiszy.
- Kliknięcia (przycisk minimapy LibDBIcon, Addon Compartment, paski LDB — identycznie): LPM przełącz peta/auto-przywoływanie (jak 1.0.x), PPM menu, Ctrl+klik okno PetCall.
- Menu PPM (MenuUtil) zastępuje obecny panel dwukolumnowy:
  - nagłówek „PetCall”, „Przywołaj inny”, „Odwołaj peta”, ✓ „Auto-przywoływanie”,
  - „Aktywny: ‹zestaw›” (informacja),
  - „Ostatnio przywołane ▸” (5 ostatnich, zapis na konto),
  - „Wszystkie pety ▸” → podmenu stron alfabetycznych (~25 petów/strona, etykieta zakresu jak w 1.0.x), przewijane, z ikonami,
  - „Otwórz PetCall”, „Ustawienia”.
  - Najechanie na peta pokazuje podgląd 3D obok menu.
- Przycisk minimapy domyślnie ukryty (jak 1.0.x), opcja w Ustawieniach.

## 9. Skróty klawiszowe i komendy

- Skróty bez zmian nazw: `PETCALL_SUMMON`, `PETCALL_DESUMMON`, `PETCALL_TOGGLE`, `PETCALL_CONFIG` (otwiera okno PetCall).
- `/pcall`, `/petcall` bez argumentu → okno. Podkomendy 1.0.x działają bez zmian: `config`, `resummon`, `dismiss`, `desummon`, `togglePet`, `enable`, `dismissWhenStealthed`, `debugstate`, `migrate`. Nowe: `settings`, `help`.

## 10. Panel Ustawień (natywny)

Kategoria „PetCall” (układ pionowy, `Settings.RegisterVerticalLayoutCategory`, ustawienia przez proxy do DB PetCall). Na górze przycisk „Otwórz okno PetCall”.

- **Ogólne:** Auto-przywoływanie; Tylko po zmianie strefy; Czas oczekiwania (1–30 s, krok 0,5); Komunikaty na czacie; Przycisk minimapy; Nadpisuj loadout walk petów; Skala okna PetCall (80–130%).
- **Gdzie:** BG/arena: Przywołuj / Nie przywołuj / Odwołuj; Lochy i raidy: Przywołuj / Nie przywołuj / Odwołuj (każda lista zapisuje się w parze pól `enableIn…`/`dismissIn…`); Tylko w miastach; Odwołuj w ukryciu/niewidzialności.
- **Automatyczna zmiana peta:** Włączona; Co ile (1–60 min); Tylko w miastach; Przy zmianie mapy.
- **Przedmioty specjalne:** Włączone; lista przełączników z nazwami przedmiotów/questów (nazwy z API, z pamięcią podręczną).
- **Podkategoria „Profile”** (canvas): bieżący profil (lista), nowy, kopiuj z, resetuj, usuń (potwierdzenie). Format `profileKeys`/`profiles` zgodny z 1.0.x.
- **Podkategoria „O dodatku”** (canvas; układ pionowy Ustawień nie ma elementu z dowolnym tekstem): wersja PetCall, wersja gry i Interface (z `GetBuildInfo`), nowości z bieżącej wersji (`ReleaseNotes`), lista komend, skróty klawiszowe z przypisanymi klawiszami, autorzy.
- Otwarcie panelu w walce: komunikat „Otworzę po walce” i otwarcie po `PLAYER_REGEN_ENABLED`.

## 11. Wygląd, EllesmereUI, skalowanie, tłumaczenia

- Wyłącznie elementy Blizzarda: `ButtonFrameTemplate`, `InsetFrameTemplate`, zakładki Blizzarda, `SearchBoxTemplate`, `WowStyle1DropdownTemplate`, suwak ze strzałkami, `MinimalScrollBar`, `GameFont*`, atlasy z Dziennika Kolekcji.
- Animacje: zanikanie przy otwarciu okna (0,15 s), podświetlenie kafelka, krótki błysk znaczka przy zmianie wagi.
- **EllesmereUI** (`## OptionalDeps: EllesmereUI`): `EllesmereUI.RegisterSkin("PetCall", fn)`; `fn` zapamiętuje `S` i skórkuje elementy statyczne (`S.Shell`, `S.Inset`, `S.Panel` dla podglądu, `S.Tab` + `S.SetTabSelection` gdy `S.apiVersion >= 2`, `S.EditBox`, `S.Button`, `S.Dropdown`, `S.Checkbox`, `S.ScrollBar`, `S.CloseButton`); elementy tworzone później (kafelki, wiersze, chipy) skórkowane w fabryce przez zapamiętane `S` (`S.SquareIcon`, `S.Button`). Własne kolory biorą akcent z `S.GetAccentColor()` i odświeżają się przez `S.OnLooksChanged`. Bez EllesmereUI wszystko działa identycznie.
- **Skalowanie:** okno dziedziczy skalę interfejsu gry × „Skala okna PetCall”. Progi układu: < 760 px — podgląd jako dymek; < 700 px — panel zestawów zwinięty. Sprawdzane: 1080p, 1440p, 4K, ultrawide; skala interfejsu 0,65–1,15.
- **Tłumaczenia:** każdy tekst przez `L[...]`, `enUS` wzorcem, pozostałe języki z CurseForge przy wydaniu. Przyciski i etykiety dopasowują szerokość do tekstu (z minimalną szerokością). Nazwy stref, klas, specjalizacji, typów petów — z API gry.
- **Czytelność:** stan nie jest przekazywany samym kolorem (kształty ●○◌, tekst w znaczkach, opisy w dymkach).
- **Wydajność:** zero `OnUpdate`, gdy okno jest ukryte; obrót modelu tylko przy widocznym podglądzie; siatka przebudowywana tylko po callbacku rdzenia; wyszukiwanie na przygotowanych kluczach.

## 12. Struktura kodu UI

| Plik | Rola |
|---|---|
| `UI/Widgets.lua` | fabryka elementów nad szablonami Blizzarda (przycisk, przełącznik, lista, suwak, chip, pole); każdy element rejestruje się w `UI/Skin.lua` |
| `UI/MainWindow.lua` | ramka, zakładki, rozmiar/pozycja/skala, progi responsywne |
| `UI/SetList.lua` | panel zestawów |
| `UI/PetsTab.lua` | pasek narzędzi, reguły automatyczne, siatka |
| `UI/PetPreview.lua` | panel podglądu (używa `ModelPreview`) |
| `UI/WhenTab.lua` | edytor warunków, szablony, blok reguły złożonej |
| `UI/SetSettingsTab.lua` | ustawienia zestawu |
| `UI/StatusBar.lua` | pasek stanu |
| `UI/ShareDialog.lua` | okna eksportu/importu |
| `UI/Broker.lua`, `UI/Menu.lua` | LDB, LibDBIcon, Addon Compartment, menu PPM |
| `UI/Settings.lua`, `UI/Profiles.lua` | natywny panel Ustawień, podkategoria Profile |
| `UI/Skin.lua` | integracja z EllesmereUI |

**Samoopisujące się typy:** każdy typ warunku (`Core/Conditions.lua`) i kryterium reguły automatycznej (`Core/AutoRules.lua`) deklaruje `fields` (schemat: `multiMap`, `choice`, `multiChoice`, `timeRange`, `text`, `code`, `number`, `operator`), `Describe(settings)` i `Check(settings)`. `UI/WhenTab.lua` i edytor chipów rysują kontrolki wyłącznie ze schematu; UI nie zawiera kodu specyficznego dla typów.

## 13. Kontrakt rdzeń ↔ UI

Rozszerza kontrakt z planu nadrzędnego. UI nie zapisuje bezpośrednio do `db`.

| API | Zwraca / działanie |
|---|---|
| `Sets:List()`, `Sets:Get(name)`, `Sets:Create(name)` → `set, ok, err` | |
| `set:Rename(name)` → `ok, err`; `set:Delete()` | |
| `set:SetEnabled(b)`, `SetPriority(w)`, `SetImmediate(b)`, `SetDefaultWeight(w)` | |
| `set:GetPetWeight(petID)`, `SetPetWeight(petID, w)`, `SetPetWeights(petIDs, w)`, `ClearPetWeights()` | |
| `set:GetChance(petID)` → `0..1`, `reason?` | |
| `set:GetAutoRules()` → lista chipów lub `{legacy = tree}`; `set:SetAutoRules(rules)` | |
| `set:GetConditionModel()` → `{groups = {{rows}}}` lub `{legacy = tree}`; `set:SetConditionModel(model)` | |
| `set:GetConditionStates()` → `{[rowRef] = {value, reason}}` | |
| `set:IsActive()`, `set:GetStatus()` → `"active"|"waiting"|"empty"|"noConditions"|"disabled"` | |
| `Conditions.Types()`, `AutoRules.Types()` → typy ze schematami | |
| `Conditions.ToModel(tree)`, `FromModel(model)`, `Simplify(tree)` | |
| `Sets:GetCurrent()`, `Ready:GetBlockers()` → `{ {key, label, detail} }` | |
| `addon:SummonAnother()`, `addon:Dismiss()`, `addon:SetAutoSummon(b)`, `addon:SummonPet(petID)` | |
| `addon:GetRecentPets()` → max 5 | |
| `Share:Export(name)` → `str`; `Share:Import(str, name)` → `ok, name, info` | |
| `Profiles:List()`, `Current()`, `Set(name)`, `Copy(from)`, `Reset()`, `Delete(name)` | |
| Callbacki: `SetsChanged(name?)`, `CurrentSetChanged`, `PetsChanged`, `ReadyChanged`, `ProfileChanged`, `ConditionStateChanged(name)` | |

Wszystkie funkcje modyfikujące zwracają `ok, err`; `err` jest przetłumaczonym tekstem do pokazania graczowi.

## 14. Obsługa błędów

- UI pokazuje `err` przy polu albo w `UIErrorsFrame`; nigdy nie propaguje wyjątku.
- Kod Lua w warunku: kompilacja i wykonanie w `pcall`; błąd przy polu, raportowany raz na wersję kodu.
- Brak danych peta → kafelek „Wczytywanie…” odświeżany po `PetsChanged`. Model 3D niewczytany → ikona.
- Akcje niedozwolone w walce (otwarcie Ustawień) → odłożone do `PLAYER_REGEN_ENABLED` z komunikatem.

## 15. Testy

- **busted (CI):** zestawy, wagi i szanse; każdy typ warunku z [nie] i wieloma wartościami; grupy; `ToModel`/`FromModel` na przykładach z 1.0.x (w tym głębokie drzewa) z kontrolą równoważności wyniku `Check`; `Simplify`; reguły automatyczne vs stare filtry (identyczne tablice wag); profile na prawdziwym zapisie z 1.0.13; eksport/import (`PetCall:1:` i `PetCall:2:`), sanityzacja; filtrowanie i sortowanie siatki (czyste funkcje); mapowanie list 3-stanowych na pary pól.
- **luacheck (CI).**
- **W grze:** lista kontrolna z planu nadrzędnego + rozdzielczości i skale z §11, klient deDE, z i bez EllesmereUI, ~1500 petów, konto bez petów, walka (otwieranie okna, Ustawień), import starego stringa.

## 16. Pokrycie funkcji 1.0.x

| Funkcja 1.0.x | Gdzie w 2.0 |
|---|---|
| Auto-przywoływanie (enable) | pasek stanu, Ustawienia › Ogólne, LPM minimapy, menu PPM |
| Tylko po zmianie strefy, czas oczekiwania, komunikaty | Ustawienia › Ogólne |
| BG/arena i PvE: włącz/odwołuj | Ustawienia › Gdzie (listy 3-stanowe) |
| Tylko w miastach, odwołuj w ukryciu | Ustawienia › Gdzie |
| Nadpisywanie loadoutu walk | Ustawienia › Ogólne |
| Auto-zmiana: timer, tylko miasta, zmiana mapy | Ustawienia › Automatyczna zmiana peta |
| Przycisk minimapy | Ustawienia › Ogólne |
| Przedmioty specjalne | Ustawienia › Przedmioty specjalne |
| Profile (AceDBOptions) | Ustawienia › Profile |
| Wybór petów i 6 wag, waga domyślna, reset | zakładka Pety |
| Filtry (poziom, ulubione, typ, AND/OR, priorytet) | reguły automatyczne |
| Zestawy: tworzenie, nazwa, usuwanie, włączanie, priorytet, immediate | panel Zestawy, Ustawienia zestawu |
| Triggery: zone, specialLocation, groupType, macro, specialization, luacode, AND/OR | zakładka Kiedy (typy + grupy + Zaawansowane + blok reguły złożonej) |
| Import/eksport | panel Zestawy, Ustawienia zestawu, okna ShareDialog |
| Migracja z PetLeash | bez zmian (popup przy logowaniu, `/pcall migrate`) |
| Podgląd 3D | panel podglądu, dymek przy wąskim oknie, menu PPM |
| Menu PPM z petami | menu MenuUtil |
| Tooltip LDB | tooltip LDB (+ powody wstrzymania) |
| Komendy i skróty | §9 |
| Panel About | Ustawienia › O dodatku (podkategoria) |
| `/pcall debugstate` | bez zmian |
