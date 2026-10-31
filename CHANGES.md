
# Changelog

## Unreleased

### New

- **How PetCall acts.** A row above your sets opens one page for everything PetCall does by itself: Auto-summon, when a pet comes out, a new pet on a new map, what happens after a pet battle, the exceptions and pet-like items. The AddOns panel keeps only the look.
- **Exceptions** keep the pet away in some places: Battlegrounds, Arenas, Dungeons, Raids, Scenarios and delves, While mounted, Stealth or invisibility and Outside cities. Each one is As usual, Leave the pet alone or Put the pet away. Add exception makes your own from the same conditions as sets.
- **Also when solo** on Dungeons, Raids, and Scenarios and delves. Clear it and the exception fits only in a party or raid group.
- **Because:** on the Out now card says why no pet comes out, with a button where one helps. With a pet out, the card counts down to the next new pet by the second, and says "your pick" for a pet you chose yourself.
- **New pet every** can be 1 minute.
- **Use recommended settings** shows your settings beside the recommended ones first. Undo puts yours back.
- Battleground and Arena are separate place types. A new Hidden condition covers stealth, invisibility, camouflage and feign death.
- A welcome screen after the update shows what moved. /pcall welcome opens it again.

### Changed

- Key presses and commands pause Auto-summon instead of switching it off. Dismissing your pet, also outside PetCall, pauses it until you change zone; summoning one ends the pause. Only the check box and /pcall enable turn it off.
- Your own actions go past exceptions: a key press summons in a battleground too, and the chat says which exception it went past.
- A pet that an exception, stealth, death or a pet battle took away comes back when that ends, also with Only after a loading screen.
- Picking a pet in the grid, the preview or the menu waits for the game (combat, flying, sitting…) like every other summon.
- A pet you picked yourself stays when a set starts. The set's timer and a new map still replace it.
- The Quiet raid nights, Quiet in dungeons and Quiet in PvP templates are gone: the exceptions do their job. A set with "No pet while this set is used" becomes an exception, also when you import one.
- A "no pet" set that had sets with pets above it becomes an exception with an "and not" condition, so those sets still win where both fit. It shows as a Complex rule you can't edit; replace it with your own conditions when you like.
- Sets show "Like Default" with its value instead of "Like the settings". New pet every and Message on summon live on the Default set.
- PetCall waits during a pet battle, notices /sit and /stand, and tries to hide the red error when its own try finds you sitting.
- Your old settings move into the PetCall window once and keep doing what they did.

### Fixed

- Summon Another Pet and the other keys no longer wait on settings such as Only Summon After Zoning, mounted, cities or "Don't summon" in battlegrounds and dungeons.
- A pet picked in the grid no longer skips the checks that Summon another waits for.
- Only Summon After Zoning no longer holds back the switch timer and bringing your pet back after a pet battle.
- Summon another with Auto-summon off no longer says it waits for Auto-summon and then summons anyway.
- Only Enable in Cities promised to dismiss your pet outside cities but didn't. The Outside cities exception does what its choice says.
- The dungeons and raids setting follows the place live, also when you join a group inside an instance, not only after a loading screen.
- A set's own switch timer no longer stops outside cities without saying so: "only in cities" is now part of its New pet every.
- A dismissal that falls in combat now happens after combat.
- A pet you dismiss yourself outside PetCall no longer comes back after a few seconds.

### Translations

- Every new text is translated into all ten languages.

## v2.2.0 (2026-10-29)

### New

- **Rules.** Filter the pet list by type, source, level, rarity, zone or expansion, then click Make a rule and pick how often those pets come out. Pets you collect later follow the rule too. The Rules button lists a set's rules, so you can open and change them.
- **Leave one pet out of a rule:** untick it. Tick it again to give it back to the rule.
- **Pets by expansion.** Filter the list by the expansion a pet came with. The new template Pets from this expansion picks pets from the expansion of the zone you are in.
- **Six new templates:** Caught in the wild, Hard-earned trophies, Collector's shelf, Workshop crew, Quiet in dungeons and Daylight wanderers.
- **How often is a slider** in the pet preview, from Never to Very often.

### Changed

- Clicking the pet that is out jumps to it in the pet list.
- Rules about where you are show the place, for example "From this zone (Silvermoon City)".
- A pet's own setting now beats its rules, and a pet picked by two rules follows the stronger one. Before, they were added up, so in sets with rules some pets may come out more or less often than before.
- The time-of-day templates cover the whole day without overlapping (server time): Morning critters 06–10, Daylight wanderers 10–18, Elemental dusk 18–20, Night owls 20–02, Witching hour 02–06. Sets you already made keep their hours.
- Clearer wording: a set without conditions says it is used everywhere, "Left out" only marks pets you took out yourself, and the chance bar matches the percentage next to it.
- Smoother: PetCall does less work in the background.

