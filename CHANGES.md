
Changelog
=========

1.0.1 (2026-02-24)
------------------

- Change slash command alias from /pl (PetLeash legacy) to /pcall.
- Performance: fix pet weight table being rebuilt on every summon attempt instead of only when dirty.
- Performance: combine filter iteration into a single pass over the pet journal (was N+1 passes).
- Performance: reduce FrequentCheck polling timer from 10 Hz to 2 Hz.
- Performance: detect flying state via PLAYER_MOUNT_DISPLAY_CHANGED event instead of polling.
- Performance: cache pet names before sort in broker panel (was O(N log N) API calls, now O(N)).
- Performance: extract static OnLeave handler in broker panel to avoid per-row closure allocation.
- Performance: eliminate closure allocation in macro trigger timer.
- Fix 3D preview orbit for pets with off-center skeleton root (e.g. Murkastrasza) via per-creature static preview list.
- Add hover tooltips to all General and Auto Switch tab options for clarity.
- Clean up locale file: remove legacy keys, remove duplicate entries, sort alphabetically.
- Clean up code comments: replace empty separators with descriptive section headers; update stale XXX notes.

1.0.0 (2026-02-24)
------------------

- Renamed to PetCall; based on PetLeash 3.1.5 by End (abandoned 2018).
- Full compatibility update for WoW 12.0 (Midnight).
- Fix options panel not appearing in the AddOns list on login.
- Fix broker minimap button right-click pet menu.
- Fix broker minimap button tooltip not updating after left-click.
- Add 3D pet model preview on hover in Pet Selection settings.
- Replace broker right-click context menu with a custom panel showing alphabetical pages and 3D pet model preview on hover.
- Fix pet selection filter showing wrong pets when switching between Selected/Unselected modes; add All option.
- Fix addon attempting to summon a pet while sitting on furniture or a bench.
- Fix readiness checks breaking when entering combat.
- Fix pet triggers not updating when resting state changes.
- Improve Pet Triggers UX: empty-state guidance, per-set trigger/pet summary, help text on Triggers/Filters tabs, Priority and Immediate explanations, (And)/(Or) descriptions, and visible error message on invalid set name.
- Add About panel refactor credits.
- Update all embedded libraries to current versions.

3.1.5 (2018-07-18)
------------------

- Fix readiness checks to work with 8.0 client patch.
- Fix food triggered sitting readiness check.

3.1.4 (2017-09-05)
------------------

- Fix pet selection to work with 7.3 client patch.

3.1.3 (2017-03-29)
------------------

- Fix options screen creation to not break with 7.2 client patch.

3.1.2 (2016-11-26)
------------------

- Allow setting of class in the Class Specialization trigger.  Only
  checking specialization and not class was confusing when the profile
  was not set to be specific to class.

3.1.1
-----

- Don't overflow scroll frame for pet triggers.
- Don't disable ready for haunted momento.
- Update localizations (deDE)

3.1
---

- Provide the DataBroker plugin as a minimap button, which is disabled
  by default.
- DataBroker plugin display tweaks.
- Add currently disabled/enabled search filter for pet selection
- Add class specialization trigger.
- Detect going afk or eating food as the sitting state, which lasts
  until the player moves.

3.0.17
------

- Update localizations (deDE)

3.0.16
------

- Add support for 7.0 client:
    - Update summonable pets to check for "needs fanfare", which seems
      to be a pet unwrapping animation.
    - Update readiness checks for changed spell ids.

3.0.15
------

- Fix luacode example trigger.
- Fix luacode trigger handling.
- Don't dismiss pets when going into stealth.  Pets now stealth with
  the player.
- Add another Nagrand quest for checking readiness.

3.0.14
------

- Update localizations (ruRU)

3.0.13
------

- Update localizations

3.0.12
------

- Default to enabled in PVE instances.

3.0.11
------

- Add enabled/dismiss option for PVE instances.

3.0.10
------

- Add tooltip to pet selection, to help distinguish between different
  pets with the same species.
- Make pet selection sorting consistent.

3.0.9
-----

- Update spell ids for eating readiness check.
- Don't try to dismiss a pet while flying.
- Allow summoning pets while mounted.

3.0.8
-----

- Be more chatty when summoning a pet, to help users detect problems
  with readiness checks.
- Update spell ids for eating readiness check.


3.0.7
-----

- Minor bugfixes.

3.0.6
-----

- Dismiss pets when in Camouflage and Feign Death, as they no longer
  break when a pet is dismissed.

3.0.5
-----

- Disable readiness when the Oshu'gun quest is active.  It is doing
  something weird with pets.

3.0.4
-----

- When in autoswitch mode, don't try to summon a pet if we get extra
  zoning events.

3.0.3
-----

- Minor option bugfixes.

3.0.2
-----

- Fix search box "Search" string handling.

3.0.1
-----

- Update spell ids for camouflage readiness check.

3.0
---

- Add new triggers and filters functionality to dynamically select
  pets or conditions to summon pets on.
- The pet selection screen has been rewritten to more easily search
  for pets and for improved performance.
- Update spell ids for camouflage readiness check.
