# PetCall

<p align="center"><img width="400" height="400" alt="PetCall icon" src="https://github.com/user-attachments/assets/e6027670-7bed-42e8-b4ca-a5007c40461e" /></p>

<p align="center">
Smart companion pet automation for World of Warcraft.
</p>

<p align="center">
  <a href="https://www.curseforge.com/wow/addons/petcall"><img src="https://img.shields.io/curseforge/v/1470918?label=CurseForge&color=F16436" alt="CurseForge"></a>
  <a href="https://addons.wago.io/addons/petcall"><img src="https://img.shields.io/badge/Wago-petcall-blue" alt="Wago.io"></a>
  <a href="https://github.com/Cryzer/PetCall/actions/workflows/lint.yml"><img src="https://github.com/Cryzer/PetCall/actions/workflows/lint.yml/badge.svg" alt="Lint"></a>
</p>

---

## Overview

PetCall automatically summons companion pets based on configurable rules and your current situation in the game.

Instead of manually picking a pet every time, PetCall checks where you are, what you're doing, and what class or spec you're playing — then summons the right companion automatically.

---

## Features

- Automatically summons a companion pet based on your current situation
- One window for everything (`/pcall`): your sets, a searchable pet grid, conditions and set settings
- Conditions that read like sentences: place, place type, group (solo/party/raid), class and specialization, character, time of day, macro conditionals and Lua code — with live "met right now" indicators
- "Or" groups and one-click templates (in a city, in a raid or dungeon, here, my spec, in a group)
- Multiple pet sets with priority — the highest-priority active set wins
- Pet weights from Never to Extra High, plus auto rules (favorites, pet type, level)
- 3D preview with the pet's chance in the active set
- Shows why no pet is summoned ("Paused by: In combat")
- Native game Settings panel with profiles
- Import and export pet sets as shareable strings (1.x strings still work)
- Minimap button, data broker block and Addon Compartment entry with a pet menu
- EllesmereUI skin support
- Lightweight — no Ace3, minimal impact on game performance
- Available in multiple languages

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

## Usage

Open PetCall:

- `/pcall` (or `/petcall`)
- Minimap button or Addon Compartment — **Ctrl+Click**
- **Options → AddOns → PetCall → Open**

The minimap button:

- **Left-click** — toggle your pet (and auto-summon)
- **Right-click** — pet menu: summon another, recently summoned, all pets
- **Ctrl+Click** — open the PetCall window

### Sets

The **Default** set is used whenever no other set is active. Create more sets with **+ New**; each set has:

- **Pets** — click a pet to include or exclude it, right-click for its weight; auto rules add weight to matching pets
- **When** — the conditions that make the set active; add "or another set of conditions" for alternatives
- **Set settings** — priority, summon immediately, name, export, delete

When several sets are active, the one with the highest priority wins.

### Import / Export

Use **Export** on any set (right-click it in the sets list) and send the string to a friend — they paste it into **Import** and choose a name. Imported Lua code stays disabled until you review it in the When tab.

### Slash commands

| Command | Action |
|---|---|
| `/pcall` | Open the PetCall window |
| `/pcall settings` | Open the settings |
| `/pcall resummon` | Summon another pet; turns auto-summon on |
| `/pcall dismiss` | Dismiss your pet; turns auto-summon off |
| `/pcall togglePet` | Toggle your pet and auto-summon |
| `/pcall enable` | Toggle auto-summon |
| `/pcall dismissWhenStealthed` | Toggle dismissing in stealth |
| `/pcall migrate` | Re-run the PetLeash import dialog |
| `/pcall help` | List commands |

---

## Migrating from PetLeash

PetCall is the continuation of PetLeash. Your existing profiles, pet sets, and triggers are fully compatible.

### Automatic migration

1. Install PetCall while PetLeash is still installed
2. Log in — a dialog will appear asking whether to import your PetLeash data
3. Click **Yes** — the UI reloads once and all your sets are available in PetCall
4. You can now uninstall PetLeash

### Manual migration (PetLeash already removed)

If you have already removed PetLeash but still have its SavedVariables file:

> **World of Warcraft must be closed** before editing SavedVariables files.

1. Close World of Warcraft completely
2. Locate `WTF\Account\<AccountName>\SavedVariables\PetLeash.lua`
3. Open it in a text editor and change the first line from `PetLeash3DB` to `PetCall3DB`
4. Save the file as `PetCall.lua` in the same folder
5. Log in — PetCall will load your data

If PetLeash data is present but you skipped the prompt, run `/pcall migrate` at any time.

---

## Contributing

Contributions, ideas, and feedback are welcome.

- [Open an issue](https://github.com/Cryzer/PetCall/issues)
- Submit a pull request

---

## License

MIT
