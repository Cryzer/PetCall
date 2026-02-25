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

PetCall automatically summons companion pets based on configurable rules, gameplay context, and character state.

Instead of manually selecting pets, PetCall evaluates your current situation — such as location, activity, or state — and summons the most appropriate companion pet.

PetCall is designed as a flexible automation framework for companion pets.

---

## Features

- Automatic companion pet summoning based on your current context
- Rule-based trigger system (zone, instance, activity, state, class, specialization, and more)
- Pet sets with configurable priority and enable/disable toggle
- Multiple pets per set — PetCall picks one at random from the pool
- Advanced filters (favorites, pet type, level, etc.)
- Import and export pet sets as shareable strings
- 3D pet preview in the configuration UI
- Minimap button and DataBroker launcher
- Event-driven architecture for minimal performance impact
- Ace3 configuration panel with full localization support

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
- Minimap button — **Ctrl+Click** to open options
- Addon bar button (TitanPanel, ElvUI data texts, etc.)

The minimap button also lets you interact with your pet directly:

- **Left-click** — summon or dismiss your current pet
- **Right-click** — open the pet selection panel

### Pet Triggers tab

Create one or more **pet sets**. Each set defines:

- A **pet pool** — which companions can be summoned by this set
- One or more **trigger conditions** — when this set is active
- **Priority** — higher-priority sets take precedence
- **Default value** — whether to summon or dismiss when no trigger matches

Sets are evaluated in priority order. The first active set wins.

### Import / Export

Share your pet set configuration with other players using the **Export** button on any set. Send the resulting string to a friend; they paste it into **Import Set** and choose a name.

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

## Technical Details

- SavedVariables: `PetCall3DB`
- Framework: Ace3 (AceAddon, AceDB, AceGUI, AceConfig, AceConsole, AceEvent, AceSerializer)
- Pet data: LibPetJournal-2.0
- Broker: LibDataBroker, LibDBIcon
- Static analysis: Luacheck CI on every push

---

## Contributing

Contributions, ideas, and feedback are welcome.

- [Open an issue](https://github.com/Cryzer/PetCall/issues)
- Submit a pull request
- Help with translations on [CurseForge](https://www.curseforge.com/wow/addons/petcall) or [Wago.io](https://addons.wago.io/addons/petcall)

---

## License

MIT
