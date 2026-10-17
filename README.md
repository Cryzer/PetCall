# PetCall

<p align="center"><img width="400" height="400" alt="PetCall icon" src="https://github.com/user-attachments/assets/e6027670-7bed-42e8-b4ca-a5007c40461e" /></p>

<p align="center">
The right companion pet at your side, without thinking about it.
</p>

<p align="center">
  <a href="https://www.curseforge.com/wow/addons/petcall"><img src="https://img.shields.io/curseforge/v/1470918?label=CurseForge&color=F16436" alt="CurseForge"></a>
  <a href="https://addons.wago.io/addons/petcall"><img src="https://img.shields.io/badge/Wago-petcall-blue" alt="Wago.io"></a>
  <a href="https://github.com/Cryzer/PetCall/actions/workflows/lint.yml"><img src="https://github.com/Cryzer/PetCall/actions/workflows/lint.yml/badge.svg" alt="Lint"></a>
</p>

---

## Overview

PetCall keeps a companion pet out for you. You make **sets** of pets and tell each set **when** to be used: in a city, while swimming, in a raid, at your house, at night, on one character. PetCall picks a pet from the set that fits right now, summons it, and steps aside whenever a pet would get in the way, for example in combat, in stealth or on a mount.

PetCall 2.0 is a rewrite with a new window, conditions that read like sentences, ready-made templates and a built-in help. Everything from PetCall 1.x and PetLeash carries over. See [CHANGES.md](CHANGES.md) for the full list of changes.

---

## Features

- **One window for everything** (`/pcall`): your sets on the left, the selected set on the right with **Pets**, **When** and **Set settings** tabs, and a status bar that says what PetCall is doing.
- **Sets with conditions**: place, place type (city, dungeon, raid, delve, battleground…), your house, activity (swimming, mounted, indoors, AFK…), group, class and specialization, character, time of day, holiday, macro conditionals and Lua code. A live dot shows which conditions are met right now.
- **"Or" groups**: a set can be used when *any one* of several groups of conditions is met.
- **Templates**: 20 ready-made sets ("Water pets while swimming", "Night owls", "Dungeons and raids", "Visiting friends"…) that you create with one click and change like any other set.
- **Pet grid** with search, filters and sorting; copies of one pet share a tile.
- **How often**: give each pet a weight from *Never* to *Very often*, or give whole groups of pets more chances with rules (favorites, pet type, level, rare quality, source, native to where you are). Pets you collect later follow the rules too.
- **3D preview** of the pet with its chance to come out next.
- **Says why** no pet is out ("Paused by: In combat").
- **Built-in help**: the **i** next to the logo puts a description over every part of the window.
- **Share sets** as text; strings from PetCall 1.x still import.
- **Minimap button, data broker block and Addon Compartment** entry with a pet menu.
- **Looks**: Blizzard's frames, a PetCall dark look, or your EllesmereUI skin when EllesmereUI is installed.
- **Lightweight**: no Ace3, events only for your own character, nearly no cost while the window is closed.
- Available in multiple languages.

---

## Download

