# PetCall 2.0 — main window polish

Approved in chat on 2026-10-16 from an annotated mockup ("ok działaj"). Goal: the
window explains what is going on before the player clicks anything — which set is
being edited, when it is used, what it does — and looks finished instead of raw.

## Stage 1 (this change)

1. **Set header** above the tabs: set name (large), a status pill (Active now /
   Conditions not met / No pets to choose from / Always active / Disabled) and one
   plain sentence: "When: <conditions>. PetCall picks one of <N> checked pets."
   For the default set: "Used when no other set is active."
2. **Filters on top**: segmented All / In this set / Left out plus a favorites
   toggle, next to search; sort, pet types and bulk weights stay in the Filter menu.
3. **Auto rules** read "More chance for:" with chips such as "Favorites: Often";
   the add button reads "+ Add".
4. **Count line** above the grid: "<N> in this set · <M> left out".
5. **Tiles**: second line shows the pet type, the weight when it is not Normal and
   the copy count; the include toggle is a small check (ReadyCheck texture, ghosted
   when the pet is left out) instead of the big green checkbox.
6. **Preview**: weight as six labelled buttons in two rows (Never, Very rarely,
   Rarely / Normal, Often, Very often) instead of an unlabelled slider; chance as
   a bar (relative to the most likely pet in the set) with the percentage.
7. **Moved out of the main view** into Set settings: the default weight ("Pets you
   haven't set by hand") and "Reset all weights" (with confirmation).

Weight names change from "Low/High Priority" to how-often wording; set priority
keeps its own names (Lowest … Highest).

## Stage 2 (later)

Set cards with icon and plain-language state in the sets panel; status bar as a
sentence with an auto-summon toggle.

## Constraints

Blizzard templates and textures only (Collections look), EllesmereUI skin still
applies; no new glyphs the game font lacks; all strings through `L[...]`.
