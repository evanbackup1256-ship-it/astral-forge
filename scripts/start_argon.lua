--!lua
local process = require("process")

local stdout = io.open("argon-serve.stdout.log", "w")
local stderr = io.open("argon-serve.stderr.log", "w")

local handle, err = process.spawn({
	"argon",
	"serve",
	"default.project.json",
}, {
	stdout = stdout,
	stderr = stderr,
	detached = true,
})

if not handle then
	error("failed to start argon serve: " .. tostring(err))
end

print("started argon serve pid " .. tostring(handle.pid))
print("logs: argon-serve.stdout.log, argon-serve.stderr.log")

handle:close()
stdout:close()
stderr:close()
