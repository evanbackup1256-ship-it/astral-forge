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
	["the forge encountered an error. please try again."]: "Something went wrong. Please try again.",
	["the forge returned an invalid response. please try again."]: "That didn't go through. Please try again.",
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
	["Respond", "Trade issue"],
	["Confirm", "Trade issue"],
	["Cancel", "Trade issue"],
	["Update", "Trade issue"],
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
	["Verify", "Follow"],
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
	return "Couldn't do that";
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
