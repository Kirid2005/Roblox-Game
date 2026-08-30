--!strict
-- This project builds its HUD at runtime (see
-- StarterPlayer/StarterPlayerScripts/UI/CombatUIController.lua) instead of
-- hand-authoring GUI instances that would need to live under StarterGui as
-- binary/JSON instance data. StarterGui is kept in the project tree (and
-- mapped in default.project.json) as the correct home for future
-- hand-authored menus -- start screen, inventory, skill tree browser -- as
-- the UI pass matures past the functional placeholder stage described in
-- task requirement 18.
return nil
