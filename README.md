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

You decide what fits by making **sets** of pets and telling each set **when** to be used. Or you pick one of the ready-made templates and you are done in one click. **Exceptions** keep the pet away where you don't want one, such as battlegrounds or raids.

> **New in 2.0:** a complete rebuild with a new window, conditions that read like sentences, over 40 templates, a mount condition and built-in help. Your PetCall 1.x and PetLeash sets carry over as they are. See [CHANGES.md](CHANGES.md).

---

## Highlights

**Sets that know when to show up**
- Conditions for where you are (a zone, a city, a continent, a dungeon, a raid, a delve, your house), what you are doing (swimming, AFK, in a form, riding a chosen mount), who you play with, your character, the time of day and holidays.
- Conditions read like sentences: *Activity is Swimming*, *Place type is not City*. A live dot shows what is true right now.
- "Or" groups for a set that should also be used somewhere else.
- 33 ready-made templates, plus one for each pet family, pet source and expansion, one for your class and one for each holiday.

**Exceptions beside your sets**
- Battlegrounds, Arenas, Dungeons, Raids, Scenarios and delves, While mounted, Stealth or invisibility and Outside cities each have one choice: *As usual*, *Leave the pet alone* or *Put the pet away*. Dungeons, Raids, and Scenarios and delves can apply only in a group.
- Your own exceptions, from the same conditions as sets.
- Your own key presses and clicks always work. Dismissing your pet pauses Auto-summon until you change zone.

**Pets the way you like them**
- Tick the pets a set picks from, or let rules do it: favorites, a pet type, a level, rare quality, where a pet comes from, the expansion it came with, or pets native to where you are or from the expansion of the land you are in. Pets you collect later follow the rules too.
- Decide how often each pet comes out, from *Never* to *Very often*.
- A 3D preview with the exact chance the pet comes out next.

**Always clear**
- The **Out now** card says in one sentence why the pet is or isn't out ("Because: exception Battlegrounds puts the pet away."), with a button to where you can change it.
- A status bar along the bottom of the window, and the minimap button's tooltip, say what PetCall is doing ("Paused: In combat").
- **Use recommended settings** shows your settings beside the recommended ones before anything changes, with Undo.
- Built-in help: click the **i** and every part of the window explains itself.

**Fits your game**
- Blizzard's look, a dark PetCall look, or your EllesmereUI skin.
- Minimap button with a pet menu, a data broker block and an Addon Compartment entry.
- Everything that changes what PetCall does is in its window. The game's Options panel keeps the look and the profiles.
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

1. **Nothing to set up.** Right after you install PetCall, the **Default** set uses all your pets and Auto-summon is on. A pet comes out as soon as nothing is in the way.
2. **Open the window** with `/pcall` or **Ctrl+Click** on the minimap button.
3. **Add a set.** Click **+ New → From a template…** and pick one, such as *Water pets while swimming*. Or start an **Empty set** and add your own conditions on the **When** tab.
4. **Not here?** Select **How PetCall acts** above the sets and set an exception, such as *Raids*, to *Put the pet away*.
5. **Lost?** Click the **i** next to the logo.

### Example: a pet that matches your mount

1. **+ New → Empty set**, name it *Riders*.
2. On the **When** tab, **+ Add condition → What I am doing → Mount**, then **+ choose** and tick your drakes.
3. On the **Pets** tab, add a rule for *Dragonkin*.
4. On **How PetCall acts**, set the **While mounted** exception to *As usual*. The mount window has a button that takes you there.

Now a dragonkin pet runs next to you whenever you ride one of those drakes.

---

## How PetCall picks a pet

1. **Which set.** PetCall uses the **highest set in the list whose conditions are met** right now. Drag sets to change the order. The **Default** set is always last and is used when nothing else fits.
2. **Which pets.** Only the pets ticked in that set take part. Rules tick whole groups of pets for you.
3. **Which one.** Each pet's **How often** sets its odds: *Never*, *Very rarely*, *Rarely*, *Normal*, *Often* or *Very often*. Each step makes a pet about eight times as likely as the one before. The preview shows the exact chance.

**When PetCall waits**, in this order:

1. **The game.** In combat, while flying, in stealth or invisible, in a vehicle, while dead, sitting, looting, at the barber or in a pet battle. Your own key presses wait for these too, and say so in chat.
2. **Auto-summon.** When it is off, or paused because you dismissed your pet, PetCall does nothing by itself. Your key presses and clicks still work.
3. **Exceptions.** Where an exception fits, PetCall leaves the pet alone or puts it away. Your own key presses go past it and say so in chat.

