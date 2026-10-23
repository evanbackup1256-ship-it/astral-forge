// The art was re-uploaded as Images on 2026-10-23 (assets/upload image_ids.json) and the sources
// point at those; this decal table stays as a fallback for any decal id that comes back.
// Purpose: the 2026-10 UI art was uploaded through Open Cloud as Decals. An ImageLabel cannot draw a
// Decal id ("Asset type does not match"), so the server loads each decal once at boot, reads the
// Image id inside it and publishes it on ReplicatedStorage. art() swaps a decal url for that image,
// or for the pre-revamp image when one exists, so nothing renders as a broken asset.
// resolved lazily: pure test harnesses load this module without a DataModel
function store(): ReplicatedStorage | undefined {
	const [ok, service] = pcall(() => game.GetService("ReplicatedStorage"));
	return ok ? service : undefined;
}

export const UI_ART_READY = "UiArtReady";

/** decal ids that need resolving -> image to draw while unresolved ("" keeps the decal url) */
export const UI_ART_DECALS: Record<string, string> = {
	// icon atlas A has the same 8x8 layout as the old flaticon atlas
	"105262447644762": "rbxassetid://139083324249955",
	"115863993090062": "",
	"137100865466961": "rbxassetid://93834740732329",
	"126797903300109": "rbxassetid://94028186779182",
	"82657390275902": "",
	"72852035944524": "",
	"132832534777726": "",
	"129306695928995": "",
	"140334966513714": "",
	"91615259534204": "",
	"79586395880216": "",
	"77379807257881": "",
	"73472877278952": "",
	"132294712138207": "",
	"96721820700576": "",
	"102982024064892": "",
	"112367869722042": "",
	"92141659344017": "",
	"125440001868646": "",
	"111706636066465": "",
};

export function artAttribute(id: string) {
	return "UiArt_" + id;
}

/** Image a GuiObject can draw for this content id (decal ids resolve to their image). */
export function art(url: string): string {
	const [digits] = string.match(url, "%d+$");
	if (digits === undefined) return url;
	const id = tostring(digits);
	const fallback = UI_ART_DECALS[id];
	if (fallback === undefined) return url;
	const resolved = store()?.GetAttribute(artAttribute(id));
	if (typeIs(resolved, "string") && resolved !== "") return resolved;
	return fallback !== "" ? fallback : url;
}

/** Client: wait (bounded) for the server to publish the resolved images before UI modules load. */
export function awaitUiArt(timeout: number) {
	const started = os.clock();
	while (store()?.GetAttribute(UI_ART_READY) !== true && os.clock() - started < timeout) {
		task.wait(0.1);
	}
}
