--!strict
-- Astral Forge v2: Gamepad Navigation & Omni-Platform Focus Management
-- Bridges CoreKit GamepadNavigationService with D-pad / thumbstick selection,
-- overlay stack isolation, virtual cursor suppression, and TV safe insets.

local CoreKit = require(script.Parent.Parent.CoreKit)
local GamepadNavigationService = CoreKit("GamepadNavigationService")

return GamepadNavigationService