### Fixed

- Only Summon After Zoning also works when you walk into a new zone, not only after a loading screen.
- No text is cut off any more, in any language.
- The + New and Import buttons sit right under the set list.
- The + New, import and export windows are easier to see on the dark looks.
- The pet preview no longer jumps when you move from pet to pet.

### Translations

- Every text is translated into all ten languages, including the old 1.x options and the updated help.

### For translators

- /pcall pseudo makes every text longer, as a translation would, to check that the window still fits. Type it again to turn it off.

## v2.1.1 (2026-10-18)

### Fixed

- No more Lua error in Ready.lua when the game hides your AFK or resting state from addons (for example in combat or in an instance). PetCall now waits until it can read them again.

## v2.1.0 (2026-10-18)

### New

- An Outfit condition under "Who I play as": a set can follow the transmog outfit you wear, for example undead pets while you wear your "Necromancer" outfit. Outfits are chosen by name, so the set works on every character with an outfit of that name and keeps its outfits when you share it.

## v2.0.3 (2026-10-18)

### Fixed

- The window can no longer grow past the screen, at any window scale, so its resize corner stays where you can grab it. A window that was already too big or off the screen comes back to the middle.
- The minimap button is shown by default, so resetting a profile no longer hides it. If you reset a profile on 2.0.2, turn it back on in Options: "Show Minimap Button".
- The pet preview keeps its shape in a tall window, so the pet no longer looks small or jumps back after it loads.

## v2.0.2 (2026-10-18)

### Fixed

- The text under the pet preview no longer runs into the How often buttons and the Summon button: the controls keep their place at the bottom and the "where it comes from" lines are cut to the room left (all of it shows when you point at them).
- Blank lines in Blizzard's "where it comes from" text are gone, so there is no big gap under the pet's name.

## v2.0.1 (2026-10-18)

### Fixed

- Many pet rules no longer run out of the window: the rule chips wrap onto more lines and the pet grid moves down under them.
- The pet count ("409 in this set · 130 left out") moved to the toolbar line, so the rule chips no longer cover it.
- A "where a pet comes from" rule with no text yet says so instead of showing "Source: :".
- The About page in the Options panel scrolls, so nothing below the commands is cut off.

## v2.0.0 (2026-10-17)

PetCall 2.0 is a complete rebuild. You collected hundreds of pets; now you get to see them. Sets that know when to show up, a pet that fits the moment, and a window that explains itself. Your PetCall 1.x and PetLeash sets come along as they are.

### Highlights

- A brand-new window (/pcall): your sets on the left, the chosen set on the right, and a status bar along the bottom that always says what PetCall is doing.
- Sets that know when to show up: water pets while you swim, flyers in the open world, rare pets in cities, your favorites at home.
- Conditions that read like sentences, with a live dot that shows what is true right now.
- Many new conditions: several places at once, place types (city, dungeon, raid, delve, battleground, open world), your house, swimming or AFK, solo, party or raid, one character by name, time of day and holidays.
- Match your pet to your mount: pick mounts from your collection in a window with search, filters and a 3D preview.
- Or-groups: "+ Or another set of conditions" for a set that should also be used somewhere else.
- 29 ready-made templates in groups you can filter and search, plus one for each pet family and pet source, your class and each holiday. One click and the set is yours to change.
- Decide how often each pet comes out, from Never to Very often, or let rules do it for whole groups: favorites, a pet type, a level, rare quality, where a pet comes from, or pets native to where you are. Pets you collect later follow the rules too.
- A fast pet grid for even the biggest collections, and a 3D preview with the exact chance a pet comes out next.
- No more guessing: the status bar at the bottom of the window and the minimap button's tooltip say why no pet is out, for example "Paused by: In combat".
- Built-in help: click the "i" and every part of the window explains itself.

### Also new

- A pet menu on the minimap button: summon another, your recently summoned pets, or any pet from alphabetical pages with a 3D preview. Also in the Addon Compartment.
- Settings in the game's own Options panel, with profiles, a What's new page and a window scale slider.
- Choose the look: Blizzard's frames, PetCall dark, or your EllesmereUI skin. The PetCall block also works in EllesmereUI data bars.
- Shorter text for sharing sets; sets exported from PetCall 1.x still import. Lua code in an imported set stays off until you check it.
- Lighter than ever: no Ace3, events only for your own character, fewer updates in raids and almost no cost while the window is closed.