The **Out now** card says which of these holds the pet back. The status bar and the minimap button's tooltip say it in short.

---

## The window

### Sets (left)

- **How PetCall acts**, above the sets, opens Auto-summon and the exceptions (see below). It says in a word what is in force now.
- Click a set to edit it. Drag it to change the order.
- Each card says whether the set is in use, what it is waiting for, or that it is paused.
- **Right-click** a set to pause it (for an hour or until logout), rename, duplicate, export or delete it.
- **+ New** under the list starts an empty set or one from a template. **Import** adds a set someone shared with you.
- **Out now** at the bottom: the pet at your side and the set it came from. Click it to find it in that set. Its **Because:** sentence says why the pet is or isn't out, and its button leads to the place that changes it.
- The arrow at the top folds the list away for more room.

### How PetCall acts

What PetCall does by itself, whichever set is in use.

- **Automatic:** Auto-summon (on, off, or paused until you change zone), **Bring out a pet** (*When I stand still*, after a few seconds, or *Only after a loading screen*), **New pet on a new map**, and **After a pet battle** (*Bring back my pet* or *Keep the game's pick*). A pet that PetCall or the game took away comes back when that ends.
- **Exceptions:** one row each, with *As usual*, *Leave the pet alone* or *Put the pet away*. Put the pet away acts when the exception starts to fit, so a pet you summon yourself there stays. Dungeons, Raids, and Scenarios and delves have **Also when solo**: clear it and the exception fits only in a party or raid group. **Add exception** makes one of your own from conditions.
- **Pet-like items:** pause PetCall while an item that acts like a pet is in use.
- **Use recommended settings:** your settings beside the recommended ones. Only the rows shown change, and Undo puts yours back.

### Pets tab

- **Search** by name. Show **All** pets, only those **In this set** or only those **Left out**. The star shows only your favorites.
- **Filter**: pet type, source, the expansion a pet came with, level, rarity, the zone you are in or its expansion, and sorting by name, level, rarity or chance. The line under the toolbar names each filter (click one to remove it). **How often for N shown** gives every pet shown a setting of its own.
- **Make a rule** keeps the filters as a rule: those pets, and pets you collect later that match, come out as often as you pick. The **Rules** button opens a rule on the list, where it reads as a sentence; change its filters or how often, then **Save rule**. A pet two rules pick comes out as often as the stronger one says.
- **Tick** a pet to put it in the set. Untick a pet a rule picks to leave it out anyway; tick it again to give it back to the rule. A pet's own setting always wins over its rules. **Right-click** to set how often it comes out, summon it, make it a favorite or open it in the Pet Journal.
- **Preview** on the right: the pet you point at or click, its source, level and copies, **How often** on a slider (blue when a rule sets it; **Use the rule** gives a pet set by hand back to it), its **chance in this set**, a **Summon** button and a favorite star.

### When tab

All conditions in a group must be met. **+ Or another set of conditions** adds a second group: then any one group is enough. Click **is** to turn a condition into **is not**, and **×** to remove it.

| Condition | What it checks |
|---|---|
| Place | a zone, a city or a whole continent; **+ current** adds where you stand |
| Place type | city or rest area, dungeon, raid, scenario, delve, battleground, arena, open world |
| Home | your house or plot, someone else's, inside a house |
| Activity | mounted, swimming, indoors, outdoors, AFK, in a shapeshift form |
| Hidden | stealth, invisibility, camouflage, feign death |
| Mount | the mounts you choose: **+ current** adds the one you ride, **+ choose** opens your collection with search, filters and a 3D preview |
| Group | solo, party, raid |
| Character | class, specialization, one character by name |
| Time of day | hours on the server clock |
| Holiday | any holiday, or one in particular |
| Macro conditional | any macro condition, e.g. `[outdoors,nomounted]` |
| Lua code | your own function that returns true or false |

Mounted and Mount need the **While mounted** exception set to *As usual*, or PetCall waits until you dismount.

### Status bar (bottom)

- On the left: whether Auto-summon is on, and *ready* or what PetCall is waiting for. Point at it for details.
- **Summon another** draws a new pet from the set in use.
- **Auto-summon** turns automatic summoning on or off. While it is paused, it reads *Auto-summon (Paused)*.

### Set settings tab

- **Name and state:** rename the set, pause it or let it run.
- **Order:** move it up or down.
- **Behaviour:** what happens when the set starts (keep the pet that is out, or summon a new one), **New pet every** (with *only in cities* as one of the choices) and **Message on summon**. The Default set holds the base values; other sets can use them with *Like Default*.
- **Pets:** how often the other pets come out, the ones no rule picks and you have not set by hand, new pets included. **Undo all by hand** gives every pet back to the rules, or edit the rules.
- **Export, duplicate or delete** the set.

---

## Templates

Click **+ New → From a template…**. Templates are grouped by when they are used: pick a group with the buttons at the top, or search by name. Each template creates an ordinary set you can change afterwards. Point at a card for its full description. Grey cards need pets you do not have yet; **Only with pets** hides them.

| Group | Templates |
|---|---|
| Everyday | Favorites first · Pets from this zone · Pets from this expansion · Rare parade · Battle-ready team · Walk the little ones |
| Cities and home | Where people can see you · Evening in town · Trading Post finds · Hard-earned trophies · Collector's shelf · Workshop crew · At my house · Visiting friends |
| World and instances | Flyers in the open world · Caught in the wild · Dungeons and raids · Delve crew · Scenario sidekicks |
| On the move | Water pets while swimming · Riding escort · Pack of the wild · Indoor company · Favorites while AFK |
| Time of day | Morning critters · Daylight wanderers · Elemental dusk · Night owls · Witching hour |
| Company | Lone wanderer · Party mascots · Raid group zoo |
| Collections | one per pet family (*Beast pets*, *Aquatic pets*…), one per source (*Pet Battle pets*, *Vendor pets*…) and one per expansion (*Legion pets*, *Dragonflight pets*…) |
| Class and holidays | pets that suit your class · Festive mood · the event pets of each holiday you have pets for |

*Riding escort* needs the **While mounted** exception set to *As usual*. To keep your pet away somewhere, use an exception.

---

## Settings

Which pets come out, where and how often is set in the PetCall window: in the sets and on **How PetCall acts**.

**Options → AddOns → PetCall** (the gear in the window, or `/pcall settings`) only changes how PetCall looks:

- An **Open** button for the PetCall window.
- **Appearance:** the minimap button, the window's scale and look.
- **Keys and commands:** a button to the game's key bindings for PetCall.
- **Profiles** (switch, copy, reset, delete) and an **About** page with what's new.

---

## Minimap button and data broker

**Point at the button** to see the status at a glance: whether Auto-summon is on, off or paused, the set in use, the pet that is out, what PetCall is waiting for (*Paused by: Mounted*) and how many pets you have.

- **Left-click**: your pet out or away.
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
| `/pcall settings` | Open PetCall's page in the game's Options |
| `/pcall resummon` | Summon another pet |
| `/pcall dismiss` | Dismiss your pet; Auto-summon pauses until you change zone |
| `/pcall togglePet` | Summon or dismiss your pet |
| `/pcall enable` | Auto-summon on or off |
| `/pcall migrate` | Show the PetLeash import again |
| `/pcall help` | List the commands |

**Options → Keybindings → AddOns → PetCall**: summon another pet, dismiss pet, toggle pet, open PetCall. Like the commands, the keys never turn Auto-summon off: dismissing pauses it until you change zone, and summoning ends the pause.

---

## FAQ

**Why is no pet out?**
Open the window with `/pcall` and read the **Because:** sentence on the **Out now** card. It names what holds the pet back: the game (combat, flying, sitting…), Auto-summon (off, or paused because you dismissed your pet) or an exception. Its button leads to where you can change it. Without opening the window: point at the minimap button.

**My Mount condition does nothing.**
Set the **While mounted** exception on **How PetCall acts** to *As usual*. Otherwise PetCall waits until you dismount. It leaves the pet alone by default because a summon on a mount uses the global cooldown and can get in the way of Skyriding.

**Will PetCall slow my game down?**
No. It listens only to events about your own character, checks a condition when the game says something it depends on changed (or on a slow timer for the few things the game sends no event for, such as swimming), and does almost nothing while its window is closed.

**Can I keep pets away in raids or arenas?**
Yes: on **How PetCall acts**, set the *Raids* or *Arenas* exception to *Put the pet away*. For any other place, add an exception of your own.

**I dismissed my pet and it stays away.**
That is on purpose: dismissing your pet yourself pauses Auto-summon until you change zone. Summon a pet, or click **Resume** on the Out now card, to end the pause.

---

## Upgrading

### From PetCall 1.x

Nothing to do. PetCall 2.0 reads your 1.x profiles, sets, weights and conditions as they are, and orders your sets by their old priority.

### From PetCall 2.2 or earlier

Your old settings move into the PetCall window once, on the first login, and keep doing what they did. A set that kept the pet away becomes an exception. A welcome screen shows your settings beside the recommended ones; *Keep mine* changes nothing.

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
