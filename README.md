# PetCall 
<p align="center"><img width="400" height="400" alt="Image" src="https://github.com/user-attachments/assets/e6027670-7bed-42e8-b4ca-a5007c40461e" /></p>


<p align="center">
Smart companion pet automation for World of Warcraft.
</p>

---

## Overview

PetCall automatically summons companion pets based on configurable rules, gameplay context, and character state.

Instead of manually selecting pets, PetCall evaluates your current situation — such as location, activity, or state — and summons the most appropriate companion pet.

PetCall is designed as a flexible automation framework for companion pets.

---

## ✨ Features

- Automatic companion pet summoning
- Rule-based trigger system (zone, instance, activity, state)
- Pet sets with priority and logical conditions
- Advanced filtering and smart selection
- Context-aware pet switching
- 3D pet preview in configuration UI
- Minimap + DataBroker integration
- Event-driven architecture (performance focused)
- Ace3 configuration panel

---

## 🧠 Why PetCall

PetCall focuses on automation.

It allows you to create predictable, context-aware pet behavior with flexible rule logic.

---

## ⚙️ Installation

### CurseForge (recommended)

Install via CurseForge client.

### Manual

1. Download the latest release  
2. Extract into:
World of Warcraft/retail/Interface/AddOns/
3. Ensure folder name is `PetCall`.

---

## 🔄 Migrating from PetLeash

PetCall is the continuation of PetLeash. Your existing profiles, pet sets, and triggers are fully compatible and can be imported automatically.

### Automatic migration

1. Install PetCall while PetLeash is still installed
2. Log in — a dialog will appear asking whether to import your PetLeash data
3. Click **Yes** — the UI reloads once and all your sets are available in PetCall
4. You can now uninstall PetLeash

### Manual migration (PetLeash already uninstalled)

If you have already removed PetLeash but still have its SavedVariables file:

> **World of Warcraft must be closed** before editing SavedVariables files. WoW overwrites them on logout, so any changes made while the game is running will be lost.

1. Close World of Warcraft completely
2. Locate `WTF\Account\<AccountName>\SavedVariables\PetLeash.lua`
3. Open it in a text editor and change the first line from `PetLeash3DB` to `PetCall3DB`
4. Save the file as `PetCall.lua` in the same folder
5. Log in — PetCall will load your data

### Manual import at any time

If PetLeash data is present but you skipped the prompt:

```
/pcall migrate
```

---

## 🚀 Usage

Open configuration:

- Interface → AddOns → PetCall
- Minimap button
- DataBroker launcher

Create pet sets and define triggers.  
PetCall handles the rest.

---

## 🧩 Technical Details

- SavedVariables: `PetCall3DB`
- Framework: Ace3
- Pet data: LibPetJournal
- Event-driven evaluation
- Localization ready

---

## 🤝 Contributing

Contributions, ideas, and feedback are welcome.

- Open an issue
- Submit a PR
- Suggest features

---

## 📜 License

MIT

---

## ⭐ Project Philosophy

PetCall treats companion pets as a system, not a button.

The goal is to provide a flexible automation layer that enables dynamic pet behavior with minimal manual interaction.
