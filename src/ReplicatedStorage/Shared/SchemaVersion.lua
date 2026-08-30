--!strict
-- The current player-data schema version. Bump this whenever
-- DataSchema.Defaults shape changes, and add a migration step in
-- ServerScriptService/Data/DataSchema.lua's `Migrations` list that upgrades
-- from (n-1) to (n). Shared so debug tooling / admin commands on either
-- side can display "profile is on schema X".
return 1
