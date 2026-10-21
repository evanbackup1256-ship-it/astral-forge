// Every ViewportFrame in the game frames its subject through @rbxts/viewportmodel, so the camera
// fits the model's real point cloud instead of a hand-tuned distance. FittedView owns the camera
// and re-fits when the frame resizes; the pool hands out bare transparent frames for scenes that
// open and close often (the crate reel), so phones aren't creating and destroying them each time.
import ViewportModel = require("@rbxts/viewportmodel");

export class FittedView {
	readonly camera: Camera;
	private readonly fit: ViewportModel;
	private readonly resize: RBXScriptConnection;
	private hasModel = false;
	private sized = false;
	/** runs after every re-fit, once the frame has a real size and a model */
	onFit?: () => void;

	constructor(readonly viewport: ViewportFrame, fieldOfView = 30) {
		this.camera = new Instance("Camera");
		this.camera.FieldOfView = fieldOfView;
		this.camera.Parent = viewport;
		viewport.CurrentCamera = this.camera;
		this.fit = new ViewportModel(viewport, this.camera);
		this.resize = viewport.GetPropertyChangedSignal("AbsoluteSize").Connect(() => this.calibrate());
		this.calibrate();
	}

	/** call again whenever parts are added or the model moves */
	setModel(model: Model) {
		this.fit.setModel(model);
		this.hasModel = true;
		this.calibrate();
	}

	/** true once the frame has been laid out; fits before that would divide by zero */
	ready(): boolean {
		return this.sized && this.hasModel;
	}

	calibrate() {
		const size = this.viewport.AbsoluteSize;
		this.sized = size.X > 0 && size.Y > 0;
		if (!this.sized) {
			return;
		}
		this.fit.calibrate();
		if (this.hasModel) {
			this.onFit?.();
		}
	}

	/** a distance that keeps the whole model in frame from any angle around `focus` */
	distance(focus?: Vector3): number {
		return this.fit.getFitDistance(focus);
	}

	/** the tightest camera for this orientation; `margin` pulls it back by that fraction */
	frame(orientation: CFrame, margin = 0): CFrame {
		const tight = this.fit.getMinimumFitCFrame(orientation);
		if (margin <= 0) {
			return tight;
		}
		return tight.mul(new CFrame(0, 0, this.distance() * margin));
	}

	destroy() {
		this.resize.Disconnect();
		if (this.viewport.CurrentCamera === this.camera) {
			this.viewport.CurrentCamera = undefined;
		}
		this.camera.Destroy();
	}
}

const POOL_MAX = 24;
const pool: ViewportFrame[] = [];

export function takeViewport(parent: GuiObject, zIndex: number): ViewportFrame {
	let viewport = pool.pop();
	if (viewport === undefined) {
		viewport = new Instance("ViewportFrame");
		viewport.Name = "PooledView";
		viewport.BackgroundTransparency = 1;
		viewport.BorderSizePixel = 0;
		viewport.Active = false;
		viewport.Selectable = false;
	}
	viewport.Size = UDim2.fromScale(1, 1);
	viewport.Position = new UDim2();
	viewport.AnchorPoint = Vector2.zero;
	viewport.ImageTransparency = 0;
	viewport.ImageColor3 = new Color3(1, 1, 1);
	viewport.Ambient = Color3.fromRGB(150, 142, 146);
	viewport.LightColor = Color3.fromRGB(255, 232, 206);
	viewport.LightDirection = new Vector3(-0.5, -0.8, 0.6);
	viewport.ZIndex = zIndex;
	viewport.Parent = parent;
	return viewport;
}

export function giveViewport(viewport: ViewportFrame) {
	viewport.CurrentCamera = undefined;
	viewport.ClearAllChildren();
	viewport.Parent = undefined;
	if (pool.size() < POOL_MAX) {
		pool.push(viewport);
	} else {
		viewport.Destroy();
	}
}
