# Faction Farter

A standalone addon for World of Warcraft: Forever. Fart on opposing-faction players, keep a per-character tally of unique targets, and browse your history. The companion is optional for public leaderboard sync.

## Changelog

### v0.4

- Replaced direct addon whispers with native fart emote detection. When someone farts on you, the addon shows their name and portrait when available and plays a default sound. This works outside your party.
- Party alerts play the exact sound the sender heard, including Random, and respect the recipient's party alert and mute settings. Older addon versions can still display the party text alert.
- Added `/ffhistory [count]` for a copyable, aligned list of up to 25 recent records with target, timestamp, zone, and subzone.
- Added `/ffstats [echo|party|guild|say]` for your character tally and top three zones. Echo shows the full scoreboard locally. Shared channels get a compact summary.
