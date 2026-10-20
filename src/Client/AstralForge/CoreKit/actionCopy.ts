export const PLAYER_COPY: Record<string, string> = {
	["that request could not be validated."]: "That didn't go through. Try again.",
	["the server is still finishing an earlier request."]: "Still working on your last tap.",
	["the connection is busy. try again in a moment."]: "Things are a little busy. Try again in a moment.",
	["the server took too long. try again."]: "That took too long. Try again.",
	["the server did not answer that click."]: "That tap didn't go through. Try again.",
	["action rejected."]: "That move isn't available right now.",
	["malformed admin request."]: "Check the command fields and try again.",
	["invalid action payload"]: "That option isn't available.",
	["invalid action payload."]: "That option isn't available.",
	["the forge encountered an error. please try again."]: "Something broke on our end. Give it another go.",
	["the forge returned an invalid response. please try again."]: "That didn't go through. Try again.",
	["request rejected."]: "That move isn't available right now.",
	["payload is required"]: "That option isn't available.",
	["payload must be a table"]: "That option isn't available.",
	["this action does not accept a payload"]: "That option isn't available.",
	["invalid expedition"]: "Pick an expedition first.",
	["invalid artifact"]: "Choose an artifact first.",
	["invalid signal offer"]: "That signal offer isn't available.",
	["invalid title selection"]: "Choose a title to wear.",
	["invalid boost selection"]: "Choose a boost to activate.",
	["invalid shop offer"]: "That shop offer isn't available.",
	["invalid protocol"]: "That protocol isn't available.",
	["invalid reactor channel"]: "Pick a reactor channel.",
	["invalid story chapter"]: "That chapter isn't available.",
	["invalid mail"]: "That message isn't available.",
	["invalid guild upgrade"]: "That guild upgrade isn't available.",
	["invalid follow verification payload"]: "Couldn't check that follow.",
	["invalid code payload"]: "Enter a code first.",
	["invalid upgrade payload"]: "Choose an upgrade and try again.",
	["invalid claim payload"]: "That reward isn't ready to claim.",
	["invalid reward payload"]: "That reward isn't ready to claim.",
	["invalid progression payload"]: "That level isn't ready yet.",
	["invalid world payload"]: "That world isn't available yet.",
	["remote traffic paused briefly. please try again."]: "Easy, that was a lot of taps. Give it a second.",
	["your profile is not ready. please try again."]: "Your save is still loading. Try again in a moment.",
	["feedback isn't set up yet. please try again later."]: "Feedback isn't open yet. Check back later.",
	["please slow down for a moment."]: "Easy there. Give it a second.",
	["the server is still starting. please retry in a moment."]: "The server's still warming up. Try again in a moment.",
	["this trade hit an error and has to be cancelled."]: "Something went wrong with this trade, so it's been called off.",
	["relic id is invalid or inventory is full."]: "Your relic bag might be full. Make some room and try again.",
	["that machine cannot be queued."]: "That station can't be queued right now.",
	["target must be online in this server."]: "They need to be in this server for that.",
	["guild request was denied."]: "The guild turned that down.",
	["that code is invalid or already used."]: "That code doesn't work, or it's already been used.",
	["relic recycler is required for auto-salvage."]: "You'll need the Relic Recycler before auto-salvage works.",
	["an auto-salvage rarity is invalid."]: "Pick the rarities to salvage again.",
	["the relic selection is invalid."]: "Pick the relics again. Something changed.",
	["that request is already open."]: "You've already asked for that.",
	["there is no open request to cancel."]: "There's nothing to cancel.",
	["that player has no open supply request."]: "They don't need anything right now.",
	["that supply cannot be requested."]: "That supply can't be requested.",
};

export const INTERNAL_PAYLOAD_COPY: Record<string, true> = {
	["invalid action payload"]: true,
	["invalid action payload."]: true,
	["payload is required"]: true,
	["payload must be a table"]: true,
	["this action does not accept a payload"]: true,
	["that option isn't available."]: true,
	["that option isn't available"]: true,
	["check that choice and try again."]: true,
	["check that choice and try again"]: true,
	["that request could not be validated."]: true,
	["that request could not be validated"]: true,
	["that didn't go through. try again."]: true,
	["that didn't go through. try again"]: true,
};

