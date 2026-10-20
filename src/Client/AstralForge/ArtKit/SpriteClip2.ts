const RunService = game.GetService("RunService");

type SpriteSignal = "PlayCalled" | "PauseCalled" | "StopCalled" | "FrameChanged" | "FrameLast" | "Looped";

export interface ImageSpriteProps {
	adornee: ImageLabel | ImageButton;
	blendAdornee?: ImageLabel | ImageButton;
	spriteSheetId: string;
	spriteSize: Vector2;
	spriteOffset?: Vector2;
	edgeOffset?: Vector2;
	spriteCount: number;
	columnCount: number;
	frameRate: number;
	isLooped: boolean;
	getOpacity?: () => number;
	currentFrame?: number;
}

const scheduled = new Map<SpriteClipImageSprite, number>();
let schedulerConnection: RBXScriptConnection | undefined;

function stopSchedulerIfIdle() {
	if (scheduled.size() > 0 || schedulerConnection === undefined) {
		return;
	}
	schedulerConnection.Disconnect();
	schedulerConnection = undefined;
}

function unschedule(sprite: SpriteClipImageSprite) {
	scheduled.delete(sprite);
	stopSchedulerIfIdle();
}

function ensureScheduler() {
	if (schedulerConnection !== undefined) {
		return;
	}
	schedulerConnection = RunService.RenderStepped.Connect((deltaTime) => {
		scheduled.forEach((carried, sprite) => {
			if (!sprite.isPlaying) {
				scheduled.delete(sprite);
				return;
			}
			// looped clips that can't be seen hold their frame; one-shots keep running so their
			// FrameLast / Looped signals still fire on time
			if (sprite.loops() && !sprite.onScreen()) {
				return;
			}
			const step = 1 / math.max(1, sprite.frameRate);
			const elapsed = carried + math.min(deltaTime, 0.25);
			const due = math.floor(elapsed / step);
			if (due <= 0) {
				scheduled.set(sprite, elapsed);
				sprite.RenderSubframe(elapsed / step);
				return;
			}
			const remainder = elapsed % step;
			const advances = math.min(due, sprite.spriteCount);
			if (advances <= 2) {
				for (let index = 0; index < advances && sprite.isPlaying; index++) {
					sprite.Advance();
				}
			} else {
				sprite.AdvanceBy(advances);
			}
			if (sprite.isPlaying) {
				scheduled.set(sprite, remainder);
				sprite.RenderSubframe(remainder / step);
			} else {
				sprite.RenderSubframe(0);
			}
		});
		stopSchedulerIfIdle();
	});
}

function computeOnScreen(image: GuiObject | undefined): boolean {
	if (image === undefined || !image.IsDescendantOf(game)) {
		return false;
	}
	let node: Instance | undefined = image;
	while (node !== undefined) {
		if (node.IsA("GuiObject") && !node.Visible) {
			return false;
		}
		if (node.IsA("LayerCollector")) {
			if (!node.Enabled) {
				return false;
			}
			if (!node.IsA("ScreenGui")) {
				// surface/billboard space: screen bounds don't apply
				return true;
			}
			break;
		}
		node = node.Parent;
	}
	const camera = game.GetService("Workspace").CurrentCamera;
	if (camera === undefined) {
		return true;
	}
	const position = image.AbsolutePosition;
	const size = image.AbsoluteSize;
	const viewport = camera.ViewportSize;
	return position.X + size.X > 0 && position.Y + size.Y > 0 && position.X < viewport.X && position.Y < viewport.Y;
}

function schedule(sprite: SpriteClipImageSprite) {
	scheduled.set(sprite, 0);
	sprite.RenderSubframe(0);
	ensureScheduler();
}

class SpriteClipImageSprite {
	isPlaying = false;
	private signals = new Map<SpriteSignal, BindableEvent>();
	private destroyed = false;
	private adornee?: ImageLabel | ImageButton;
	private blendAdornee?: ImageLabel | ImageButton;
	private spriteSheetId: string;
	private spriteSize: Vector2;
	private spriteOffset: Vector2;
	private edgeOffset: Vector2;
	spriteCount: number;
	private columnCount: number;
	frameRate: number;
	private isLooped: boolean;
	private getOpacity?: () => number;
	currentFrame: number;
	private destroyingConnection?: RBXScriptConnection;
	private blendDestroyingConnection?: RBXScriptConnection;

	constructor(props: ImageSpriteProps) {
		this.adornee = props.adornee;
		this.blendAdornee = props.blendAdornee;
		this.spriteSheetId = props.spriteSheetId;
		this.spriteSize = props.spriteSize;
		this.spriteOffset = props.spriteOffset ?? Vector2.zero;
		this.edgeOffset = props.edgeOffset ?? Vector2.zero;
		this.spriteCount = math.max(1, math.floor(props.spriteCount));
		this.columnCount = math.max(1, math.floor(props.columnCount));
		this.frameRate = math.max(1, props.frameRate);
		this.isLooped = props.isLooped;
		this.getOpacity = props.getOpacity;
		this.currentFrame = math.clamp(math.floor(props.currentFrame ?? 1), 1, this.spriteCount);
		props.adornee.Image = this.spriteSheetId;
		props.adornee.ImageRectSize = this.spriteSize;
		this.applyFrame();
		this.destroyingConnection = props.adornee.Destroying.Connect(() => this.Destroy());
		this.blendDestroyingConnection = props.blendAdornee?.Destroying.Connect(() => {
			this.blendAdornee = undefined;
		});
	}

	private seenAt = -math.huge;
	private seen = true;