### Fixed

- Lua code conditions, the Party/Raid group setting being ignored, "Any" class for specializations, renaming a set, changes that needed a /reload, and the Special Items entry for spell 100959.

## v1.0.15 (2026-10-15)

- Fixed a Lua error that could appear when opening the pet list in the PetCall settings.

## v1.0.14 (2026-10-15)

- Updated for WoW 12.1.5 (interface 120105).
- Fixed a Lua error on login in 12.1.5: Special Items now uses the current item API after Blizzard removed the old item functions.
- Fixed a Lua error on login when the game's deprecated-API fallbacks are turned off (AFK message detection).
- Class Specialization trigger now uses the current specialization API.
- Fixed the Special Items entry for spell 100959 never activating.
- The About panel now shows the real game version instead of a fixed one.

## v1.0.13 (2026-03-23)

- Locale files now pull translations automatically from CurseForge at release time via the BigWigs packager.
- Fixed double spaces in two localisation phrase keys that caused duplicate entries on CurseForge.
- Full Simplified Chinese (zhCN) translation — thanks XingDvD!

## v1.0.12 (2026-03-15)

- Updated TOC interface version to 120005.

## v1.0.11 (2026-02-27)

- Fixed the 3D pet preview getting stuck or going blank when quickly moving the mouse between pets — it would sometimes show the wrong pet or show nothing at all until you moved your mouse away and back in.
- The preview now updates live while scrolling with the mouse wheel — whichever pet is under your cursor as you scroll will be shown, no need to wiggle the mouse.
- Fixed the preview frame sometimes appearing empty (visible border but no model) until you moved your mouse out and back in. This affected both the Options pet list and the minimap right-click panel.
- The Options list and minimap panel now share the same preview code, so both behave identically.

## v1.0.10 (2026-02-26)

- Fixed import not selecting any pets when importing a set from another player. Pet GUIDs are account-specific; exports now use species IDs so the importer's matching pets are selected automatically.

## v1.0.9 (2026-02-26)

- Redesigned Pet Triggers layout: sets displayed in a two-column grid with equal-size Edit/Delete/Export buttons side by side.
- Set labels now use a larger, more readable font (GameFontNormal). Sets with zero triggers are highlighted in orange as a reminder.
- Disabled sets are now shown with a gray title and "(disabled)" indicator.
- Delete now asks for confirmation before removing a set.
- Export redesigned: the export string no longer contains the set name. The importer chooses their own name, with duplicate detection.
- Import dialog now auto-closes after a successful import.
- Fixed false "already exists" error when creating a set whose name matched a default wildcard in the database.
- Fixed unicode artifact characters appearing in import error messages.
- Fixed "Okay" button on the import name field triggering an unintended import; button is now hidden.
- Added "Create" button next to the "Add New Set" field; "Okay" button on that field is also hidden.
- Fixed Export button crash (AceSerializer:Serialize returns one value, not two).
- Export dialog now auto-selects all text on open for easy copying.
- Pet selection panel now auto-closes 0.75 seconds after the cursor leaves it.

## v1.0.8 (2026-02-25)

- Added Import/Export for trigger sets. Use the Export button next to any set to get a shareable string, and Import Set to load one from another player.
- Added AceSerializer-3.0 library for reliable set serialization.
- Added Luacheck CI — static analysis runs on every push to main.

## v1.0.7 (2026-02-25)

- Fixed release notes showing full changelog instead of current version only.

## v1.0.6 (2026-02-25)

- Fixed release notes showing full changelog instead of current version only (set markup-type: markdown in .pkgmeta).

## v1.0.5 (2026-02-25)

- Fixed CurseForge build error caused by unsupported localizations key in .pkgmeta.

## v1.0.4 (2026-02-25)

- Fixed CurseForge build error caused by invalid .pkgmeta keys (curse-project-id, wago-project-id moved to TOC headers).
- Fixed CHANGES.md format to use Markdown headers, enabling per-version release notes extraction.

## v1.0.3 (2026-02-25)

- Fixed translation errors in German, Russian, French, Chinese, and Korean locales. Added missing v1.0.2 strings (migration prompts, summoning message) to all locales.
- Now published on CurseForge and Wago.io with community localization support.

## v1.0.2 (2026-02-25)

