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
- Trigger conditions: zone, instance type, activity, resting, class, specialization, and more
- Multiple pet sets with priority — the highest-priority active set wins
- Add multiple pets to a set — PetCall picks one at random
- Filter pets by favorites, type, level, and more
- Import and export pet sets as shareable strings — easy to share with friends
- 3D pet preview when browsing pets in the options panel
- Minimap button for quick access
- Lightweight — has minimal impact on game performance
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

Open configuration:

- **Interface → AddOns → PetCall**
- Minimap button — **Ctrl+Click**

The minimap button also gives quick access to your pet:

- **Left-click** — toggle PetCall on or off (dismisses or resummons your pet)
- **Right-click** — open the pet selection panel

### Pet Triggers tab

Create one or more **pet sets**. Each set defines:

- A **pet pool** — which companions can be summoned by this set
- One or more **trigger conditions** — when this set should be active
- **Priority** — higher-priority sets take precedence over lower ones
- **Default behavior** — what happens when none of the trigger conditions are met (summon or dismiss)

Sets are checked in priority order. The first active set wins.

### Import / Export

Share your pet set configuration with other players using the **Export** button on any set. Send the resulting string to a friend — they paste it into **Import Set** and choose a name for it.

### Slash commands

| Command | Action |
|---|---|
| `/pcall` | Open configuration |
| `/pcall migrate` | Re-run the PetLeash import dialog |

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
