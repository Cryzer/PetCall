# PetCall

<p align="center"><img width="400" height="400" alt="PetCall icon" src="https://github.com/user-attachments/assets/e6027670-7bed-42e8-b4ca-a5007c40461e" /></p>

<p align="center">
<b>The right companion pet at your side, without thinking about it.</b>
</p>

<p align="center">
  <a href="https://www.curseforge.com/wow/addons/petcall"><img src="https://img.shields.io/curseforge/v/1470918?label=CurseForge&color=F16436" alt="CurseForge"></a>
  <a href="https://addons.wago.io/addons/petcall"><img src="https://img.shields.io/badge/Wago-petcall-blue" alt="Wago.io"></a>
  <a href="https://github.com/Cryzer/PetCall/actions/workflows/lint.yml"><img src="https://github.com/Cryzer/PetCall/actions/workflows/lint.yml/badge.svg" alt="Lint"></a>
</p>

---

## What PetCall does

You collected hundreds of pets. PetCall makes sure you see them.

It keeps a companion pet at your side and picks one that fits the moment: a water pet while you swim, a rare one in the city, your favorites at home, a spooky one at midnight. It steps aside on its own whenever a pet would be in the way, in combat, in stealth or in the air, and comes back when it can.

You decide what fits by making **sets** of pets and telling each set **when** to be used. Or you pick one of the ready-made templates and you are done in one click.

> **New in 2.0:** a complete rebuild with a new window, conditions that read like sentences, over 40 templates, a mount condition and built-in help. Your PetCall 1.x and PetLeash sets carry over as they are. See [CHANGES.md](CHANGES.md).

---

## Highlights

**Sets that know when to show up**
- Conditions for where you are (a zone, a city, a continent, a dungeon, a raid, a delve, your house), what you are doing (swimming, AFK, in a form, riding a chosen mount), who you play with, your character, the time of day and holidays.
- Conditions read like sentences: *Activity is Swimming*, *Place type is not City*. A live dot shows what is true right now.
- "Or" groups for a set that should also be used somewhere else.
- 29 ready-made templates, one for each pet family and pet source, one for your class and one for each holiday.

**Pets the way you like them**
- Tick the pets a set picks from, or let rules do it: favorites, a pet type, a level, rare quality, where a pet comes from, or pets native to where you are. Pets you collect later follow the rules too.
- Decide how often each pet comes out, from *Never* to *Very often*.
- A 3D preview with the exact chance the pet comes out next.

**Always clear**
- A status bar along the bottom of the window that says what PetCall is doing, and why no pet is out ("Paused by: In combat").
- Built-in help: click the **i** and every part of the window explains itself.

**Fits your game**
- Blizzard's look, a dark PetCall look, or your EllesmereUI skin.
- Minimap button with a pet menu, a data broker block and an Addon Compartment entry.
- Settings in the game's own Options panel, with profiles.
- Light: no Ace3, events only for your own character, almost no cost while the window is closed.
- Available in several languages.

---

## Install

