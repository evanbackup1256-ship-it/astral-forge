// TeleportFlush: who is safe to teleport during a soft shutdown (audit follow-up).
// A player may only be sent to a new server once this server has released their save session;
// otherwise the new server finds the session still locked (or loads a stale save). The shutdown
// release pass can time out or fail for some profiles, so before the group teleport each player
// whose profile is still held gets one more release save; anyone still held stays here and
// Roblox's own shutdown keeps retrying their release instead of teleporting them early.

export interface FlushDeps<P extends defined> {
	/** true while this server still holds the player's save session */
	held: (this: void, player: P) => boolean;
	/** a release save; true when the session was released */
	release: (this: void, player: P) => boolean;
}

export function flushBeforeTeleport<P extends defined>(players: ReadonlyArray<P>, deps: FlushDeps<P>, attempts = 1): { ready: P[]; held: P[] } {
	const ready: P[] = [];
	const held: P[] = [];
	for (const player of players) {
		let still = deps.held(player);
		for (let attempt = 0; still && attempt < attempts; attempt++) {
			pcall(() => deps.release(player));
			still = deps.held(player);
		}
		if (still) held.push(player);
		else ready.push(player);
	}
	return { ready, held };
}
