const ReplicatedStorage = game.GetService("ReplicatedStorage");
const ClientLog = (require(script.Parent!.FindFirstChild("CoreKit")! as ModuleScript) as (name: string) => { ClientLog: { debug(...args: defined[]): void; warn(...args: defined[]): void; once(...args: defined[]): void } })("log").ClientLog;
let bootstrapRoot: Instance | undefined;

function installBundledRuntime(): boolean {
	const include = ReplicatedStorage.FindFirstChild("rbxts_include");
	let _nodeModules = include;
	if (_nodeModules !== undefined) {
		_nodeModules = _nodeModules.FindFirstChild("node_modules");
	}
	const nodeModules = _nodeModules;
	if (nodeModules === undefined) {
		return false;
	}
	let _localFallback: Instance | undefined = script.Parent;
	if (_localFallback !== undefined) {
		_localFallback = _localFallback.FindFirstChild("FrameworkRuntime");
	}
	const localFallback = _localFallback;
	const astral = ReplicatedStorage.FindFirstChild("AstralForge");
	let _replicatedFallback: Instance | undefined = astral;
	if (_replicatedFallback !== undefined) {
		_replicatedFallback = _replicatedFallback.FindFirstChild("Vendor");
		if (_replicatedFallback !== undefined) {
			_replicatedFallback = _replicatedFallback.FindFirstChild("FlameworkRuntime");
		}
	}
	const replicatedFallback = _replicatedFallback;
	const fallback = localFallback ?? replicatedFallback;
	if (fallback === undefined) {
		return false;
	}
	let runtime = nodeModules.FindFirstChild("@flamework");
	let installed = false;
	if (runtime === undefined) {
		runtime = fallback.Clone();
		runtime.Name = "@flamework";
		runtime.Parent = nodeModules;
		installed = true;
	} else {
		const fillMissing = (target: Instance, source: Instance): void => {
			for (const child of source.GetChildren()) {
				const current = target.FindFirstChild(child.Name);
				if (current === undefined) {
					child.Clone().Parent = target;
					installed = true;
				} else {
					fillMissing(current, child);
				}
			}
		};
		fillMissing(runtime, fallback);
	}
	if (installed) {
		ClientLog.debug("framework", "bundled runtime installed");
	}
	return true;
}

function hasFlameworkRuntime(): boolean {
	const include = ReplicatedStorage.FindFirstChild("rbxts_include");
	let _nodeModules: Instance | undefined = include;
	if (_nodeModules !== undefined) {
		_nodeModules = _nodeModules.FindFirstChild("node_modules");
	}
	const nodeModules = _nodeModules;
	let _scope: Instance | undefined = nodeModules;
	if (_scope !== undefined) {
		_scope = _scope.FindFirstChild("@flamework");
	}
	const scope = _scope;
	let _coreOut: Instance | undefined = scope;
	if (_coreOut !== undefined) {
		_coreOut = _coreOut.FindFirstChild("core");
		if (_coreOut !== undefined) {
			_coreOut = _coreOut.FindFirstChild("out");
		}
	}
	const coreOut = _coreOut;
	let _componentsOut: Instance | undefined = scope;
	if (_componentsOut !== undefined) {
		_componentsOut = _componentsOut.FindFirstChild("components");
		if (_componentsOut !== undefined) {
			_componentsOut = _componentsOut.FindFirstChild("out");
		}
	}
	const componentsOut = _componentsOut;
	if (coreOut === undefined || componentsOut === undefined) {
		return false;
	}
	for (const child of ["flamework", "metadata", "modding", "prelude", "reflect"] as const) {
		if (coreOut.FindFirstChild(child) === undefined) {
			return false;
		}
	}
	for (const child of ["baseComponent", "componentTracker", "components", "utility"] as const) {
		if (componentsOut.FindFirstChild(child) === undefined) {
			return false;
		}
	}
	return true;
}

function startFramework(root: Instance): boolean {
	if (!hasFlameworkRuntime()) {
		return false;
	}
	ClientLog.once("framework-runtime", "framework", "flamework present");
	let _frameworkModule: Instance | undefined = script.Parent;
	if (_frameworkModule !== undefined) {
		_frameworkModule = _frameworkModule.FindFirstChild("framework");
	}
	const frameworkModule = _frameworkModule;
	if (frameworkModule === undefined || !frameworkModule.IsA("ModuleScript")) {
		ClientLog.warn("framework", "framework module missing");
		return true;
	}
	const [loaded, runtime] = pcall(() => {
		return require(frameworkModule as ModuleScript) as { initializeClientFramework(this: void, root: Instance): void };
	});
	if (!loaded) {
		ClientLog.warn("framework", `couldn't load framework: ${tostring(runtime)}`);
		return true;
	}
	const [started, reason] = pcall(() => {
		return (runtime as { initializeClientFramework(this: void, root: Instance): void }).initializeClientFramework(root);
	});
	if (!started) {
		ClientLog.warn("framework", `framework didn't start: ${tostring(reason)}`);
	} else {
		ClientLog.once("framework-started", "framework", "framework started");
		task.spawn(() => {
			const deadline = os.clock() + 5;
			while (root.Parent !== undefined && os.clock() < deadline) {
				if (root.GetAttribute("AstralFrameworkReady") === true) {
					ClientLog.once("framework-ready", "framework", "ui root ready");
					return;
				}
				task.wait(0.1);
			}
			if (root.Parent !== undefined) {
				ClientLog.warn("framework", "ui root did not attach");
			}
		});
	}
	return true;
}

function initializeClientFramework(root: Instance): void {
	if (bootstrapRoot === root && root.Parent !== undefined) {
		return;
	}
	bootstrapRoot = root;
	installBundledRuntime();
	if (startFramework(root)) {
		return;
	}
	ClientLog.debug("framework", "waiting for runtime");
	task.spawn(() => {
		const deadline = os.clock() + 8;
		while (root.Parent !== undefined && os.clock() < deadline) {
			installBundledRuntime();
			if (startFramework(root)) {
				return;
			}
			task.wait(0.2);
		}
		ClientLog.warn("framework", "framework still missing after 8s — restart Rojo");
	});
}

export = {
	initializeClientFramework,
};
