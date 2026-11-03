// Who has the stage. A foreground motion (a page transition, an overlay opening) takes the stage for a
// moment with beginFocus(); ambient motion (idle glints) asks isFocused() and waits its turn, so the
// move that matters is the one that reads. No imports on purpose: the core motion module uses it.
let stageUntil = 0;

export function beginFocus(seconds: number): void {
	stageUntil = math.max(stageUntil, os.clock() + seconds);
}

export function isFocused(): boolean {
	return os.clock() < stageUntil;
}
