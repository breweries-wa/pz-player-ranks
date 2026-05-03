# Player Ranks

A multiplayer server mod for **Project Zomboid Build 42**. Tracks player stats across a configurable set of categories, persists data server-side, and displays ranked leaderboards in-game. Stats are tracked at two levels: **lifetime** (survives death, resets on server wipe) and **current character** (resets on death).

---

## Features

- **39 tracked stats** across 7 categories: Survival, Exploration, Combat, Industry, Deaths & Suffering, Vehicles, and Social/Chaos
- **Lifetime vs. character split** — compete on who's died the most or who's survived the longest without dying
- **Hall of Fame snapshot** — before a server wipe, the top 3 per stat are preserved and viewable in-game
- **In-game leaderboard UI** (Phase 3) — tabbed panel with stat picker, top-10 list, and a "you are here" context block
- **Admin chat commands** — wipe data, snapshot the Hall of Fame, or reset individual players
- No client mod required — server-side only

---

## Stat Categories

| Category | Example Stats |
|---|---|
| Survival | Days Survived, Calories Consumed, Time Online, Hours Slept |
| Exploration | Unique Tiles Visited, Distance Traveled, Farthest From Spawn |
| Combat | Zombies Killed, Headshots, Times Bitten, Times Scratched |
| Industry | Items Crafted, Structures Built, Crops Planted/Harvested |
| Deaths & Suffering | Total Deaths, Longest Streak, Times Passed Out |
| Vehicles | Vehicles Repaired, Vehicles Hotwired, Fuel Consumed |
| Social / Chaos | Items Given, Doors Kicked, Windows Smashed, Chat Messages Sent |

---

## Installation

1. Subscribe on the Steam Workshop *(link added after first publish)*
2. Enable **Player Ranks** in the mod list when setting up your server
3. No client-side installation required — players connect normally

### Manual install

Copy the `PlayerRanks` folder into your server's `Zomboid/mods/` directory:

```
Zomboid/mods/PlayerRanks/
  mod.info
  common/mod.info
  42/media/lua/...
```

---

## Admin Commands

Type these in the in-game chat. All commands except `/ranks show` require Admin or Moderator access level.

| Command | Effect |
|---|---|
| `/ranks show` | Print top 5 Zombies Killed (lifetime) to your chat |
| `/ranks show <statId>` | Print top 5 for any stat (e.g. `/ranks show distancetraveled`) |
| `/ranks snapshot` | Save a Hall of Fame snapshot from current lifetime data |
| `/ranks wipe` | Snapshot then clear all player data |
| `/ranks reset <player>` | Reset both stat sets for a named player |
| `/ranks resetchar <player>` | Reset only current-character stats for a named player |

Stat IDs match the internal names shown in the table below — lowercase, no spaces (e.g. `zombieskilled`, `tilesvisited`, `totaldeaths`).

---

## Data & Persistence

- All data is stored server-side via PZ's `ModData` API under the key `PlayerRanks_data`
- Keyed by Steam ID — data survives character death and respawn
- Character stats zero out on death; lifetime stats never reset until a server wipe
- The Hall of Fame snapshot (`/ranks snapshot` or auto-saved before `/ranks wipe`) preserves the top 3 players per stat
- Clients send stat deltas to the server every 30 seconds and on clean logout — the server holds the authoritative record

---

## Roadmap

| Phase | Status | Scope |
|---|---|---|
| 1 — Foundation | ✅ Complete | Mod scaffold, stat definitions, server data layer, event hooks (zombies killed, chat), admin chat commands, death handling |
| 2 — Polling + Full Coverage | 🔲 Planned | 5s client timer, polled stats (distance, tiles visited, time online, etc.), wipe handler |
| 3 — UI | 🔲 Planned | ISPanel leaderboard with tabs (My Stats / Top Players / Top Characters / Hall of Fame), stat dropdown, "you are here" row |
| 4 — Polish | 🔲 Planned | Stat format strings, config file (sampling interval, enabled stats), Workshop page |

---

## Development

```
workshop/content/108600/PlayerRanks/
  mod.info
  common/mod.info          ← required duplicate or mod won't appear in list
  42/
    media/
      lua/
        shared/
          PlayerRanks_StatDefs.lua   ← stat catalog, format helpers
        server/
          PlayerRanks_Server.lua     ← data layer, leaderboard queries, death/wipe handling
        client/
          PlayerRanks_Client.lua     ← event hooks, delta batching, /ranks command
```

After editing, deploy to the runtime copy before restarting PZ:

```powershell
Copy-Item ".\PlayerRanks\42\media\lua\*" "C:\Users\<you>\Zomboid\mods\PlayerRanks\42\media\lua\" -Recurse -Force
```

---

## License

MIT
