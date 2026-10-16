# PetCall 2.0 — ready-made sets ("recipes")

Asked for in chat on 2026-10-16 ("generator gotowych zestawów"). Status: design for
approval; nothing built yet.

## Why

Building a useful set today takes four steps in three tabs: create it, add
conditions in When, decide which pets belong (tick by hand or add "More chance
for" rules), then fix the default weight in Set settings. New players stop at the
Default set; the competition (PetLeash, PetWalker, Auto Pets) offers no help here
at all. Recipes turn the most common wishes into one click and show, before
anything is created, what the set will do and which of the player's own pets it
will use.

## Goals

- From "+ New", the player can pick a recipe or start empty.
- Each recipe card shows: a title, one sentence saying when it is used, how many of
  *the player's* pets match, and four of those pets' icons.
- Creating from a recipe makes an ordinary set: conditions, pet rules and weights
  the player can edit afterwards like any other set. No hidden "recipe mode".
- The pet choice follows the collection: new pets that fit join by themselves
  (rules, not a frozen list of ticks).
- A recipe the player cannot use yet (too few matching pets, or the holiday is
  months away) is still shown, greyed, with the reason, so players learn what
  exists.

## Non-goals

- No online or shared recipe catalogue; recipes ship with the addon.
- No editing of recipes themselves; the player edits the set it produced.
- Recipes never change or delete existing sets.

## Anti-goals (a failure even if it works)

- A recipe that creates a set with zero pets, or one that silently takes over
  everywhere (no conditions).
- A wizard of several screens; one gallery screen plus one confirmation is the
  limit.
- Any new library or Ace3 dependency.

## How it looks

"+ New" (sets panel) opens a small menu: **Empty set** / **From a recipe…**.
"From a recipe…" replaces the tab area of the main window with a gallery
(the sets panel and status bar stay):

```
New set from a recipe                                   [Back]
------------------------------------------------------------------
[img img img img]  Water pets while swimming        34 pets  [Create]
                   When you swim. Aquatic pets.
[img img img img]  Hallow's End                      6 pets  [Create]
                   During Hallow's End. Pets from the event.
[img img img img]  Pets from this zone               varies  [Create]
                   Everywhere. Pets native to the zone you are in.
[grey .... ]       Darkmoon Faire                    0 pets   (greyed)
                   You have no pets from this event yet.
```

Cards sit in one column, sorted: usable first, then greyed. Hovering a card shows
the full list of conditions and rules in a tooltip. **Create** asks for nothing:
the set is named after the recipe (a number is added when the name is taken),
selected, and the window switches to its Pets tab so the player sees the result.

## The first recipes

Each recipe is data: `{ key, title, hint, conditions = {...}, rules = {...},
defaultWeight = Never, priority }`.

| Recipe | Conditions | Pets (rules, weight Normal) |
|---|---|---|
| Water pets while swimming | Activity: Swimming | Pet type: Aquatic |
| Flyers in the open world | Place type: Open world; Activity: Outdoors | Pet type: Flying |
| Holiday: <each holiday in the calendar> | Holiday: <that one> | Source mentions <holiday title> |
| Pets from this zone | none, priority Lowest (acts as a better Default) | Native to where I am |
| At my house | Home: My house or plot | Favorites; Pet type: Critter |
| Dungeons and raids | Place type: Dungeon, Raid | Level 25 and Rare |
| Night owls | Time of day 20:00–06:00 | Pet type: Undead, Magic |
| Favorites while AFK | Activity: AFK | Favorites |
| My class theme | Character: my class | a class-to-pet-types table (Hunter: Beast; Warlock: Undead, Magic; Mage: Elemental, Magic; Death Knight: Undead; Druid: Critter, Beast; Shaman: Elemental; …) |

Holiday recipes are generated: one card per holiday the calendar knows
(`Conditions.KnownHolidays`), so the gallery follows Blizzard's calendar instead of
a list in our code.

## New pet rules this needs

Two "More chance for" rule kinds join Favorites / Pet type / Level:

- **Source mentions <text>**: matches when the species' source text (5th return of
  `C_PetJournal.GetPetInfoBySpeciesID`, colour codes stripped) contains the text,
  ignoring case. Used for holiday pets; also useful by hand ("Vendor",
  "Darkmoon").
- **Native to where I am**: matches when the source text lists the current zone
  (`GetZoneText()`). The set's weight table must be rebuilt on zone change for this
  rule only (mark the set dirty on `ZONE_CHANGED_NEW_AREA` when it has the rule).

Rare (quality) is needed for "Dungeons and raids"; add it as a third new kind,
**Quality at least <Common/Uncommon/Rare>**, unless the builder finds it simpler to
fold into Level.

## Counting pets for the cards

A card's count is the number of pets (one per tile, copies grouped as in the grid)
whose weight in the would-be set is above zero. Compute it by building the weight
table for a throw-away settings table (`Weights.Build` already takes plain
settings), never by creating the set first.

## Decided in chat

- Generator = ready-made sets the player picks from (this document).
- Icons, cards and one-click Create follow the proposal the player approved.

## Calls I made (check these)

- Cards in one column rather than a grid: the text explains the recipe, and it
  stays readable at the smallest window size.
- Greyed recipes stay visible with a reason instead of being hidden — except
  holiday cards with no matching pet: the calendar also lists weekly events
  (Timewalking, bonus events, brawls) that would fill the gallery with grey cards.
- No confirmation dialog on Create; the set is easy to delete and lands selected.
- Recipe sets use rules, not ticks, so the collection keeps them current.
- "Pets from this zone" has no conditions and the lowest priority, so it acts as a
  smarter Default without replacing it.

## Left to the builder

- Exact card layout, sizes and the four-icon strip.
- Where the recipe table lives (suggested `Core/Recipes.lua`, UI in
  `UI/RecipeGallery.lua`).
- Whether the set header and the empty-set banner count rule-only pets as "in this
  set" (they must; check `SetHeader.Counts` and `PetGridModel.Filter` with a set
  whose pets come only from rules).
- Localised source texts: holiday matching uses the calendar's localised title
  against the localised source text; verify in game on enUS and note other
  locales as a known risk.

## Tests that must exist

- Every recipe produces a set with at least one condition or the Lowest priority,
  and no recipe produces a set while showing 0 pets.
- Card counts equal the pets the created set really draws from.
- Holiday cards appear for every holiday the calendar stub returns.
- "Native to where I am" changes its pets after a zone change.
- A taken name gets a number; existing sets are untouched.
