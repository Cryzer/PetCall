
# Changelog

## v1.0.9 (2026-02-25)

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