- Added automatic PetLeash profile migration. On first login with both addons installed, PetCall prompts to import all sets, triggers, and settings from PetLeash. The UI reloads once to apply the data cleanly.
- Added /pcall migrate slash command to trigger the import dialog manually.
- Fixed 3D pet preview not updating when quickly moving the mouse between pets in the pet list and broker panel.

## v1.0.1 (2026-02-24)

- New slash command: /pcall (replaces legacy /pl).
- Improved overall performance and reduced CPU usage during auto-summon checks.
- Faster pet filtering and selection.
- Reduced background polling frequency.
- Improved broker panel responsiveness.
- Fixed 3D preview orbit for certain pets (e.g. Murkastrasza).
- Added hover tooltips across General and Auto Switch settings.
- Various internal optimizations and cleanup.

## v1.0.0 (2026-02-24)

- PetCall: continuation of PetLeash (3.1.5).
- Full compatibility update for WoW 12.0 (Midnight).
- Added 3D pet model preview on hover in Pet Selection.
- Replaced broker right-click menu with a custom pet selection panel with alphabetical pages and 3D preview.
- Fixed options panel not appearing in AddOns list on login.
- Fixed broker minimap right-click pet menu.
- Fixed broker tooltip not updating after left-click.
- Fixed incorrect pets shown when switching Selected / Unselected filters; added All option.
- Fixed addon attempting to summon pets while sitting on furniture.
- Fixed readiness checks breaking in combat.
- Fixed pet triggers not updating when resting state changes.
- Improved Pet Triggers UX (guidance, summaries, help text, clearer explanations).
- Updated embedded libraries.
- Added credits in About panel.

## 3.1.5 (2018-07-18)

- Fix readiness checks to work with 8.0 client patch.
- Fix food triggered sitting readiness check.

## 3.1.4 (2017-09-05)

- Fix pet selection to work with 7.3 client patch.

## 3.1.3 (2017-03-29)

- Fix options screen creation to not break with 7.2 client patch.

## 3.1.2 (2016-11-26)

- Allow setting of class in the Class Specialization trigger.  Only
  checking specialization and not class was confusing when the profile
  was not set to be specific to class.

## 3.1.1

- Don't overflow scroll frame for pet triggers.
- Don't disable ready for haunted momento.
- Update localizations (deDE)

## 3.1

- Provide the DataBroker plugin as a minimap button, which is disabled
  by default.
- DataBroker plugin display tweaks.
- Add currently disabled/enabled search filter for pet selection
- Add class specialization trigger.
- Detect going afk or eating food as the sitting state, which lasts
  until the player moves.

## 3.0.17

- Update localizations (deDE)

## 3.0.16

- Add support for 7.0 client:
    - Update summonable pets to check for "needs fanfare", which seems
      to be a pet unwrapping animation.
    - Update readiness checks for changed spell ids.

## 3.0.15

- Fix luacode example trigger.
- Fix luacode trigger handling.
- Don't dismiss pets when going into stealth.  Pets now stealth with
  the player.
- Add another Nagrand quest for checking readiness.

## 3.0.14

- Update localizations (ruRU)

## 3.0.13

- Update localizations

## 3.0.12

- Default to enabled in PVE instances.

## 3.0.11

- Add enabled/dismiss option for PVE instances.

## 3.0.10

- Add tooltip to pet selection, to help distinguish between different
  pets with the same species.
- Make pet selection sorting consistent.

## 3.0.9

- Update spell ids for eating readiness check.
- Don't try to dismiss a pet while flying.
- Allow summoning pets while mounted.

## 3.0.8

- Be more chatty when summoning a pet, to help users detect problems
  with readiness checks.
- Update spell ids for eating readiness check.

## 3.0.7

- Minor bugfixes.

## 3.0.6

- Dismiss pets when in Camouflage and Feign Death, as they no longer
  break when a pet is dismissed.

## 3.0.5

- Disable readiness when the Oshu'gun quest is active.  It is doing
  something weird with pets.

## 3.0.4

- When in autoswitch mode, don't try to summon a pet if we get extra
  zoning events.

## 3.0.3

- Minor option bugfixes.

## 3.0.2

- Fix search box "Search" string handling.

## 3.0.1

- Update spell ids for camouflage readiness check.

## 3.0

- Add new triggers and filters functionality to dynamically select
  pets or conditions to summon pets on.
- The pet selection screen has been rewritten to more easily search
  for pets and for improved performance.
- Update spell ids for camouflage readiness check.
