--!strict

local root = script.Parent
assert(root:IsA("ModuleScript"), "Reflex package root must be a ModuleScript")

return require(root)