| Platform | Link |
|---|---|
| **CurseForge** | [curseforge.com/wow/addons/petcall](https://www.curseforge.com/wow/addons/petcall) |
| **Wago.io** | [addons.wago.io/addons/petcall](https://addons.wago.io/addons/petcall) |

Use the CurseForge or Wago app for automatic updates, or download the addon from either site and extract it into `World of Warcraft/_retail_/Interface/AddOns/`. The folder must be named `PetCall`.

---

## Getting started

1. **Nothing to set up.** Right after you install PetCall, the **Default** set uses all your pets and auto-summon is on. A pet comes out as soon as nothing is in the way.
2. **Open the window** with `/pcall` or **Ctrl+Click** on the minimap button.
3. **Add a set.** Click **+ New → From a template…** and pick one, such as *Water pets while swimming*. Or start an **Empty set** and add your own conditions on the **When** tab.
4. **Lost?** Click the **i** next to the logo.

### Example: a pet that matches your mount

1. **+ New → Empty set**, name it *Riders*.
2. On the **When** tab, **+ Add condition → What I am doing → Mount**, then **+ choose** and tick your drakes.
3. On the **Pets** tab, add a rule for *Dragonkin*.
4. In the PetCall settings, turn off *Don't summon while mounted*. The mount window offers to do it for you.

Now a dragonkin pet runs next to you whenever you ride one of those drakes.

---

## How PetCall picks a pet

1. **Which set.** PetCall uses the **highest set in the list whose conditions are met** right now. Drag sets to change the order. The **Default** set is always last and is used when nothing else fits.
2. **Which pets.** Only the pets ticked in that set take part. Rules tick whole groups of pets for you.
3. **Which one.** Each pet's **How often** sets its odds: *Never*, *Very rarely*, *Rarely*, *Normal*, *Often* or *Very often*. Each step makes a pet about eight times as likely as the one before. The preview shows the exact chance.

**When PetCall waits:** in combat, while flying, in stealth or invisible, in a vehicle, while dead, looting or at the barber, and in the cases you choose in the settings. The status bar at the bottom of the window says what it is waiting for.

---

## The window

### Sets (left)

- Click a set to edit it. Drag it to change the order.
- Each card says whether the set is in use, what it is waiting for, or that it is paused.
- **Right-click** a set to pause it (for an hour or until logout), rename, duplicate, export or delete it.
- **+ New** starts an empty set or one from a template. **Import** adds a set someone shared with you.
- **Out now** at the bottom: the pet at your side and the set it came from.
- The arrow at the top folds the list away for more room.

### Pets tab

- **Search** by name. Show **All** pets, only those **In this set** or only those **Left out**. The star shows only your favorites.
- **Filter**: pet types, sorting by name, level, rarity or chance, and one weight for every pet shown.
- **More chance for**: rules that put whole groups of pets in the set. Click a rule to change how often its pets come out or to narrow it down. **+ Add** makes a new rule.
- **Tick** a pet to put it in the set. **Right-click** to set how often it comes out, summon it, make it a favorite or open it in the Pet Journal.
- **Preview** on the right: the pet you point at or click, its source, level and copies, **How often**, its **chance in this set**, a **Summon** button and a favorite star.

### When tab

All conditions in a group must be met. **+ Or another set of conditions** adds a second group: then any one group is enough. Click **is** to turn a condition into **is not**, and **×** to remove it.

| Condition | What it checks |
|---|---|
| Place | a zone, a city or a whole continent; **+ current** adds where you stand |
| Place type | city or rest area, dungeon, raid, scenario, delve, battleground or arena, open world |
| Home | your house or plot, someone else's, inside a house |
| Activity | mounted, swimming, indoors, outdoors, AFK, in a shapeshift form |
| Mount | the mounts you choose: **+ current** adds the one you ride, **+ choose** opens your collection with search, filters and a 3D preview |
| Group | solo, party, raid |
| Character | class, specialization, one character by name |
| Time of day | hours on the server clock |
| Holiday | any holiday, or one in particular |
| Macro conditional | any macro condition, e.g. `[outdoors,nomounted]` |
| Lua code | your own function that returns true or false |

Mounted and Mount need *Don't summon while mounted* turned off in the settings, or PetCall waits until you dismount.

### Status bar (bottom)

- On the left: whether auto-summon is on, and *ready* or what PetCall is waiting for. Point at it for details.
- **Summon another** draws a new pet from the set in use.
- **Auto-summon** turns automatic summoning on or off.

### Set settings tab

- **Name and state:** rename the set, pause it or let it run.
- **Order:** move it up or down.
- **Behaviour:** what happens when the set starts (keep the pet that is out, or summon a new one), how often to switch pets, a chat message on summon, or **no pet at all** while the set is used, for raids or arenas.
- **Pets:** how often pets come out that you have not set by hand, new pets included. Reset all weights or edit the rules.
- **Export, duplicate or delete** the set.

---

## Templates

Click **+ New → From a template…**. Templates are grouped by when they are used: pick a group with the buttons at the top, or search by name. Each template creates an ordinary set you can change afterwards. Point at a card for its full description. Grey cards need pets you do not have yet; **Only with pets** hides them.

| Group | Templates |
|---|---|
| Everyday | Favorites first · Pets from this zone · Rare parade · Battle-ready team · Walk the little ones |
| Cities and home | Where people can see you · Evening in town · Trading Post finds · At my house · Visiting friends |
| World and instances | Flyers in the open world · Dungeons and raids · Delve crew · Scenario sidekicks · Quiet raid nights · Quiet in PvP |
| On the move | Water pets while swimming · Riding escort · Pack of the wild · Indoor company · Favorites while AFK |
| Time of day | Morning critters · Elemental dusk · Night owls · Witching hour |
| Company | Lone wanderer · Party mascots · Raid group zoo |
| Collections | one per pet family (*Beast pets*, *Aquatic pets*…) and one per source (*Pet Battle pets*, *Vendor pets*…) |
| Class and holidays | pets that suit your class · Festive mood · the event pets of each holiday you have pets for |

*Quiet raid nights* and *Quiet in PvP* keep your pet away. *Riding escort* needs *Don't summon while mounted* turned off.

---

## Settings

**Options → AddOns → PetCall**, the gear in the window, or `/pcall settings`:

- Auto-summon, the wait when idle, only after zoning, only in cities.
- Timed and per-map pet switching.
- Dismiss in stealth or invisibility. Don't summon while mounted.
- What PetCall does in dungeons and raids, and in battlegrounds and arenas.
- Special items: pause PetCall while an item that acts like a pet is in use.
- The Pet Battle loadout's pet, chat messages, the minimap button.
- Window look and scale.
- **Profiles** (switch, copy, reset, delete) and an **About** page with what's new.

---

## Minimap button and data broker

- **Left-click**: your pet out or away, with auto-summon.
- **Right-click**: a pet menu with *Summon another*, your recently summoned pets and every pet in alphabetical pages, with a 3D preview.
- **Ctrl+Click**: the PetCall window.

The same block works in data bars that support LibDataBroker and in the Addon Compartment.

---

## Sharing sets

Right-click a set, choose **Export** and send the text to a friend. They click **Import**, paste it and pick a name. Pets match by species, so the friend's own copies are ticked. Lua code in an imported set stays off until it is reviewed on the When tab. Sets exported from PetCall 1.x still import.

---

## Slash commands and key bindings

| Command | Action |
|---|---|
| `/pcall` or `/petcall` | Open the PetCall window |
| `/pcall settings` | Open the settings |
| `/pcall resummon` | Summon another pet; turns auto-summon on |
| `/pcall dismiss` | Dismiss your pet; turns auto-summon off |
| `/pcall togglePet` | Pet out or away, with auto-summon |
| `/pcall enable` | Auto-summon on or off |
| `/pcall dismissWhenStealthed` | Dismissing in stealth on or off |
| `/pcall migrate` | Show the PetLeash import again |
| `/pcall help` | List the commands |

**Options → Keybindings → AddOns → PetCall**: summon another pet, dismiss pet, toggle pet, open PetCall.

---

## FAQ

**Why is no pet out?**
Open the window with `/pcall` and look at the status bar along its bottom edge. Where it usually says *Auto-summon: ready*, it says what is in the way: combat, flying, stealth, a set with *no pet* and so on. Point at the text for details.

**My Mount condition does nothing.**
Turn off *Don't summon while mounted* in the settings. While it is on, PetCall waits until you dismount. It is on by default because a summon on a mount uses the global cooldown and can get in the way of Skyriding.

**Will PetCall slow my game down?**
No. It listens only to events about your own character, checks a condition when the game says something it depends on changed (or on a slow timer for the few things the game sends no event for, such as swimming), and does almost nothing while its window is closed.

**Can I keep pets away in raids or arenas?**
Yes: in the settings for dungeons, raids, battlegrounds and arenas, or with a set that has *No pet while this set is used*.

---

## Upgrading

### From PetCall 1.x

Nothing to do. PetCall 2.0 reads your 1.x profiles, sets, weights and conditions as they are, and orders your sets by their old priority.

### From PetLeash

PetCall continues PetLeash. Your profiles, pet sets and triggers carry over.

1. Install PetCall while PetLeash is still installed.
2. Log in: a dialog asks whether to import your PetLeash data.
3. Click **Yes**. The UI reloads once and your sets are in PetCall.
4. Uninstall PetLeash.

Skipped the dialog? Run `/pcall migrate`.

**PetLeash already removed, but its SavedVariables file is still there:**

> Close World of Warcraft completely before editing SavedVariables files.

1. Find `WTF\Account\<AccountName>\SavedVariables\PetLeash.lua`.
2. Open it in a text editor and change the first line from `PetLeash3DB` to `PetCall3DB`.
3. Save it as `PetCall.lua` in the same folder.
4. Log in: PetCall loads your data.

---

## Contributing

Ideas, bug reports and pull requests are welcome: [open an issue](https://github.com/Cryzer/PetCall/issues).

---

## License

MIT
