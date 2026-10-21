--!strict
-- Group / like-goal / notification rewards: each claims once, only when eligible.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local src = fs.readFile("out/Server/AstralForge/Services/Gameplay/CommunityRewards.luau")
local C = (luau.load(src, { debugName = "CommunityRewards" }) :: any)()

local config = {
	GroupId = 123,
	GroupName = "Astral Forge",
	GroupReward = { Stardust = 40 },
	Likes = 600,
	LikeGoals = { { Likes = 100, Reward = { Stardust = 1 } }, { Likes = 500, Reward = { Stardust = 2 } }, { Likes = 1000, Reward = { Stardust = 3 } } },
	NotifyEnabled = false,
	NotifyReward = { Stardust = 5 },
}
local rewards: any = { CreatorFollowClaimed = false }

-- group: membership must be confirmed by the server, then only once
assert(not C.claim(rewards, "Group", 1, false, config).ok, "non-member can't claim")
assert(not C.claim(rewards, "Group", 1, nil, config).ok, "failed check can't claim")
assert(C.claim(rewards, "Group", 1, true, config).ok, "member claims")
assert(not C.claim(rewards, "Group", 1, true, config).ok, "group claims once")
assert(rewards.GroupClaimed == true)
local noGroup = table.clone(config)
noGroup.GroupId = 0
assert(not C.claim({}, "Group", 1, true, noGroup).ok, "no group configured")

-- like goals: only reached ones, each once, bad indices refused
assert(C.claim(rewards, "Like", 1, nil, config).ok)
assert(not C.claim(rewards, "Like", 1, nil, config).ok, "goal claims once")
assert(C.claim(rewards, "Like", 2, nil, config).ok)
assert(not C.claim(rewards, "Like", 3, nil, config).ok, "unreached goal refused")
assert(not C.claim(rewards, "Like", 9, nil, config).ok, "missing goal refused")
assert(not C.claim(rewards, "Like", "1", nil, config).ok, "non-number index refused")

-- notifications: off by default
assert(not C.claim(rewards, "Notify", 1, nil, config).ok, "notify reward off by default")
local on = table.clone(config)
on.NotifyEnabled = true
assert(C.claim(rewards, "Notify", 1, nil, on).ok)
assert(not C.claim(rewards, "Notify", 1, nil, on).ok, "notify claims once")
assert(not C.claim(rewards, "Nope", 1, nil, config).ok, "unknown kind refused")

local view = C.publicState(rewards, config)
assert(view.GroupClaimed == true and view.LikeGoals[1].Claimed and view.LikeGoals[2].Claimed and not view.LikeGoals[3].Claimed)
assert(C.publicState(nil, config).GroupClaimed == false, "missing save bag reads as unclaimed")

-- new save fields have template defaults
local template = fs.readFile("src/Server/AstralForge/DataTemplate.ts")
for _, key in { "GroupClaimed: false", "LikeGoals: {}", "NotifyClaimed: false" } do
	assert(template:find(key, 1, true), "DataTemplate default missing: " .. key)
end
print("verify_community_rewards: ok")
