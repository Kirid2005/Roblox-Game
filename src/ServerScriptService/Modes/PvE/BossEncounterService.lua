--!strict
-- Thin layer on top of DungeonService specifically for boss content: it
-- reuses the exact same combat engine and encounter pipeline (nothing
-- here is a separate combat system) and adds HP-threshold phase triggers
-- as an example of extending boss behavior purely through the generic
-- EffectSystem plus CombatSession's `onTick` extension point -- no
-- changes to CombatEngine were needed to add this.
--
-- Player-count limits come from the EncounterDef (see EncounterCatalog),
-- not a hard-coded 8; Constants.BOSS_ENCOUNTER_MAX_PLAYERS is only the
-- suggested default new boss encounters should use when authoring one.

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Enums = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Enums"))

local EncounterCatalog = require(ServerStorage:WaitForChild("GameData"):WaitForChild("EncounterCatalog"))

local ServerScriptService = game:GetService("ServerScriptService")
local CombatSession = require(ServerScriptService:WaitForChild("Combat"):WaitForChild("CombatSession"))
local EffectSystem = require(ServerScriptService:WaitForChild("Combat"):WaitForChild("EffectSystem"))

local DungeonService = require(script.Parent:WaitForChild("DungeonService"))

local BossEncounterService = {}

export type PhaseThreshold = {
	healthPercent: number, -- trigger once boss HP falls at/below this fraction
	triggered: boolean,
}

-- Builds an `onTick` callback that watches every Beta-team (enemy)
-- combatant and, the first time its HP crosses a threshold, buffs it
-- (a simple "enrage" -- more Power, expressed with the same generic
-- StatModifier effect every spell uses). New phase behaviors are added by
-- extending this table/callback, never by touching combat internals.
local function buildPhaseWatcher(): (session: CombatSession.CombatSessionObject) -> ()
	local thresholds: { PhaseThreshold } = {
		{ healthPercent = 0.5, triggered = false },
		{ healthPercent = 0.25, triggered = false },
	}

	return function(session: CombatSession.CombatSessionObject)
		for _, combatant in session:getRoster() do
			if combatant.teamId == Enums.TeamId.Beta and combatant:isAlive() then
				local maxHealth = combatant:getEffectiveStat(Enums.StatId.MaxHealth, session.currentTick)
				if maxHealth > 0 then
					local fraction = combatant.currentHealth / maxHealth
					for _, threshold in thresholds do
						if not threshold.triggered and fraction <= threshold.healthPercent then
							threshold.triggered = true
							EffectSystem.applyEffectSpec(
								{
									type = Enums.EffectType.StatModifier,
									target = "Caster", -- resolved relative to `caster` below, i.e. the boss itself
									stat = Enums.StatId.Power,
									amount = 0.25,
									percent = true,
									duration = math.huge,
								},
								combatant, -- acting as its own "caster" for a self-applied phase buff
								nil,
								session:getRoster(),
								session.currentTick,
								session.rng
							)
							session:log("Info", { message = `{combatant.displayName} enters an enraged phase!`, combatantId = combatant.id })
						end
					end
				end
			end
		end
	end
end

function BossEncounterService.startBossEncounter(players: { Player }, encounterId: string): (CombatSession.CombatSessionObject?, DungeonService.StartFailureReason?)
	local encounterDef = EncounterCatalog[encounterId]
	assert(encounterDef and encounterDef.isBossEncounter, `BossEncounterService: "{encounterId}" is not a boss encounter`)

	return DungeonService.startEncounter(players, encounterId, { onTick = buildPhaseWatcher() })
end

return BossEncounterService