	loops(): boolean {
		return this.isLooped;
	}

	/** Visible in the hierarchy and overlapping the viewport. Re-checked at most 4 times a second. */
	onScreen(): boolean {
		const now = os.clock();
		if (now - this.seenAt < 0.25) {
			return this.seen;
		}
		this.seenAt = now;
		this.seen = computeOnScreen(this.adornee);
		return this.seen;
	}

	private fire(signal: SpriteSignal) {
		this.signals.get(signal)?.Fire();
	}

	private applyFrameTo(image: ImageLabel | ImageButton | undefined, frame: number) {
		if (image === undefined) {
			return;
		}
		const index = frame - 1;
		const column = index % this.columnCount;
		const row = math.floor(index / this.columnCount);
		image.Image = this.spriteSheetId;
		image.ImageRectSize = this.spriteSize;
		image.ImageRectOffset = new Vector2(
			this.edgeOffset.X + column * (this.spriteSize.X + this.spriteOffset.X),
			this.edgeOffset.Y + row * (this.spriteSize.Y + this.spriteOffset.Y),
		);
	}

	private applyFrame() {
		this.applyFrameTo(this.adornee, this.currentFrame);
		const followingFrame =
			this.currentFrame >= this.spriteCount ? (this.isLooped ? 1 : this.spriteCount) : this.currentFrame + 1;
		this.applyFrameTo(this.blendAdornee, followingFrame);
	}

	RenderSubframe(alpha: number) {
		const blend = this.blendAdornee;
		const opacity = math.clamp(this.getOpacity?.() ?? 1, 0, 1);
		if (blend === undefined) {
			if (this.adornee !== undefined) {
				this.adornee.ImageTransparency = 1 - opacity;
			}
			return;
		}
		const raw = math.clamp((alpha - 0.68) / 0.32, 0, 1);
		const amount = raw * raw * (3 - 2 * raw);
		if (this.adornee !== undefined) {
			this.adornee.ImageTransparency = 1 - (1 - amount) * opacity;
		}
		blend.ImageTransparency = 1 - amount * opacity;
	}

	Play(playFrom?: number): boolean {
		if (this.destroyed || this.isPlaying) {
			return false;
		}
		if (playFrom !== undefined) {
			this.SetFrame(playFrom);
		}
		this.isPlaying = true;
		schedule(this);
		this.fire("PlayCalled");
		return true;
	}

	Pause(): boolean {
		if (!this.isPlaying) {
			return false;
		}
		this.isPlaying = false;
		unschedule(this);
		this.RenderSubframe(0);
		this.fire("PauseCalled");
		return true;
	}

	Stop(): boolean {
		const wasPlaying = this.isPlaying;
		if (wasPlaying) {
			this.isPlaying = false;
			unschedule(this);
		}
		if (!this.destroyed) {
			this.SetFrame(1);
		}
		this.RenderSubframe(0);
		if (wasPlaying) {
			this.fire("StopCalled");
		}
		return wasPlaying;
	}

	SetFrame(frame: number) {
		if (this.destroyed) {
			return;
		}
		const requestedFrame = math.floor(frame);
		if (requestedFrame < 1 || requestedFrame > this.spriteCount) {
			error(`Invalid SpriteClip frame ${requestedFrame}; expected 1-${this.spriteCount}`);
		}
		const changed = requestedFrame !== this.currentFrame;
		this.currentFrame = requestedFrame;
		this.applyFrame();
		if (changed) {
			this.fire("FrameChanged");
		}
		if (requestedFrame === this.spriteCount) {
			this.fire("FrameLast");
		}
	}

	Advance() {
		if (this.destroyed) {
			return;
		}
		const followingFrame = this.currentFrame + 1;
		if (followingFrame <= this.spriteCount) {
			this.SetFrame(followingFrame);
			return;
		}
		if (!this.isLooped) {
			this.Pause();
			return;
		}
		this.SetFrame(1);
		this.fire("Looped");
	}

	AdvanceBy(steps: number) {
		if (this.destroyed || steps <= 0) {
			return;
		}
		const amount = math.max(1, math.floor(steps));
		if (!this.isLooped) {
			const target = math.min(this.spriteCount, this.currentFrame + amount);
			this.SetFrame(target);
			if (target >= this.spriteCount) {
				this.Pause();
			}
			return;
		}
		const zeroBased = this.currentFrame - 1 + amount;
		const loops = math.floor(zeroBased / this.spriteCount);
		this.SetFrame((zeroBased % this.spriteCount) + 1);
		if (loops > 0) {
			this.fire("Looped");
		}
	}

	GetSignal(signal: SpriteSignal): RBXScriptSignal {
		let bindable = this.signals.get(signal);
		if (bindable === undefined) {
			bindable = new Instance("BindableEvent");
			this.signals.set(signal, bindable);
		}
		return bindable.Event;
	}

	Destroy() {
		if (this.destroyed) {
			return;
		}
		this.isPlaying = false;
		unschedule(this);
		this.destroyingConnection?.Disconnect();
		this.destroyingConnection = undefined;
		this.blendDestroyingConnection?.Disconnect();
		this.blendDestroyingConnection = undefined;
		this.adornee = undefined;
		this.blendAdornee = undefined;
		this.signals.forEach((bindable) => bindable.Destroy());
		this.signals.clear();
		this.destroyed = true;
	}
}

export type ImageSprite = SpriteClipImageSprite;

export const SpriteClip2 = {
	ImageSprite: {
		new: (props: ImageSpriteProps) => new SpriteClipImageSprite(props),
	},
};