| Platform | Link |
|---|---|
| **CurseForge** | [curseforge.com/wow/addons/petcall](https://www.curseforge.com/wow/addons/petcall) |
| **Wago.io** | [addons.wago.io/addons/petcall](https://addons.wago.io/addons/petcall) |

Install via the CurseForge or Wago client for automatic updates, or download manually from either site and extract into:

```
World of Warcraft/_retail_/Interface/AddOns/
```

Ensure the folder is named `PetCall`.

---

## Getting started

1. Type `/pcall` (or **Ctrl+Click** the minimap button).
2. The **Default** set already uses all your pets, and auto-summon is on: PetCall summons one of them as soon as nothing is in the way.
3. Want something more? Click **+ New → From a template…** and pick a set, or start an **Empty set** and add your own conditions.
4. Not sure what a part of the window does? Click the **i** next to the logo.

---

## How PetCall picks a pet

1. **Which set.** The sets list is in order: PetCall uses the **highest set whose conditions are met** right now. Drag sets to change the order. The **Default** set is always last and is used when no other set fits.
2. **Which pets.** Only the ticked pets of that set take part. Rules can tick whole groups of pets for you ("via a rule").
3. **Which one.** Each pet's **How often** sets its odds: *Never*, *Very rarely*, *Rarely*, *Normal*, *Often*, *Very often*. Each step makes a pet about eight times as likely as the one before. The preview shows the exact chance.

PetCall also waits when a pet would be in the way: in combat, while flying, in stealth or invisible, in a vehicle, while dead, looting or at the barber, and in the other cases you choose in the settings. The status bar tells you what it is waiting for.

---

## The window

### Sets (left)

- Click a set to edit it, drag it to change the order.
- **Right-click** a set to pause, rename, duplicate, export or delete it.
- **+ New** creates an empty set or one from a template; **Import** adds a set someone shared with you.
- At the bottom: the pet that is out now and the set it came from.

### Pets tab

- **Search**, show **All** pets, only those **In this set** or **Left out**, or only favorites. The **Filter** button sorts the pets and can give one weight to every pet shown.
- **More chance for**: rules that give whole groups of pets extra chances. Click a rule to change it, **+ Add** for a new one.
- **Tick** a pet to put it in the set. **Right-click** to set its weight, summon it or make it a favorite.
- **Preview** on the right: the pet you point at or picked, its source, **How often**, its **chance in this set** and a **Summon** button.

### When tab

Conditions read like sentences: *Activity is Swimming*, *Place type is not City*. Click **is** to turn a condition into **is not**. All conditions in a group must be met; with **+ Or another set of conditions**, any one group is enough.

| Condition | Examples |
|---|---|
| Place | a zone, a city or a whole continent |
| Place type | city or rest area, dungeon, raid, scenario, delve, battleground or arena, open world |
| Home | your house or plot, someone else's, inside a house |
| Activity | mounted, swimming, indoors, outdoors, AFK, in a shapeshift form |
| Group | solo, party, raid |
| Character | class, specialization, one character by name |
| Time of day | hours on the server clock |
| Holiday | any holiday or a specific one |
| Macro conditional | e.g. `[outdoors,nomounted]` |
| Lua code | your own function that returns true or false |

### Set settings tab

Pause the set, move it up or down, choose what happens when it starts (keep the pet that is out or summon a new one), how often to switch pets, a chat message on summon, or **no pet at all** while the set is used (for raids or arenas). Under **Pets**: the weight for pets you haven't set by hand, new pets included, plus reset and export.

---

## Settings

**Options → AddOns → PetCall** (or the gear in the window, or `/pcall settings`):

- Auto-summon, wait time when idle, only after zoning, only in cities.
- Timed and per-map auto switch.
- Dismiss in stealth or invisibility; don't summon while mounted.
- What to do in dungeons and raids, and in battlegrounds and arenas.
- Special items: pause PetCall while an item that acts like a pet is in use.
- Override the Pet Battle loadout's pet, chat messages, minimap button.
- Window look and window scale.
- **Profiles** (switch, copy, reset, delete) and an **About** page with what's new.

---

## Minimap button and data broker

- **Left-click**: toggle your pet (and auto-summon).
- **Right-click**: pet menu with summon another, recently summoned pets and all pets in alphabetical pages, with a 3D preview.
- **Ctrl+Click**: open the PetCall window.

The same block works in data bars that support LibDataBroker, and in the Addon Compartment.

---

## Sharing sets

Right-click a set and choose **Export**, then send the text to a friend. They click **Import**, paste it and pick a name. Pets match by species, so the friend's own copies are ticked. Lua code in an imported set stays off until you review it in the When tab.

---

## Slash commands

| Command | Action |
|---|---|
| `/pcall` or `/petcall` | Open the PetCall window |
| `/pcall settings` | Open the settings |
| `/pcall resummon` | Summon another pet; turns auto-summon on |
| `/pcall dismiss` | Dismiss your pet; turns auto-summon off |
| `/pcall togglePet` | Toggle your pet and auto-summon |
| `/pcall enable` | Toggle auto-summon |
| `/pcall dismissWhenStealthed` | Toggle dismissing in stealth |
| `/pcall migrate` | Re-run the PetLeash import dialog |
| `/pcall help` | List commands |

Key bindings (**Options → Keybindings → AddOns → PetCall**): summon another pet, dismiss pet, toggle pet, open PetCall.

---

## Upgrading

### From PetCall 1.x

Nothing to do: PetCall 2.0 reads your 1.x profiles, sets, weights and conditions as they are, and puts your sets in the order of their old priority.

### From PetLeash

PetCall is the continuation of PetLeash. Your existing profiles, pet sets and triggers are fully compatible.

**Automatic migration**

1. Install PetCall while PetLeash is still installed.
2. Log in: a dialog asks whether to import your PetLeash data.
3. Click **Yes**: the UI reloads once and all your sets are available in PetCall.
4. You can now uninstall PetLeash.

If PetLeash data is present but you skipped the prompt, run `/pcall migrate` at any time.

**Manual migration (PetLeash already removed)**

If you have already removed PetLeash but still have its SavedVariables file:

> **World of Warcraft must be closed** before editing SavedVariables files.

1. Close World of Warcraft completely.
2. Locate `WTF\Account\<AccountName>\SavedVariables\PetLeash.lua`.
3. Open it in a text editor and change the first line from `PetLeash3DB` to `PetCall3DB`.
4. Save the file as `PetCall.lua` in the same folder.
5. Log in: PetCall loads your data.

---

## Contributing

Contributions, ideas, and feedback are welcome.

- [Open an issue](https://github.com/Cryzer/PetCall/issues)
- Submit a pull request

---

## License

MIT
