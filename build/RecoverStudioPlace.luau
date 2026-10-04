-- Preserve an existing Studio recovery place and apply only this repair's scripts.
-- Usage: lune run build/RecoverStudioPlace.luau <input.rbxl> <new-output.rbxl>
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local input, output = process.args[1], process.args[2]
assert(input and output and input ~= output, "Provide separate input and output paths")
assert(not fs.isFile(output), "Recovery output already exists; choose a new path")
local original = fs.readFile(input)
local root = roblox.deserializePlace(original)
local changes = {
	{ "src/Client/AstralForge/ClientRuntime.luau", "StarterPlayer.StarterPlayerScripts.AstralForge.ClientRuntime" },
	{ "src/Client/AstralForge/CoreKit.luau", "StarterPlayer.StarterPlayerScripts.AstralForge.CoreKit" },
	{ "src/Client/AstralForge/MotionKit.luau", "StarterPlayer.StarterPlayerScripts.AstralForge.MotionKit" },
	{ "src/Client/AstralForge/pages/PageRouter.luau", "StarterPlayer.StarterPlayerScripts.AstralForge.pages.PageRouter" },
	{ "src/Client/AstralForge/pages/PagesBazaar.luau", "StarterPlayer.StarterPlayerScripts.AstralForge.pages.PagesBazaar" },
	{ "src/Client/AstralForge/pages/PagesCasino.luau", "StarterPlayer.StarterPlayerScripts.AstralForge.pages.PagesCasino" },
	{ "src/Client/AstralForge/pages/PagesSocial.luau", "StarterPlayer.StarterPlayerScripts.AstralForge.pages.PagesSocial" },
	{ "src/Client/AstralForge/pages/PagesStory.luau", "StarterPlayer.StarterPlayerScripts.AstralForge.pages.PagesStory" },
	{ "src/Shared/AstralForge/Shared/GameConfig.luau", "ReplicatedStorage.AstralForge.Shared.GameConfig" },
	{ "src/Server/AstralForge/ReleaseReadiness.luau", "ServerScriptService.AstralForge.ReleaseReadiness" },
}
local function find(path)
	local target = root
	for name in string.gmatch(path, "[^.]+") do
		target = assert(target:FindFirstChild(name), "Missing recovery instance " .. path)
	end
	return target
end
local function normalize(source) return (string.gsub(source, "\r\n", "\n")) end
local expected, replacements = {}, {}
local function replace(target, source, path)
	assert(replacements[target.Source] == nil, "Ambiguous recovery script source " .. path)
	replacements[target.Source] = { source = source, path = path, found = 0 }
end
for _, change in changes do
	local source = normalize(fs.readFile(change[1]))
	replace(find(change[2]), source, change[2])
	expected[change[2]] = source
end
local story = assert(find("ServerStorage.AstralForgeStories.Pages"):FindFirstChild("ChatView.story"))
local storySource = normalize(fs.readFile("src/Stories/Pages/ChatView.story.luau"))
replace(story, storySource, "ChatView.story")
local instanceCount = #root:GetDescendants()
-- Replace only Source property payloads. Keep every other binary chunk verbatim,
-- including newer terrain properties that Lune cannot deserialize yet.
local function u32(value)
	local bytes = buffer.create(4)
	buffer.writeu32(bytes, 0, value)
	return buffer.tostring(bytes)
end
local bytes = buffer.fromstring(original)
local chunks = { string.sub(original, 1, 32) }
local position, unchangedChunks = 32, 0
while position < #original do
	assert(position + 16 <= #original, "Truncated place chunk header")
	local tag = buffer.readstring(bytes, position, 4)
	local compressed = buffer.readu32(bytes, position + 4)
	local plain = buffer.readu32(bytes, position + 8)
	local length = if compressed > 0 then compressed else plain
	assert(position + 16 + length <= #original, "Truncated place chunk")
	local raw = buffer.readstring(bytes, position, 16 + length)
	local rewritten = false
	if tag == "PROP" then
		local body = buffer.readstring(bytes, position + 16, length)
		if compressed > 0 then body = serde.decompress("zstd", body) end
		assert(#body == plain, "Property chunk decompressed size mismatch")
		local payload = buffer.fromstring(body)
		local nameLength = buffer.readu32(payload, 4)
		local name = buffer.readstring(payload, 8, nameLength)
		if name == "Source" then
			assert(buffer.readu8(payload, 8 + nameLength) == 1, "Unsupported source property encoding")
			local cursor = 9 + nameLength
			local pieces = { string.sub(body, 1, cursor) }
			while cursor < #body do
				local size = buffer.readu32(payload, cursor)
				local source = buffer.readstring(payload, cursor + 4, size)
				cursor += 4 + size
				local replacement = replacements[source]
				if replacement then
					replacement.found += 1
					source = replacement.source
				end
				table.insert(pieces, u32(#source) .. source)
			end
			assert(cursor == #body, "Invalid source payload length")
			local updated = table.concat(pieces)
			-- Roblox accepts uncompressed chunks when compressed length is zero.
			raw = tag .. u32(0) .. u32(#updated) .. buffer.readstring(bytes, position + 12, 4) .. updated
			rewritten = true
		end
	end
	if not rewritten then unchangedChunks += 1 end
	table.insert(chunks, raw)
	position += 16 + length
end
for _, replacement in replacements do
	assert(replacement.found == 1, replacement.path .. " must match exactly one recovery source")
end
local encoded = table.concat(chunks)
-- Verify script contents and instance count without reserializing the model.
root = roblox.deserializePlace(encoded)
assert(#root:GetDescendants() == instanceCount, "Recovery instance count changed")
for path, source in expected do assert(normalize(find(path).Source) == source, path .. " did not round-trip") end
assert(normalize(find("ServerStorage.AstralForgeStories.Pages"):FindFirstChild("ChatView.story").Source) == storySource)
fs.writeFile(output, encoded)
print("[RECOVERY] verified 11 fixed scripts; preserved " .. instanceCount .. " instances and " .. unchangedChunks .. " non-source chunks verbatim; wrote " .. output)