export const FAILURE_TITLE_PREFIXES: ReadonlyArray<[prefix: string, title: string]> = [
	["Claim", "Couldn't claim"],
	["Buy", "Couldn't buy"],
	["Upgrade", "Couldn't upgrade"],
	["Unlock", "Couldn't unlock"],
	["Equip", "Couldn't equip"],
	["Unequip", "Couldn't unequip"],
	["Salvage", "Couldn't salvage"],
	["Set", "Couldn't update"],
	["Toggle", "Couldn't update"],
	["Start", "Couldn't start"],
	["Launch", "Couldn't launch"],
	["Join", "Couldn't join"],
	["Leave", "Couldn't leave"],
	["Create", "Couldn't create"],
	["Invite", "Couldn't invite"],
	["Respond", "Trade didn't go through"],
	["Confirm", "Trade didn't go through"],
	["Cancel", "Trade didn't go through"],
	["Update", "Trade didn't go through"],
	["Contribute", "Couldn't contribute"],
	["Kick", "Couldn't remove them"],
	["Report", "Couldn't send that"],
	["Redeem", "Couldn't redeem"],
	["Spin", "Couldn't spin"],
	["Select", "Couldn't travel"],
	["Route", "Couldn't route power"],
	["Stabilize", "Couldn't stabilize"],
	["Pulse", "Couldn't pulse"],
	["Capture", "Couldn't capture"],
	["Dismantle", "Couldn't dismantle"],
	["Open", "Couldn't open"],
	["Read", "Couldn't open"],
	["Delete", "Couldn't delete"],
	["Rebirth", "Couldn't rebirth"],
	["Verify", "Couldn't check that"],
];

export const FAILURE_BODY_BY_ACTION: Record<string, string> = {
	LaunchExpedition: "Pick an expedition first.",
	ClaimExpedition: "That expedition isn't back yet.",
	EquipArtifact: "Choose an artifact to equip.",
	UpgradeArtifact: "Choose an artifact to upgrade.",
	BuyArtifact: "Choose an artifact to buy.",
	BuySignalOffer: "That signal offer isn't available.",
	EquipTitle: "Choose a title to wear.",
	SetProfileStyle: "Pick an accent and frame for your profile.",
	ActivateBoost: "Choose a boost to activate.",
	BuyItemOffer: "That shop offer isn't available.",
	BuyDailyOffer: "That daily offer isn't available.",
	BuyCrateSkin: "That skin isn't for sale.",
	EquipCrateSkin: "You don't own that skin.",
	FuseRelics: "Those relics can't be fused.",
	BuyAnomalyProtocol: "That protocol isn't available.",
	SetAnomalyChannel: "Pick a reactor channel.",
	ReadStoryChapter: "That chapter isn't available.",
	ClaimStoryChapter: "That chapter isn't ready to claim.",
	ReadMail: "That message isn't available.",
	ClaimMail: "That mail isn't ready to claim.",
	DeleteMail: "That message isn't available.",
	BuyGuildUpgrade: "That guild upgrade isn't available.",
	BuyMachine: "That station isn't available.",
	BuyResearch: "That research isn't available.",
	Overcharge: "That station isn't ready to overcharge.",
	CollectVault: "Nothing to collect yet.",
	Rebirth: "You aren't ready to rebirth yet.",
	VerifyCreatorFollow: "Couldn't check that follow.",
	RedeemCode: "Enter a code first.",
};

export function friendlyPlayerMessage(value: string | undefined): string | undefined {
	if (value === undefined || value.size() === 0) {
		return undefined;
	}
	const exact = PLAYER_COPY[value] ?? PLAYER_COPY[value.lower()];
	if (exact !== undefined) {
		return exact;
	}
	const lowered = value.lower();
	// the chat filter turned it down
	if (lowered.find("please try different wording", 1, true)[0] !== undefined) {
		return "The filter didn't like that wording. Try saying it another way.";
	}
	// leftover server shorthand ("Invalid mission request.", "Mission not found.", "Unknown boost id.")
	if (lowered.sub(1, 8) === "invalid " || (lowered.sub(1, 8) === "unknown " && lowered.find(" id", 1, true)[0] !== undefined)) {
		return "That isn't available right now. It may have just changed.";
	}
	if (lowered.find(" not found", 1, true)[0] !== undefined && lowered.find("admin", 1, true)[0] === undefined) {
		return "Couldn't find that one. It may have just changed.";
	}
	return value;
}

export function failureTitle(action: string, gated?: boolean): string {
	if (gated) {
		return "Still locked";
	}
	if (action === "VerifyCreatorFollow") {
		return "Follow";
	}
	for (const [prefix, title] of FAILURE_TITLE_PREFIXES) {
		if (action.sub(1, prefix.size()) === prefix) {
			return title;
		}
	}
	return "That didn't work";
}

export function failureBody(action: string, raw: string): string {
	const lowered = raw.lower();
	if (INTERNAL_PAYLOAD_COPY[lowered] !== undefined) {
		return FAILURE_BODY_BY_ACTION[action] ?? "That option isn't available.";
	}
	return friendlyPlayerMessage(raw) ?? raw;
}

export interface ActionResponse {
	message?: string;
	error?: string;
	[key: string]: unknown;
}

export function friendlyActionResponse<T extends ActionResponse>(response: T): T {
	const message = friendlyPlayerMessage(response.message);
	const friendlyError = friendlyPlayerMessage(response.error);
	if (message === response.message && friendlyError === response.error) {
		return response;
	}
	const cloned = table.clone(response);
	setmetatable(cloned, undefined as unknown as LuaMetatable<T>);
	cloned.message = message;
	cloned.error = friendlyError;
	return cloned;
}
