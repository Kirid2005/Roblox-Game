# Architecture

Foundational server-authoritative architecture for a turn-based magic
strategy game (PvE dungeons/bosses, PvP ladder, persistent character
progression, monetization). Built with [Rojo](https://rojo.space/) so the
whole project lives as plain-text Luau under `src/` and syncs into Roblox
Studio.

## Opening the project

```
rojo serve
```

then connect from the Rojo Studio plugin. `default.project.json` maps
`src/ReplicatedStorage`, `src/ServerScriptService`, `src/ServerStorage`,
`src/StarterPlayer/StarterPlayerScripts`, and `src/StarterGui` onto the
matching Roblox services.

## Design principles this codebase follows

- **Server authority everywhere it matters.** Every random roll, every AP/
  gauge change, every stat calculation, every reward and rating change
  happens in a server-only ModuleScript. Clients send *requests*
  (`RequestCastSpell`, `RequestUnlockSkillNode`, ...); the server decides.
- **Configuration over code.** Spells, skill tree nodes, items, enemies,
  encounters, and reward tables are all plain data tables (`SpellCatalog`,
  `SkillTreeCatalog`, `ItemCatalog`, `NPCCatalog`, `EncounterCatalog`,
  `RewardTables`). Adding content should rarely require touching the
  combat engine.
- **One reusable combat engine, many modes.** PvE, co-op, boss, and PvP
  fights are all a `CombatSession` built from a roster of `Combatant`s.
  Mode services (`DungeonService`, `BossEncounterService`,
  `PvPMatchService`) differ only in how they build that roster and what
  they do on victory/defeat.
- **Generic effects, not special cases.** Every spell verb (damage, heal,
  buff, debuff, gauge/AP manipulation, stun, shield) is one of a small set
  of `EffectType`s dispatched by `EffectSystem`. New tempo-manipulation
  mechanics are new effect data, not new code paths.

## ReplicatedStorage hierarchy (safe to replicate)

```
ReplicatedStorage/
└── Shared/
    ├── Constants.lua          -- tunable numbers (gauge rate, XP curve, caps, ...)
    ├── Enums.lua               -- CombatState, EffectType, StatId, TargetType, ...
    ├── Net.lua                 -- RemoteEvent/RemoteFunction registry + fire/invoke helpers
    ├── SchemaVersion.lua       -- current player-data schema version
    ├── Util/
    │   ├── Signal.lua          -- minimal in-VM event emitter
    │   └── Table.lua           -- deepCopy / reconcile (schema migration helper) / freeze
    ├── Spells/
    │   └── SpellCatalog.lua    -- spell definitions incl. outcome-probability tables
    ├── SkillTree/
    │   └── SkillTreeCatalog.lua
    ├── Items/
    │   └── ItemCatalog.lua
    └── StatusEffects/
        └── StatusEffectCatalog.lua  -- display/stacking metadata for named buffs/debuffs
```

Nothing here can execute a probability roll, compute a reward, or hold
authoritative character state -- it is all either pure configuration or
plumbing. That's a deliberate boundary: a client can read a spell's odds
for its tooltip, but never roll them.

## ServerScriptService hierarchy (server-only logic)

```
ServerScriptService/
├── Bootstrap/
│   └── Init.server.lua         -- the one script that starts everything, in order
├── Network/
│   ├── RemoteRegistry.lua      -- creates the RemoteEvent/RemoteFunction instances
│   ├── CombatRemotes.lua       -- cast requests in, throttled state snapshots out
│   ├── ProgressionRemotes.lua  -- profile snapshot + skill unlock requests
│   ├── PvPRemotes.lua          -- queue join/leave, match-found push, leaderboard reads
│   └── MonetizationRemotes.lua -- purchase *prompt* requests only (never grants)
├── Data/
│   ├── DataSchema.lua          -- versioned profile shape + migration chain
│   └── PlayerDataService.lua   -- DataStore load/save, session locking, retries, autosave
├── Progression/
│   ├── StatCalculator.lua      -- base + equipment + skill tree -> derived stats (pure)
│   ├── ExperienceService.lua   -- XP curve, leveling, skill point grants
│   ├── SkillTreeService.lua    -- validates & applies node unlocks
│   ├── SpellbookService.lua    -- spell ownership/level-gate checks
│   └── InventoryService.lua    -- item stock + equip/unequip
├── Combat/                     -- the reusable, mode-agnostic combat engine
│   ├── Combatant.lua            -- runtime per-participant state (HP/AP/gauge/effects)
│   ├── CombatantFactory.lua     -- Player+profile / NPCDef -> Combatant params
│   ├── ActionGauge.lua          -- Speed -> gauge fill -> AP (server-tick driven)
│   ├── ApManager.lua            -- effective AP cost, afford/spend/grant
│   ├── EffectSystem.lua         -- generic effect dispatch (damage/heal/buff/gauge/AP/...)
│   ├── DamageCalculator.lua     -- pure damage/heal amount + shield absorption math
│   ├── SpellResolver.lua        -- server-authoritative outcome roll + effect application
│   ├── CombatSession.lua        -- FSM + roster + combat log + snapshot for one encounter
│   ├── CombatRegistry.lua       -- process-wide active-session registry
│   ├── CombatValidator.lua      -- the "can this client actually do this?" checklist
│   ├── CombatEngine.lua         -- public orchestration API mode services call into
│   └── TurnScheduler.lua        -- single fixed-rate loop ticking every active session
├── Modes/
│   ├── PvE/
│   │   ├── EncounterFactory.lua      -- EncounterDef -> NPC-side Combatant params
│   │   ├── DungeonService.lua        -- party validation, session creation, PvE rewards
│   │   └── BossEncounterService.lua  -- boss content on the same engine + phase triggers
│   └── PvP/
│       ├── MatchmakingService.lua    -- rating-based queue/pairing
│       ├── PvPMatchService.lua       -- 1v1 session creation + result resolution
│       ├── RatingService.lua         -- pure Elo math
│       ├── SeasonService.lua         -- cross-server season lifecycle, soft resets
│       └── LeaderboardService.lua    -- OrderedDataStore per season
├── Rewards/
│   ├── RewardTables.lua        -- reward payouts per mode/encounter (data)
│   └── RewardService.lua       -- idempotent grant (ledger-keyed) into a profile
├── Monetization/
│   ├── ProductCatalog.lua      -- developer product / game pass -> effect mapping
│   └── MonetizationService.lua -- ProcessReceipt (idempotent), game pass entitlement
├── Security/
│   └── RateLimiter.lua         -- per-player-per-remote token bucket
├── Debug/
│   └── ProbabilitySimulator.lua -- mass-simulate a spell's outcome distribution
└── Tests/
    ├── TestRunner.lua           -- tiny assert-based runner (no external framework)
    ├── *.spec.lua                -- StatCalculator, DamageCalculator, ActionGauge,
    │                                RatingService, SpellResolver suites
    └── RunAll.server.lua         -- Studio-only: runs every spec, prints a summary
```

## ServerStorage hierarchy (server-only, not client-relevant)

```
ServerStorage/
└── GameData/
    ├── NPCCatalog.lua          -- enemy/boss stat blocks (no reason to preload to clients)
    ├── EncounterCatalog.lua    -- dungeon rooms/bosses: which NPCs, player-count range
    └── SeasonRewardTiers.lua   -- PvP season-end reward thresholds (competitively sensitive)
```

## StarterPlayer / StarterGui hierarchy (client)

```
StarterPlayer/StarterPlayerScripts/
├── Bootstrap.client.lua        -- client entrypoint, same "wire in order" pattern as the server
├── Network/
│   └── RemoteClient.lua        -- Net.lua wrapper: server pushes -> local Signals
├── Combat/
│   ├── CombatController.lua    -- cached view of the current CombatSession snapshot
│   └── InputController.lua     -- keybinds/clicks -> (spell, target) selection -> request
└── UI/
    └── CombatUIController.lua  -- minimal runtime-built HUD driven entirely by server state

StarterGui/
└── UINotes.lua                 -- explains the runtime-UI approach; future hand-authored
                                    menus (inventory, skill tree browser) belong here
```

The client never simulates combat. `CombatController` is a cache of the
last `CombatStateUpdated` snapshot; `CombatUIController` just renders it.

## The combat state machine

`CombatSession.state` (session-level): `Waiting -> Charging -> Victory |
Defeat | Ended`.

Each `Combatant.actionState` (per-participant, only meaningful while the
session is `Charging`): `Charging -> ActionReady -> SelectingAction ->
ResolvingAction -> ApplyingEffects -> WaitingForNextAction -> Charging`.

This is intentionally two-layered: the *session* is doing exactly one of
"waiting to start / actively fighting / over"; each *combatant*
independently cycles through its own action-readiness state, which is what
makes the ATB-style concurrency work (multiple combatants can be
`ActionReady` at once, especially in co-op).

`TurnScheduler` ticks every registered `CombatSession` at
`Constants.COMBAT_TICK_RATE` Hz from server-measured `dt`. Per tick, per
alive combatant: `ActionGauge.advance` (Speed -> gauge -> AP),
`EffectSystem.tickPeriodicEffects` (DoT/HoT pulses, expiry pruning), then
the session's optional `onTick` hook (see boss phases below), then
`checkVictoryConditions`.

## How a cast actually happens

1. Client: `InputController.selectTarget` calls
   `CombatController.castSpell(spellId, targetId)`, which fires
   `RequestCastSpell(sessionId, myCombatantId, spellId, targetId)`.
2. Server (`CombatRemotes`): rate-limits the request, looks up the session,
   and calls `CombatEngine.requestCastSpell(session, player, casterId,
   spellId, targetId)` -- passing the *actual* `Player` who sent the
   remote, not anything client-supplied.
3. `CombatValidator.validateCast` checks, in order: session is `Charging`;
   combatant exists; `combatant.player == requestingPlayer` (you can't act
   for someone else's combatant); combatant is alive and not mid-action;
   spell exists, is owned, and isn't on cooldown; effective AP cost is
   affordable; target satisfies the spell's `targetType`.
4. On success: AP is spent, `SpellResolver.resolveCast` rolls the outcome
   (weights adjusted by the caster's `CritChanceBonus`/`FailureResistance`
   stats) using the *session's* seeded `Random`, and applies every effect
   in the chosen outcome via `EffectSystem`.
5. The result is written to `session:log(...)`, which fires signals
   `CombatRemotes` is listening to; those push a throttled
   `CombatStateUpdated` snapshot and a `CombatLogEvent` to every player in
   the session.

No client input is ever treated as the outcome -- only as a request to
compute one.

## Data model & migrations

`DataSchema.newDefaults()` is the single source of truth for a profile's
shape (level/XP, currencies, stats, learned spells, skill tree, inventory/
equipment, PvE/PvP progress, reward ledger, monetization state, metadata).
`DataSchema.migrate(rawData)`:

1. Walks `DataSchema.Migrations[oldVersion + 1 .. CurrentVersion]`,
   applying each structural transform in order.
2. Reconciles the result against `newDefaults()` so newly-added leaf
   fields get sane defaults without every migration needing to set them
   individually.

To ship a schema change: update `newDefaults`, bump
`Shared/SchemaVersion.lua`, add one function to `DataSchema.Migrations`
keyed by the new version. Old migration steps are never deleted while any
live save could still be at that version.

`PlayerDataService` wraps this in DataStore `UpdateAsync` with a session
lock (`ActiveSession = {sessionId, lockedAt}`, stale after 30s) so a
player who reconnects to a different server mid-transition can't run two
copies of their profile at once; saves retry with backoff
(`Constants.DATASTORE_SAVE_RETRIES`), autosave runs every
`Constants.AUTO_SAVE_INTERVAL_SECONDS`, and `BindToClose` gives in-flight
saves up to 25s to finish before the process is killed.

## Extensibility hooks worth knowing about

- **New spell:** add an entry to `SpellCatalog`. No engine changes needed
  unless it truly needs bespoke logic (`customResolverId`, currently
  unused but reserved).
- **New tempo/support mechanic:** express it as one or more `EffectSpec`s
  using existing `EffectType`s (`GaugeModifier`, `ApModifier`,
  `ApCostModifier`, `StatModifier`, ...). Only add a new `EffectType` (and
  one `EffectSystem` branch) for a genuinely new *verb*.
- **New boss phase mechanic:** `CombatSession.config.onTick` is a generic
  per-tick hook mode services can attach without touching `CombatEngine`;
  see `BossEncounterService.buildPhaseWatcher` for the HP-threshold-enrage
  example.
- **New game mode:** build a roster of `Combatant.CombatantParams`
  (players via `CombatantFactory.fromPlayer`, NPCs via `.fromNpc`), call
  `CombatEngine.createSession(mode, roster, config)`. Everything else
  (gauge, AP, effects, validation, FSM) is already handled.
- **New monetized product:** add it to `ProductCatalog`; if it's
  progression-affecting, keep its magnitude at or under
  `Constants.MAX_MONETIZATION_ADVANTAGE` (25%) as `ExperienceService`
  clamps to that ceiling regardless.

## Security checklist (task requirement 17) and where it's handled

| Exploitable action | Where it's prevented |
| --- | --- |
| Fake damage/heal/AP/gauge | Only `EffectSystem`/`ActionGauge`/`ApManager` mutate these, only from server-rolled `SpellResolver` output |
| Fake spell ownership | `CombatValidator` checks `combatant.spellIdSet`, built server-side from `SpellbookService.ownsSpell` |
| Acting as another player's combatant | `CombatValidator` checks `combatant.player == requestingPlayer` |
| Acting out of turn / while resolving | `CombatValidator` checks `actionState` |
| Fake currency/rewards, duplicate claims | `RewardService` is ledger-keyed and idempotent; `MonetizationService` tracks `processedPurchaseIds` before confirming a receipt |
| Fake PvP results/rating | Rating/leaderboard/reward changes only happen in `PvPMatchService.handleMatchEnd`, driven by the session's own `onVictory`, never a client message |
| RemoteEvent/RemoteFunction spam | `Security/RateLimiter` token bucket per player per remote key |
| Purchase manipulation | Grants only happen from a real `MarketplaceService.ProcessReceipt` callback, gated on `processedPurchaseIds` |

## What's foundation vs. what's a documented next step

This is a foundational architecture, not a finished game. Deliberately
left as documented follow-ups rather than half-built abstractions:

- **Cross-server PvP matching.** `MatchmakingService` matches within a
  single server today; queue entries are already mirrored into a
  `MemoryStoreSortedMap` so a cross-server matchmaking coordinator (pair
  entries from different servers, reserve-teleport both players) can be
  added without changing how players join/leave the queue.
- **Team-rating math for >2-player PvP.** `RatingService` is pairwise Elo;
  a future team mode needs a team-rating algorithm, not a
  `PvPMatchService` rewrite.
- **Real Roblox asset IDs.** `ProductCatalog`'s developer product / game
  pass ids are placeholders -- swap in real Creator Dashboard ids before
  shipping.
- **Hand-authored UI.** `CombatUIController` proves the client-presents-
  server-state pattern; a real HUD/menu pass belongs under `StarterGui`
  per `UINotes.lua`.
