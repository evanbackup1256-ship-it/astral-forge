--!strict

return function()


	local ProfileIntegrity = {}

	local MOD_ADLER = 65521
	local JOURNAL_LIMIT = 12
	local MAX_NODES = 24000
	local ALGORITHM = "AFX-ADLER32-V1"

	local function finite(value: any): boolean
		return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
	end

	local function copy(value: any)
		if type(value) ~= "table" then return value end
		local result = {}
		for key, child in value do result[copy(key)] = copy(child) end
		return result
	end

	local function orderedKeys(source): { any }
		local keys = {}
		for key in source do table.insert(keys, key) end
		table.sort(keys, function(left, right)
			local leftType, rightType = type(left), type(right)
			if leftType ~= rightType then return leftType < rightType end
			if leftType == "number" then return left < right end
			return tostring(left) < tostring(right)
		end)
		return keys
	end

	local function feed(state, text: string)
		for index = 1, #text do
			state.A = (state.A + string.byte(text, index)) % MOD_ADLER
			state.B = (state.B + state.A) % MOD_ADLER
		end
	end

	local function digestValue(state, value: any, depth: number, parentKey: string?)
		state.Nodes += 1
		if state.Nodes > MAX_NODES or depth > 18 then
			error("profile exceeds integrity traversal budget")
		end
		local kind = type(value)
		if kind == "nil" then feed(state, "n;")
		elseif kind == "boolean" then feed(state, value and "b1;" or "b0;")
		elseif kind == "number" then
			if not finite(value) then error("profile contains a non-finite number") end
			feed(state, "d" .. string.format("%.17g", value) .. ";")
		elseif kind == "string" then
			feed(state, "s" .. tostring(#value) .. ":" .. value .. ";")
		elseif kind == "table" then
			feed(state, "{")
			for _, key in orderedKeys(value) do

				local excluded = parentKey == "Meta" and (key == "Integrity" or key == "Transactions")
				if not excluded then
					digestValue(state, key, depth + 1, nil)
					digestValue(state, value[key], depth + 1, type(key) == "string" and key or nil)
				end
			end
			feed(state, "}")
		else
			error("profile contains unsupported value type " .. kind)
		end
	end

	function ProfileIntegrity.Hash(value: any): string
		local state = { A = 1, B = 0, Nodes = 0 }
		digestValue(state, value, 0, nil)
		return string.format("%08x", state.B * 65536 + state.A)
	end

	local function criticalSnapshot(profile)
		return {
			Cash = profile.Cash,
			Vault = profile.Vault,
			Cores = profile.Cores,
			Stardust = profile.Stardust,
			Rebirths = profile.Rebirths,
			RunCash = profile.RunCash,
			LifetimeCash = profile.LifetimeCash,
			Zone = profile.Zone,
			CurrentZone = profile.CurrentZone,
			Domain = copy(profile.Domain),
			Continuum = copy(profile.Continuum),
			Machines = copy(profile.Machines),
			Research = copy(profile.Research),
			GridUpgrades = copy(profile.GridUpgrades),
			BoostInventory = copy(profile.BoostInventory),
			Items = {
				NextId = profile.Items and profile.Items.NextId or 1,
				Essence = profile.Items and profile.Items.Essence or 0,
				Keys = copy(profile.Items and profile.Items.Keys or {}),
			},
			Anomaly = {
				Fragments = profile.Anomaly and profile.Anomaly.Fragments or 0,
				Stabilizations = profile.Anomaly and profile.Anomaly.Stabilizations or 0,
			},
		}
	end

	local function applyCriticalSnapshot(profile, snapshot)
		for _, key in {
			"Cash", "Vault", "Cores", "Stardust", "Rebirths", "RunCash", "LifetimeCash",
			"Zone", "CurrentZone", "Domain", "Continuum", "Machines", "Research", "GridUpgrades", "BoostInventory",
		} do
			if snapshot[key] ~= nil then profile[key] = copy(snapshot[key]) end
		end
		if type(snapshot.Items) == "table" and type(profile.Items) == "table" then
			profile.Items.NextId = snapshot.Items.NextId or profile.Items.NextId
			profile.Items.Essence = snapshot.Items.Essence or profile.Items.Essence
			profile.Items.Keys = copy(snapshot.Items.Keys or profile.Items.Keys)
		end
		if type(snapshot.Anomaly) == "table" and type(profile.Anomaly) == "table" then
			profile.Anomaly.Fragments = snapshot.Anomaly.Fragments or profile.Anomaly.Fragments
			profile.Anomaly.Stabilizations = snapshot.Anomaly.Stabilizations or profile.Anomaly.Stabilizations
		end
	end

	function ProfileIntegrity.EnsureEnvelope(profile)
		profile.Meta = type(profile.Meta) == "table" and profile.Meta or {}
		profile.Meta.Integrity = type(profile.Meta.Integrity) == "table" and profile.Meta.Integrity or {
			Algorithm = ALGORITHM,
			Hash = "",
			SealedRevision = 0,
			SealedAt = 0,
		}
		profile.Meta.Transactions = type(profile.Meta.Transactions) == "table" and profile.Meta.Transactions or {}
		return profile
	end

	function ProfileIntegrity.Seal(profile): string
		ProfileIntegrity.EnsureEnvelope(profile)
		local hash = ProfileIntegrity.Hash(profile)
		profile.Meta.Integrity = {
			Algorithm = ALGORITHM,
			Hash = hash,
			SealedRevision = math.max(0, math.floor(tonumber(profile.Meta.Revision) or 0)),
			SealedAt = os.time(),
		}
		return hash
	end

	function ProfileIntegrity.Record(profile, label: string, revision: number?)
		ProfileIntegrity.EnsureEnvelope(profile)
		local snapshot = criticalSnapshot(profile)
		local entry = {
			Id = string.format("%d:%d", os.time(), math.max(0, math.floor(revision or 0))),
			At = os.time(),
			Revision = math.max(0, math.floor(revision or 0)),
			Label = string.sub(label ~= "" and label or "mutation", 1, 64),
			Snapshot = snapshot,
			Hash = ProfileIntegrity.Hash(snapshot),
		}
		table.insert(profile.Meta.Transactions, entry)
		while #profile.Meta.Transactions > JOURNAL_LIMIT do table.remove(profile.Meta.Transactions, 1) end
		return entry
	end

	function ProfileIntegrity.VerifyAndRecover(profile): (boolean, string)
		ProfileIntegrity.EnsureEnvelope(profile)
		local envelope = profile.Meta.Integrity
		if envelope.Algorithm ~= ALGORITHM or type(envelope.Hash) ~= "string" or envelope.Hash == "" then
			local sealed = pcall(ProfileIntegrity.Seal, profile)
			if not sealed then
				return false, "legacy profile structure is invalid; schema recovery required"
			end
			return true, "sealed legacy profile"
		end
		local ok, current = pcall(ProfileIntegrity.Hash, profile)
		if ok and current == envelope.Hash then return true, "verified" end

		local journal = profile.Meta.Transactions
		for index = #journal, 1, -1 do
			local entry = journal[index]
			if type(entry) == "table" and type(entry.Snapshot) == "table" and type(entry.Hash) == "string" then
				local snapshotOk, snapshotHash = pcall(ProfileIntegrity.Hash, entry.Snapshot)
				if snapshotOk and snapshotHash == entry.Hash then
					applyCriticalSnapshot(profile, entry.Snapshot)
					local sealed = pcall(ProfileIntegrity.Seal, profile)
					if not sealed then
						return false, "transaction recovered critical state; schema recovery still required"
					end
					return false, "recovered critical state from transaction " .. tostring(entry.Id)
				end
			end
		end
		local sealed = pcall(ProfileIntegrity.Seal, profile)
		if not sealed then
			return false, "integrity mismatch; profile structure requires schema recovery"
		end
		return false, "integrity mismatch; no valid recovery entry"
	end

	function ProfileIntegrity.Status(profile)
		ProfileIntegrity.EnsureEnvelope(profile)
		local envelope = profile.Meta.Integrity
		return {
			Algorithm = envelope.Algorithm,
			Hash = envelope.Hash,
			SealedRevision = envelope.SealedRevision,
			SealedAt = envelope.SealedAt,
			JournalDepth = #profile.Meta.Transactions,
		}
	end

	return table.freeze(ProfileIntegrity)
end
