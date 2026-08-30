--!strict
-- Central tunable numbers so gameplay values never get hard-coded ad-hoc
-- inside feature scripts. Anything a designer might want to rebalance
-- belongs here (or in a Catalog module) instead of scattered literals.

local Constants = {}

-- Action Gauge / ATB tuning.
-- A combatant's gauge fills by `Speed * ACTION_GAUGE_RATE` every combat tick.
-- When the gauge crosses ACTION_GAUGE_THRESHOLD, it is consumed and the
-- combatant is granted ACTION_POINTS_PER_TICK Action Points (banked, up to
-- MAX_ACTION_POINTS).
Constants.COMBAT_TICK_RATE = 10 -- server combat ticks per second
Constants.ACTION_GAUGE_THRESHOLD = 1000
Constants.ACTION_GAUGE_RATE = 1 -- multiplied by Speed and dt
Constants.ACTION_POINTS_PER_TICK = 1
Constants.MAX_ACTION_POINTS = 6
Constants.BASE_SPEED = 100

-- Party / encounter sizing. Never hard-code player counts in gameplay code;
-- read them from here (or from an encounter's own override) instead.
Constants.DUNGEON_MIN_PLAYERS = 1
Constants.DUNGEON_MAX_PLAYERS = 4
Constants.BOSS_ENCOUNTER_MAX_PLAYERS = 8
Constants.PVP_MATCH_MAX_PLAYERS = 2

-- Progression curve. ExperienceService reads this rather than embedding a
-- formula many places.
Constants.XP_BASE = 100
Constants.XP_GROWTH = 1.12
Constants.MAX_CHARACTER_LEVEL = 100

-- PvP season defaults. SeasonService can override duration per-season
-- without touching the rating/leaderboard code.
Constants.SEASON_DURATION_DAYS = 30
Constants.PVP_STARTING_RATING = 1000
Constants.PVP_K_FACTOR = 32

-- Monetization guardrail: paid progression/convenience effects are capped
-- so no purchase can grant more than this fractional advantage over a
-- non-paying player (see design doc "no pay-to-win" guideline).
Constants.MAX_MONETIZATION_ADVANTAGE = 0.25

-- DataStore / persistence.
Constants.DATASTORE_NAME = "PlayerProfile_v1"
Constants.DATASTORE_SAVE_RETRIES = 5
Constants.DATASTORE_RETRY_BACKOFF_SECONDS = 2
Constants.AUTO_SAVE_INTERVAL_SECONDS = 120

-- Networking hygiene: never let a single client spam a remote faster than
-- this. Enforced by Security/RateLimiter.
Constants.DEFAULT_REMOTE_RATE_LIMIT_PER_SECOND = 10

return Constants
