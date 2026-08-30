# Roblox-Game

A turn-based magic strategy game for Roblox: risk/reward spellcasting, an
Action-Time-Battle-style Speed/Action Point combat system, persistent
character progression, PvE dungeons & boss co-op, and a competitive PvP
ladder with seasons -- all server-authoritative.

This repository currently contains the **foundational architecture**: a
scalable, modular Luau codebase (synced via [Rojo](https://rojo.space/))
covering data persistence, the combat engine, progression, PvE/PvP mode
services, rewards, and monetization hooks, ready to build content on top
of.

See [`ARCHITECTURE.md`](./ARCHITECTURE.md) for the full folder hierarchy,
per-system responsibilities, the combat state machine, the data
schema/migration approach, and the security model.

## Getting started

1. Install [Rojo](https://rojo.space/docs/v7/getting-started/installation/)
   and its Roblox Studio plugin.
2. From the repo root: `rojo serve`
3. In Studio, connect via the Rojo plugin.
4. In Studio's command bar, you can run the dev-only probability simulator:
   ```lua
   local Sim = require(game.ServerScriptService.Debug.ProbabilitySimulator)
   Sim.printReport("firebolt", 100000)
   ```
5. Automated tests (assert-based, no external framework) run automatically
   in Studio via `ServerScriptService/Tests/RunAll.server.lua`.
