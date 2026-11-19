# Faction Farter

A standalone addon for World of Warcraft: Forever. Fart on opposing-faction players, keep a per-character score, and browse your history. Each player normally counts once. Take a Risk can award a +2 bonus. The optional Windows companion syncs your score to the [leaderboard](https://ff.gaefrogge.com/).

## How to use

Left-click the minimap icon for the Fart and History pages. Right-click for Audio, Notifications, and Graphics settings. Select an opposing-faction player and click Fart, use `/fffart`, or use the Fart keybinding. Fart Again repeats the effect without adding another point.

Take a Risk and Autofart appear as compact ability icons below Fart. Hover for unlock progress, effects, and cooldown information. Unlocks use your character's total farts, including legacy credit and risk bonuses.

- **Take a Risk:** Unlocks at 50 farts. Use on an uncounted opposing-faction target. A 1-in-3 success earns +2 farts, including on the leaderboard. A 2-in-3 failure earns nothing and causes a 5-minute shart lockout. Either outcome starts a 30-minute cooldown.
- **Autofart:** Unlocks at 150 farts. Activate a 30-second window, then mouse over uncounted opposing-faction players to fart automatically, with 1 second between successful tags. Each new target earns +1. Activation starts a 1-hour cooldown. Your manually selected target stays selected.
- **Shart lockout:** Blocks all fart abilities, commands, keybindings, and automatic tags. It ends an active Autofart window. Brown dripping farticles accompany the lockout when Show farticles is enabled. The failure sound plays once and respects mute. Reloads and relogs preserve lockouts and cooldowns. Each icon retains its own cooldown display while the separate shart countdown shows below.

Choose separate outgoing and incoming graphics, colors, sizes, opacities, and durations. Styles include Cloud, Jet, and Confetti bomb. Move origin places your local effects. Fully left on a slider selects Random. Confetti mixes your chosen color with its complementary hue and lighter shades, using fine pieces, a quick low burst, and a slow fluttering fall.

Show party farticles is optional and off by default. It displays an updated party member's outgoing style and resolved settings at their usable, visible nameplate when available. It requires Show farticles and works independently of Show party alerts. No available nameplate means no party effect. Existing party popup and sound messages remain compatible with older versions, which may not support newer sounds or styles.

Audio choices include Wet Fart, Quick Fart, Long Fart, Squeaky Fart, Duty Time, Deep Fart, and Random. Mute fart sounds silences normal and shart clips. Playback uses WoW's Sound Effects channel. Fully quit and relaunch WoW after updating to load the new audio and artwork.

## Commands

| Command | What it does |
| --- | --- |
| `/factionfarter` | Toggle the main window. |
| `/fffart` | Fart on your current opposing-faction target. Works in macros. |
| `/ffrisk` | Take a Risk on an uncounted opposing-faction target. Unlocks at 50 farts. |
| `/ffauto` | Activate the 30-second mouseover Autofart window. Unlocks at 150 farts. |
| `/fftest` | Preview the incoming popup and sound. |
| `/ffhistory [count]` | Open a copyable list of recent records, up to 25. Risk successes appear once as +2. |
| `/ffstats [echo\|party\|guild\|say]` | Show your score and top three zones. Echo gives a private ASCII scoreboard. Shared channels receive a compact summary. |

Unavailable ability commands explain the unlock requirement, remaining cooldown, or shart lockout in local chat. Commands do not bypass these checks.

## Changelog

### v0.6

- Added Take a Risk at 50 farts: 1-in-3 chance for +2 leaderboard credit, otherwise a 5-minute shart lockout. Both outcomes have a 30-minute cooldown.
- Added Autofart at 150 farts: a manually activated 30-second mouseover tagging window, 1 second between successful new targets, and a 1-hour cooldown.
- Added macro commands `/ffrisk` and `/ffauto`, with local explanations when unavailable.
- Added a shared shart lockout across buttons, commands, keybindings, and automatic triggers. Cooldowns and lockouts persist through reloads and relogs.
- Added fixed brown dripping shart farticles and a quieter, one-shot failure sound. Graphics and sound respect their existing enable/mute settings.
- Replaced the secondary ability buttons with compact custom WoW-inspired icons, unlock tooltips, lock indicators, cooldown sweeps, and bright countdown text. Individual cooldowns remain visible during shart lockout.
- Added optional Show party farticles, independent of party popup/sound alerts. Updated clients share outgoing style, color, size, opacity, and duration, including actual Random results, and draw at usable party nameplates when available.
- Preserved existing party popup and sound protocols for older addon users.
- Added Confetti bomb to outgoing and incoming styles, with fine tumbling pieces, a fast low burst, slow fall, and an automatically complementary color palette.
- Added Squeaky Fart, Duty Time, and Deep Fart to sound selection and Random. Trimmed Duty Time's empty start/end and balanced the new clips against existing audio.
- History and `/ffhistory` show a successful risk as one target marked +2. Leaderboard credit uses the existing companion format and requires no companion update.
- Standardized Color spelling and aligned color-button labels consistently.

### v0.5

- Added farticles! Outgoing farts and incoming directed fart emotes play separately configured Cloud or Jet effects at a user-placed screen origin.
- Added independent style selection, color pickers, size, opacity, and duration controls for outgoing and incoming graphics. Drag each slider fully left for Random. Duration supports up to 8 seconds.
- Added Move origin, Reset origin, Preview outgoing, and Preview incoming controls. The origin and graphics settings save per character.
- Redesigned Settings with Audio, Notifications, and Graphics pages, flat buttons, the addon logo, and a saved draggable window position.
- Redesigned the compact main window with matching Fart and History navigation.
- Added adjustable notification text size and updated the minimap button to use the addon logo.
- Farticles respect Show farticles independently of Mute fart sounds. Effects use the placed screen origin and are visible to the local player.

### v0.4

- Replaced direct addon whispers with native fart emote detection. When someone farts on you, the addon shows their name and portrait when available and plays a default sound. This works outside your party.
- Party alerts play the exact sound the sender heard, including Random, and respect the recipient's party alert and mute settings. Older addon versions can still display the party text alert.
- Added `/ffhistory [count]` for a copyable, aligned list of up to 25 recent records with target, timestamp, zone, and subzone.
- Added `/ffstats [echo|party|guild|say]` for your character tally and top three zones. Echo shows the full scoreboard locally. Shared channels get a compact summary.
